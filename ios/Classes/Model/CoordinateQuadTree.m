//
//  CoordinateQuadTree.m
//  officialDemo2D
//
//  Created by yi chen on 14-5-15.
//  Copyright (c) 2014年 AutoNavi. All rights reserved.
//

#import <MAMapKit/MAMapKit.h>
#import <AMapSearchKit/AMapCommonObj.h>
#import "CoordinateQuadTree.h"
#import "ClusterAnnotation.h"
#import "AMapMarker.h"

QuadTreeNodeData QuadTreeNodeDataForAMapPOI(AMapPOI* poi)
{
    return QuadTreeNodeDataMake(poi.location.latitude, poi.location.longitude, (__bridge_retained void *)(poi));
}

BoundingBox BoundingBoxForMapRect(MAMapRect mapRect)
{
    CLLocationCoordinate2D topLeft = MACoordinateForMapPoint(mapRect.origin);
    CLLocationCoordinate2D botRight = MACoordinateForMapPoint(MAMapPointMake(MAMapRectGetMaxX(mapRect), MAMapRectGetMaxY(mapRect)));
    
    CLLocationDegrees minLat = botRight.latitude;
    CLLocationDegrees maxLat = topLeft.latitude;
    
    CLLocationDegrees minLon = topLeft.longitude;
    CLLocationDegrees maxLon = botRight.longitude;
    
    return BoundingBoxMake(minLat, minLon, maxLat, maxLon);
}

float CellSizeForZoomLevel(double zoomLevel)
{
    /*zoomLevel越大，cellSize越小. */
    if (zoomLevel < 13.0)
    {
        return 64;
    }
    else if (zoomLevel <15.0)
    {
        return 32;
    }
    else if (zoomLevel <18.0)
    {
        return 16;
    }
    else if (zoomLevel < 20.0)
    {
        return 8;
    }
    
    return 64;
}

BoundingBox quadTreeNodeDataArrayForPOIs(QuadTreeNodeData *dataArray, NSArray * pois)
{
    CLLocationDegrees minX = ((AMapPOI *)pois[0]).location.latitude;
    CLLocationDegrees maxX = ((AMapPOI *)pois[0]).location.latitude;
    
    CLLocationDegrees minY = ((AMapPOI *)pois[0]).location.longitude;
    CLLocationDegrees maxY = ((AMapPOI *)pois[0]).location.longitude;
    
    for (NSInteger i = 0; i < [pois count]; i++)
    {
        dataArray[i] = QuadTreeNodeDataForAMapPOI(pois[i]);
        
        if (dataArray[i].x < minX)
        {
            minX = dataArray[i].x;
        }
        
        if (dataArray[i].x > maxX)
        {
            maxX = dataArray[i].x;
        }
        
        if (dataArray[i].y < minY)
        {
            minY = dataArray[i].y;
        }
        
        if (dataArray[i].y > maxY)
        {
            maxY = dataArray[i].y;
        }
    }
    
    return BoundingBoxMake(minX, minY, maxX, maxY);
}

#pragma mark -

@implementation CoordinateQuadTree

#pragma mark Utility

- (NSArray *)getAnnotationsWithoutClusteredInMapRect:(MAMapRect)rect
{
    __block NSMutableArray *clusteredAnnotations = [[NSMutableArray alloc] init];
    QuadTreeGatherDataInRange(self.root, BoundingBoxForMapRect(rect), ^(QuadTreeNodeData data) {
        AMapPOI *aPoi = (__bridge AMapPOI *)data.data;
        
        CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(aPoi.location.latitude, aPoi.location.longitude);
        ClusterAnnotation *annotation = [[ClusterAnnotation alloc] initWithCoordinate:coordinate count:1];
        annotation.pois = @[aPoi].mutableCopy;
        
        [clusteredAnnotations addObject:annotation];
    });
    
    return clusteredAnnotations;
}

- (NSArray *)clusteredAnnotationsWithinMapRect:(MAMapRect)rect withZoomScale:(double)zoomScale andZoomLevel:(double)zoomLevel
{
    //满足特定zoomLevel时不产生聚合效果(这里取地图的最大zoomLevel，效果为地图达到最大zoomLevel时，annotation全部展开，无聚合效果)
    if (zoomLevel >= 19.0)
    {
        return [self getAnnotationsWithoutClusteredInMapRect:rect];
    }
    
    double CellSize = CellSizeForZoomLevel(zoomLevel);
    double scaleFactor = zoomScale / CellSize;
    
    NSInteger minX = floor(MAMapRectGetMinX(rect) * scaleFactor);
    NSInteger maxX = floor(MAMapRectGetMaxX(rect) * scaleFactor);
    NSInteger minY = floor(MAMapRectGetMinY(rect) * scaleFactor);
    NSInteger maxY = floor(MAMapRectGetMaxY(rect) * scaleFactor);
    
    NSMutableArray *clusteredAnnotations = [[NSMutableArray alloc] init];
    for (NSInteger x = minX; x <= maxX; x++)
    {
        for (NSInteger y = minY; y <= maxY; y++)
        {
            MAMapRect mapRect = MAMapRectMake(x / scaleFactor, y / scaleFactor, 1.0 / scaleFactor, 1.0 / scaleFactor);
            
            __block double totalX = 0;
            __block double totalY = 0;
            __block int     count = 0;
            
            NSMutableArray *pois = [[NSMutableArray alloc] init];
            
            /* 查询区域内数据的个数. */
            QuadTreeGatherDataInRange(self.root, BoundingBoxForMapRect(mapRect), ^(QuadTreeNodeData data)
                                      {
                                          totalX += data.x;
                                          totalY += data.y;
                                          count++;
                                          
                                          [pois addObject:(__bridge AMapPOI *)data.data];
                                      });
            
            /* 若区域内仅有一个数据. */
            if (count == 1)
            {
                CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(totalX, totalY);
                ClusterAnnotation *annotation = [[ClusterAnnotation alloc] initWithCoordinate:coordinate count:count];
                annotation.pois = pois;
                
                [clusteredAnnotations addObject:annotation];
            }
            
            /* 若区域内有多个数据 按数据的中心位置画点. */
            if (count > 1)
            {
                CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(totalX / count, totalY / count);
                ClusterAnnotation *annotation = [[ClusterAnnotation alloc] initWithCoordinate:coordinate count:count];
                annotation.pois  = pois;
                
                [clusteredAnnotations addObject:annotation];
            }
        }
    }
    
    return [NSArray arrayWithArray:clusteredAnnotations];
}

#pragma mark - cluster by distance

///按照annotation.coordinate之间的距离进行聚合
- (NSArray<ClusterAnnotation *> *)clusteredAnnotationsWithinMapRect:(MAMapRect)rect withDistance:(double)distance {
    __block NSMutableArray<AMapPOI *> *allAnnotations = [[NSMutableArray alloc] init];
    QuadTreeGatherDataInRange(self.root, BoundingBoxForMapRect(rect), ^(QuadTreeNodeData data) {
        [allAnnotations addObject:(__bridge AMapPOI *)data.data];
    });
    
    NSMutableArray<ClusterAnnotation *> *clusteredAnnotations = [[NSMutableArray alloc] init];
    for (AMapPOI *aAnnotation in allAnnotations) {
        CLLocationCoordinate2D resultCoor = CLLocationCoordinate2DMake(aAnnotation.location.latitude, aAnnotation.location.longitude);
        
        ClusterAnnotation *cluster = [self getClusterForAnnotation:aAnnotation inClusteredAnnotations:clusteredAnnotations withDistance:distance];
        if (cluster == nil) {
            ClusterAnnotation *aResult = [[ClusterAnnotation alloc] initWithCoordinate:resultCoor count:1];
            aResult.pois = @[aAnnotation].mutableCopy;
            
            [clusteredAnnotations addObject:aResult];
        } else {
            double totalX = cluster.coordinate.latitude * cluster.count + resultCoor.latitude;
            double totalY = cluster.coordinate.longitude * cluster.count + resultCoor.longitude;
            NSInteger totalCount = cluster.count + 1;
            
            cluster.count = totalCount;
            cluster.coordinate = CLLocationCoordinate2DMake(totalX / totalCount, totalY / totalCount);
            [cluster.pois addObject:aAnnotation];
        }
    }
    
    return clusteredAnnotations;
}

- (ClusterAnnotation *)getClusterForAnnotation:(AMapPOI *)annotation inClusteredAnnotations:(NSArray<ClusterAnnotation *> *)clusteredAnnotations withDistance:(double)distance {
    if ([clusteredAnnotations count] <= 0 || annotation == nil) {
        return nil;
    }
    
    CLLocation *annotationLocation = [[CLLocation alloc] initWithLatitude:annotation.location.latitude longitude:annotation.location.longitude];
    for (ClusterAnnotation *aCluster in clusteredAnnotations) {
        CLLocation *clusterLocation = [[CLLocation alloc] initWithLatitude:aCluster.coordinate.latitude longitude:aCluster.coordinate.longitude];
        double dis = [clusterLocation distanceFromLocation:annotationLocation];
        if (dis < distance) {
            return aCluster;
        }
    }
    
    return nil;
}

#pragma mark Initilization

- (void)buildTreeWithPOIs:(NSArray *)pois
{
    QuadTreeNodeData *dataArray = malloc(sizeof(QuadTreeNodeData) * [pois count]);
    
    BoundingBox maxBounding = quadTreeNodeDataArrayForPOIs(dataArray, pois);
    
    /*若已有四叉树，清空.*/
    [self clean];
    
    NSLog(@"build tree.");
    /*建立四叉树索引. */
    self.root = QuadTreeBuildWithData(dataArray, [pois count], maxBounding, 4);
    
    free(dataArray);
}

- (void)buildTreeWithLatLon:(NSArray *)positions
{
    QuadTreeNodeData *dataArray = malloc(sizeof(QuadTreeNodeData) * [positions count]);
    
    BoundingBox maxBounding = quadTreeNodeDataArrayForLatLon(dataArray, positions);
    
    /*若已有四叉树，清空.*/
    [self clean];
    
    NSLog(@"build tree.");
    /*建立四叉树索引. */
    self.root = QuadTreeBuildWithData(dataArray, [positions count], maxBounding, 4);
    
    free(dataArray);
}

BoundingBox quadTreeNodeDataArrayForLatLon(QuadTreeNodeData *dataArray, NSArray * pois)
{
    CLLocationDegrees minX = ((AMapMarker *)pois[0]).position.latitude;
    CLLocationDegrees maxX = ((AMapMarker *)pois[0]).position.latitude;
    
    CLLocationDegrees minY = ((AMapMarker *)pois[0]).position.longitude;
    CLLocationDegrees maxY = ((AMapMarker *)pois[0]).position.longitude;
    
    for (NSInteger i = 0; i < [pois count]; i++)
    {
        dataArray[i] = QuadTreeNodeDataForAMapLatLon(pois[i]);
        
        if (dataArray[i].x < minX)
        {
            minX = dataArray[i].x;
        }
        
        if (dataArray[i].x > maxX)
        {
            maxX = dataArray[i].x;
        }
        
        if (dataArray[i].y < minY)
        {
            minY = dataArray[i].y;
        }
        
        if (dataArray[i].y > maxY)
        {
            maxY = dataArray[i].y;
        }
    }
    
    return BoundingBoxMake(minX, minY, maxX, maxY);
}

QuadTreeNodeData QuadTreeNodeDataForAMapLatLon(AMapMarker* marker)
{
    return QuadTreeNodeDataMake(marker.position.latitude, marker.position.longitude, (__bridge_retained void *)(marker));
}

#pragma mark Life Cycle

- (void)clean
{
    if (self.root)
    {
        NSLog(@"free tree.");
        FreeQuadTreeNode(self.root);
    }
    
}

@end
