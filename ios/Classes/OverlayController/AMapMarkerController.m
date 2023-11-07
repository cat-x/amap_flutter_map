//
//  AMapMarkerController.m
//  amap_flutter_map
//
//  Created by lly on 2020/11/3.
//

#import "AMapMarkerController.h"
#import "AMapMarker.h"
#import "AMapJsonUtils.h"
#import "AMapConvertUtil.h"
#import "MAAnnotationView+Flutter.h"
#import "MAAnimatedAnnotation.h"
#import "MAAnnotationMoveAnimation.h"
#import "FlutterMethodChannel+MethodCallDispatch.h"

#import "CoordinateQuadTree.h"
#import "ClusterAnnotation.h"
#import "ClusterAnnotationView.h"
#include <math.h>

@interface AMapMarkerController ()

@property (nonatomic,strong) NSMutableDictionary<NSString*,AMapMarker*> *markerDict;
@property (nonatomic,strong) NSMutableDictionary<NSString*,AMapMarker*> *clusterDict;
@property (nonatomic,strong) FlutterMethodChannel *methodChannel;
@property (nonatomic,strong) NSObject<FlutterPluginRegistrar> *registrar;
@property (nonatomic,strong) MAMapView *mapView;
@property (nonatomic,strong) MAAnimatedAnnotation *annotation;


@property (nonatomic,strong) CoordinateQuadTree *coordinateQuadTree;

@end

@implementation AMapMarkerController

- (instancetype)init:(FlutterMethodChannel*)methodChannel
             mapView:(MAMapView*)mapView
           registrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    self = [super init];
    if (self) {
        _methodChannel = methodChannel;
        _mapView = mapView;
        _markerDict = [NSMutableDictionary dictionaryWithCapacity:1];
        _clusterDict = [NSMutableDictionary dictionaryWithCapacity:1];
        _registrar = registrar;
        _coordinateQuadTree = [[CoordinateQuadTree alloc] init];
        
        __weak typeof(self) weakSelf = self;
        [_methodChannel addMethodName:@"markers#update" withHandler:^(FlutterMethodCall * _Nonnull call, FlutterResult  _Nonnull result) {
            id markersToAdd = call.arguments[@"markersToAdd"];
            if ([markersToAdd isKindOfClass:[NSArray class]]) {
                [weakSelf addMarkers:markersToAdd];
            }
            id markersToChange = call.arguments[@"markersToChange"];
            if ([markersToChange isKindOfClass:[NSArray class]]) {
                [weakSelf changeMarkers:markersToChange];
            }
            id markerIdsToRemove = call.arguments[@"markerIdsToRemove"];
            if ([markerIdsToRemove isKindOfClass:[NSArray class]]) {
                [weakSelf removeMarkerIds:markerIdsToRemove];
            }
            result(nil);
        }];
        [_methodChannel addMethodName:@"marker#move" withHandler:^(FlutterMethodCall * _Nonnull call, FlutterResult  _Nonnull result) {
            id targetMarkerId = call.arguments[@"markerId"];
            AMapMarker* targetMarker = weakSelf.markerDict[targetMarkerId];
            if (targetMarker) {
                [weakSelf.mapView setSelectedAnnotations:@[targetMarker.annotation]];
                MAAnimatedAnnotation* anno = (MAAnimatedAnnotation*) targetMarker.annotation;
                int count = targetMarker.trackCount - targetMarker.suspendedCount;
                CLLocationCoordinate2D* coords = targetMarker.track + targetMarker.suspendedCount;
                [anno addMoveAnimationWithKeyCoordinates:coords count:count withDuration:targetMarker.duration-targetMarker.suspendedTime withName: anno.title completeCallback:^(BOOL isFinished) {
                    if (isFinished) {
                        targetMarker.annotation.coordinate = targetMarker.position;
                        [weakSelf.mapView setSelectedAnnotations:@[targetMarker.annotation]];
                        targetMarker.suspendedTime = 0;
                        targetMarker.suspendedCount = 0;
                    }
                }  stepCallback:^(MAAnnotationMoveAnimation *animation) {
                    [weakSelf.methodChannel invokeMethod:@"marker#onMove" arguments:@{@"markerId" : targetMarkerId, @"index" : [NSNumber numberWithInt:(int)animation.passedPointCount], @"distance" : [NSNumber numberWithInt:0]}];
                 }];
            }
            result(nil);
        }];
        [_methodChannel addMethodName:@"marker#stop" withHandler:^(FlutterMethodCall * _Nonnull call, FlutterResult  _Nonnull result) {
            id targetMarkerId = call.arguments[@"markerId"];
            AMapMarker* targetMarker = weakSelf.markerDict[targetMarkerId];
            if (targetMarker) {
                MAAnimatedAnnotation* anno = (MAAnimatedAnnotation*) targetMarker.annotation;
                for (MAAnnotationMoveAnimation *animation in [anno allMoveAnimations]) {
                    [animation cancel];
                    targetMarker.suspendedTime += animation.elapsedTime;
                    targetMarker.suspendedCount += (int)animation.passedPointCount;
                }
            }
            result(nil);
        }];
        [_methodChannel addMethodName:@"marker#delete" withHandler:^(FlutterMethodCall * _Nonnull call, FlutterResult  _Nonnull result) {
            result(nil);
        }];
        [_methodChannel addMethodName:@"marker#duration" withHandler:^(FlutterMethodCall * _Nonnull call, FlutterResult  _Nonnull result) {
            id targetMarkerId = call.arguments[@"markerId"];
            AMapMarker* targetMarker = weakSelf.markerDict[targetMarkerId];
            if (targetMarker) {
                NSNumber *durationP = call.arguments[@"duration"];
                targetMarker.duration =[durationP intValue];
                if (targetMarker.duration <= 1) {
                    targetMarker.duration = 1;
                }
            }
            result(nil);
        }];
        [_methodChannel addMethodName:@"clusters#update" withHandler:^(FlutterMethodCall * _Nonnull call, FlutterResult  _Nonnull result) {
            id clustersToAdd = call.arguments[@"clustersToAdd"];
            if ([clustersToAdd isKindOfClass:[NSArray class]]) {
                [weakSelf addClusters:clustersToAdd];
            }
            id clustersToChange = call.arguments[@"clustersToChange"];
            if ([clustersToChange isKindOfClass:[NSArray class]]) {
                [weakSelf changeClusters:clustersToChange];
            }
            id clusterIdsToRemove = call.arguments[@"clusterIdsToRemove"];
            if ([clusterIdsToRemove isKindOfClass:[NSArray class]]) {
                [weakSelf removeClusters:clusterIdsToRemove];
            }
            [weakSelf updateClusters];
            result(nil);
        }];
    }
    return self;
}

- (nullable AMapMarker *)markerForId:(NSString *)markerId {
    return _markerDict[markerId];
}

- (void)addClusters:(NSArray*)markersToAdd {
    for (NSDictionary* marker in markersToAdd) {
        AMapMarker *markerModel = [AMapJsonUtils modelFromDict:marker modelClass:[AMapMarker class]];
        //从bitmapDesc中解析UIImage
        if (markerModel.icon) {
            markerModel.image = [AMapConvertUtil imageFromRegistrar:self.registrar iconData:markerModel.icon];
        }
        // 先加入到字段中，避免后续的地图回到里，取不到对应的marker数据
        if (markerModel.id_) {
            _clusterDict[markerModel.id_] = markerModel;
        }
//        [self.mapView addAnnotation:markerModel.annotation];
    }
}

- (void)changeClusters:(NSArray*)markersToChange {
    for (NSDictionary* markerToChange in markersToChange) {
        NSLog(@"changeMarker:%@",markerToChange);
        AMapMarker *markerModelToChange = [AMapJsonUtils modelFromDict:markerToChange modelClass:[AMapMarker class]];
        AMapMarker *currentMarkerModel = _clusterDict[markerModelToChange.id_];
        NSAssert(currentMarkerModel != nil, @"需要修改的marker不存在");
        
        //如果图标变了，则存储和解析新的图标
        if ([AMapConvertUtil checkIconDescriptionChangedFrom:currentMarkerModel.icon to:markerModelToChange.icon]) {
            UIImage *image = [AMapConvertUtil imageFromRegistrar:self.registrar iconData:markerModelToChange.icon];
            currentMarkerModel.icon = markerModelToChange.icon;
            currentMarkerModel.image = image;
        }
        //更新除了图标之外的其它信息
        [currentMarkerModel updateMarker:markerModelToChange];
        
        MAAnnotationView *view = [self.mapView viewForAnnotation:currentMarkerModel.annotation];
        if (view) {//如果可以获取到View，则立刻更新
            [view updateViewWithMarker:currentMarkerModel];
        } //获取不到时，则在viewDidAdd的回调中，重新更新view的效果；
    }
}

- (void)removeClusters:(NSArray*)markerIdsToRemove {
    for (NSString* markerId in markerIdsToRemove) {
        if (!markerId) {
            continue;
        }
        AMapMarker* marker = _clusterDict[markerId];
        if (!marker) {
            continue;
        }
//        [self.mapView removeAnnotation:marker.annotation];
        [_clusterDict removeObjectForKey:markerId];
    }
}


- (void)updateClusters {
    if ([self.clusterDict.allValues count] > 0) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self.coordinateQuadTree buildTreeWithLatLon:self.clusterDict.allValues];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self addAnnotationsToMapView:self.mapView];
            });
        });
    }
}

- (void)addMarkers:(NSArray*)markersToAdd {
    for (NSDictionary* marker in markersToAdd) {
        AMapMarker *markerModel = [AMapJsonUtils modelFromDict:marker modelClass:[AMapMarker class]];
        //从bitmapDesc中解析UIImage
        if (markerModel.icon) {
            markerModel.image = [AMapConvertUtil imageFromRegistrar:self.registrar iconData:markerModel.icon];
        }
        // 先加入到字段中，避免后续的地图回到里，取不到对应的marker数据
        if (markerModel.id_) {
            _markerDict[markerModel.id_] = markerModel;
        }
        [self.mapView addAnnotation:markerModel.annotation];
    }
}

- (void)changeMarkers:(NSArray*)markersToChange {
    for (NSDictionary* markerToChange in markersToChange) {
        NSLog(@"changeMarker:%@",markerToChange);
        AMapMarker *markerModelToChange = [AMapJsonUtils modelFromDict:markerToChange modelClass:[AMapMarker class]];
        AMapMarker *currentMarkerModel = _markerDict[markerModelToChange.id_];
        NSAssert(currentMarkerModel != nil, @"需要修改的marker不存在");
        
        //如果图标变了，则存储和解析新的图标
        if ([AMapConvertUtil checkIconDescriptionChangedFrom:currentMarkerModel.icon to:markerModelToChange.icon]) {
            UIImage *image = [AMapConvertUtil imageFromRegistrar:self.registrar iconData:markerModelToChange.icon];
            currentMarkerModel.icon = markerModelToChange.icon;
            currentMarkerModel.image = image;
        }
        //更新除了图标之外的其它信息
        [currentMarkerModel updateMarker:markerModelToChange];
        
        MAAnnotationView *view = [self.mapView viewForAnnotation:currentMarkerModel.annotation];
        if (view) {//如果可以获取到View，则立刻更新
            [view updateViewWithMarker:currentMarkerModel];
        } //获取不到时，则在viewDidAdd的回调中，重新更新view的效果；
    }
}

- (void)removeMarkerIds:(NSArray*)markerIdsToRemove {
    for (NSString* markerId in markerIdsToRemove) {
        if (!markerId) {
            continue;
        }
        AMapMarker* marker = _markerDict[markerId];
        if (!marker) {
            continue;
        }
        [self.mapView removeAnnotation:marker.annotation];
        [_markerDict removeObjectForKey:markerId];
    }
}

- (void)addAnnotationsToMapView:(MAMapView *)mapView
{
    if (self.coordinateQuadTree.root == nil || self.mapView.bounds.size.width == 0)
    {
        return;
    }
    double zoomScale = self.mapView.bounds.size.width / self.mapView.visibleMapRect.size.width;
    NSArray *annotations = [self.coordinateQuadTree clusteredAnnotationsWithinMapRect:mapView.visibleMapRect
                                withZoomScale:zoomScale
                                 andZoomLevel:mapView.zoomLevel];
   
    [self updateMapViewAnnotationsWithAnnotations:annotations];
}

- (void)updateMapViewAnnotationsWithAnnotations:(NSArray *)annotations
{
    /* 用户滑动时，保留仍然可用的标注，去除屏幕外标注，添加新增区域的标注 */
    NSMutableSet *before = [NSMutableSet setWithArray:self.mapView.annotations];
    [before removeObject:[self.mapView userLocation]];
    NSSet *after = [NSSet setWithArray:annotations];
    
    /* 保留仍然位于屏幕内的annotation. */
    NSMutableSet *toKeep = [NSMutableSet setWithSet:before];
    [toKeep intersectSet:after];
    
    /* 需要添加的annotation. */
    NSMutableSet *toAdd = [NSMutableSet setWithSet:after];
    [toAdd minusSet:toKeep];
    
    /* 删除位于屏幕外的annotation. */
    NSMutableSet *toRemove = [NSMutableSet setWithSet:before];
    [toRemove minusSet:after];
    
    /* 更新. */
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.mapView addAnnotations:[toAdd allObjects]];
        [self.mapView removeAnnotations:[toRemove allObjects]];
    });
}

- (MAAnnotationView *) viewForAnnotation:(id<MAAnnotation>)annotation
{
    if ([annotation isKindOfClass:[ClusterAnnotation class]])
    {
        /* dequeue重用annotationView. */
        static NSString *const AnnotatioViewReuseID1 = @"AnnotatioViewReuseID";
        static NSString *const AnnotatioViewReuseID2 = @"AnnotatioViewNO";
        ClusterAnnotationView *annotationView;

        int count = (int)[(ClusterAnnotation *)annotation count];

        if (count == 1) {
            annotationView = (ClusterAnnotationView *)[_mapView dequeueReusableAnnotationViewWithIdentifier:AnnotatioViewReuseID1];
            if (!annotationView)
            {
                annotationView = [[ClusterAnnotationView alloc] initWithAnnotation:annotation
                                                                   reuseIdentifier:AnnotatioViewReuseID1 useIcon:false];
            }
            ClusterAnnotation *ca = annotation;
            AMapMarker *marker = ca.pois[0];
            annotationView.image = marker.image;
        } else {
            annotationView = (ClusterAnnotationView *)[_mapView dequeueReusableAnnotationViewWithIdentifier:AnnotatioViewReuseID2];
            if (!annotationView)
            {
                annotationView = [[ClusterAnnotationView alloc] initWithAnnotation:annotation
                                                                   reuseIdentifier:AnnotatioViewReuseID2];
            }
        }

        /* 设置annotationView的属性. */
        annotationView.annotation = annotation;
        annotationView.count = count;

        /* 不弹出原生annotation */
        annotationView.canShowCallout = NO;

        return annotationView;
    }
    
    return nil;
}

- (void) regionDidChangeAnimated:(BOOL)animated
{
    [self addAnnotationsToMapView:self.mapView];
}

- (BOOL)onMarkerTap:(NSString*)markerId {
  if (!markerId) {
    return NO;
  }
  AMapMarker* marker = _markerDict[markerId];
  if (!marker) {
    return NO;
  }
  [_methodChannel invokeMethod:@"marker#onTap" arguments:@{@"markerId" : markerId}];
  return YES;
}

- (void) showAnnotations:(NSArray *)annotations {
    [self.mapView showAnnotations:annotations animated:YES];
}

- (BOOL)onClusterTap:(NSString*)clusterId {
  if (!clusterId) {
    return NO;
  }
  AMapMarker* marker = _clusterDict[clusterId];
  if (!marker) {
    return NO;
  }
  [_methodChannel invokeMethod:@"cluster#onTap" arguments:@{@"clusterId" : clusterId}];
  return YES;
}

- (BOOL)onMarker:(NSString *)markerId endPostion:(CLLocationCoordinate2D)position {
    if (!markerId) {
      return NO;
    }
    AMapMarker* marker = _markerDict[markerId];
    if (!marker) {
      return NO;
    }
    [_methodChannel invokeMethod:@"marker#onDragEnd"
                         arguments:@{@"markerId" : markerId, @"position" : [AMapConvertUtil jsonArrayFromCoordinate:position]}];
    return YES;
}

//- (BOOL)onInfoWindowTap:(NSString *)markerId {
//    if (!markerId) {
//      return NO;
//    }
//    AMapMarker* marker = _markerDict[markerId];
//    if (!marker) {
//      return NO;
//    }
//    [_methodChannel invokeMethod:@"infoWindow#onTap" arguments:@{@"markerId" : markerId}];
//    return YES;
//}



@end
