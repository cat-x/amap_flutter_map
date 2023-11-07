package com.amap.flutter.map.overlays.cluster;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.RectF;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.Drawable;

import androidx.annotation.NonNull;

import com.amap.api.maps.AMap;
import com.amap.api.maps.CameraUpdateFactory;
import com.amap.api.maps.TextureMapView;
import com.amap.api.maps.model.LatLngBounds;
import com.amap.api.maps.model.Marker;
import com.amap.flutter.map.MyMethodCallHandler;
import com.amap.flutter.map.utils.Const;
import com.amap.flutter.map.utils.ConvertUtil;
import com.amap.flutter.map.utils.LogUtil;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class ClusterController implements MyMethodCallHandler, ClusterRender, ClusterClickListener {
    private final MethodChannel methodChannel;
    private final AMap amap;
    private final Context context;
    private ClusterOverlay clusterOverlay;
    private Map<Integer, Drawable> mBackDrawAbles = new HashMap<Integer, Drawable>();


    public ClusterController(MethodChannel methodChannel, TextureMapView mapView) {
        this.methodChannel = methodChannel;
        this.amap = mapView.getMap();
        this.context = mapView.getContext().getApplicationContext();
        clusterOverlay = new ClusterOverlay(amap, context);
        clusterOverlay.setClusterRenderer(this);
        clusterOverlay.setOnClusterClickListener(this);
    }

    @Override
    public void doMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        LogUtil.i("ClusterController", "doMethodCall===>" + call.method);
        switch (call.method) {
            case Const.METHOD_CLUSTER_UPDATE:
                invokeClusterOptions(call, result);
                break;
        }
    }

    private void invokeClusterOptions(MethodCall methodCall, MethodChannel.Result result) {
        if (null == methodCall) {
            return;
        }
        Object clustersToAdd = methodCall.argument("clustersToAdd");
        addByList((List<Object>) clustersToAdd);
        Object clustersToChange = methodCall.argument("clustersToChange");
        updateByList((List<Object>) clustersToChange);
        Object clusterIdsToRemove = methodCall.argument("clusterIdsToRemove");
        removeByIdList((List<Object>) clusterIdsToRemove);
        result.success(null);
    }

    private void removeByIdList(List<Object> clusterIdsToRemove) {
        if (clusterIdsToRemove == null) {
            return;
        }
        clusterOverlay.removeClusterItem((List<String>) ConvertUtil.toList(clusterIdsToRemove));
    }

    @Override
    public String[] getRegisterMethodIdArray() {
        return Const.METHOD_ID_LIST_FOR_CLUSTER;
    }

    public void addByList(List<Object> clusterList) {
        if (clusterList != null) {
            Map<String, ClusterItem> items = new HashMap<>();
            for (Object clusterObj : clusterList) {
                ClusterItem clusterItem = createClusterItem(clusterObj);
                if (clusterItem != null) {
                    items.put(clusterItem.getId(), clusterItem);
                }
            }
            clusterOverlay.addClusterItem(items);
        }
    }

    private ClusterItem createClusterItem(Object clusterObj) {
        if (null != amap && clusterObj != null) {
            RegionItem regionItem = new RegionItem();

            final Map<?, ?> clusterData = ConvertUtil.toMap(clusterObj);
            final Object id = clusterData.get("id");
            if (id != null) {
                regionItem.setId(ConvertUtil.toString(id));
            } else {
                return null;
            }
            final Object icon = clusterData.get("icon");
            if (icon != null) {
                regionItem.setIcon(ConvertUtil.toBitmapDescriptor(icon));
            } else {
                return null;
            }
            final Object position = clusterData.get("position");
            if (position != null) {
                regionItem.setPosition(ConvertUtil.toLatLng(position));
            } else {
                return null;
            }
            final Object rotation = clusterData.get("rotation");
            if (rotation != null) {
                regionItem.setRotation(ConvertUtil.toFloat(rotation));
            }
            return regionItem;
        }
        return null;
    }

    private void updateByList(List<Object> clustersToChange) {
        if (clustersToChange != null) {
            Map<String, ClusterItem> items = new HashMap<>();
            for (Object clusterToChange : clustersToChange) {
                ClusterItem clusterItem = update(clusterToChange);
                if (clusterItem != null) {
                    items.put(clusterItem.getId(),clusterItem);
                }
            }
            clusterOverlay.addClusterItem(items);
        }
    }

    private ClusterItem update(Object clusterToChange) {
        if (clusterToChange != null) {
            RegionItem regionItem = new RegionItem();

            final Map<?, ?> clusterData = ConvertUtil.toMap(clusterToChange);
            final Object id = clusterData.get("id");
            if (id != null) {
                regionItem.setId(ConvertUtil.toString(id));
            } else {
                return null;
            }
            final Object icon = clusterData.get("icon");
            if (icon != null) {
                regionItem.setIcon(ConvertUtil.toBitmapDescriptor(icon));
            } else {
                return null;
            }
            final Object position = clusterData.get("position");
            if (position != null) {
                regionItem.setPosition(ConvertUtil.toLatLng(position));
            } else {
                return null;
            }
            final Object rotation = clusterData.get("rotation");
            if (rotation != null) {
                regionItem.setRotation(ConvertUtil.toFloat(rotation));
            }
            return regionItem;
        }
        return null;
    }

    @Override
    public Drawable getDrawAble(int clusterNum) {
        int radius = 200;
        if (clusterNum < 10) {

            Drawable bitmapDrawable = mBackDrawAbles.get(2);
            if (bitmapDrawable == null) {
                bitmapDrawable = new BitmapDrawable(null, drawCircle(radius,
                        Color.argb(255, 13, 74, 161)));
                mBackDrawAbles.put(2, bitmapDrawable);
            }

            return bitmapDrawable;
        } else if (clusterNum < 50) {
            Drawable bitmapDrawable = mBackDrawAbles.get(3);
            if (bitmapDrawable == null) {
                bitmapDrawable = new BitmapDrawable(null, drawCircle(radius,
                        Color.argb(255, 33, 150, 243)));
                mBackDrawAbles.put(3, bitmapDrawable);
            }

            return bitmapDrawable;
        } else if (clusterNum < 100) {
            Drawable bitmapDrawable = mBackDrawAbles.get(3);
            if (bitmapDrawable == null) {
                bitmapDrawable = new BitmapDrawable(null, drawCircle(radius,
                        Color.argb(255, 13, 74, 161)));
                mBackDrawAbles.put(3, bitmapDrawable);
            }

            return bitmapDrawable;
        } else if (clusterNum < 200) {
            Drawable bitmapDrawable = mBackDrawAbles.get(3);
            if (bitmapDrawable == null) {
                bitmapDrawable = new BitmapDrawable(null, drawCircle(radius,
                        Color.argb(255, 255, 152, 0)));
                mBackDrawAbles.put(3, bitmapDrawable);
            }

            return bitmapDrawable;
        } else if (clusterNum < 500) {
            Drawable bitmapDrawable = mBackDrawAbles.get(3);
            if (bitmapDrawable == null) {
                bitmapDrawable = new BitmapDrawable(null, drawCircle(radius,
                        Color.argb(255, 230, 81, 0)));
                mBackDrawAbles.put(3, bitmapDrawable);
            }

            return bitmapDrawable;
        } else if (clusterNum < 1000) {
            Drawable bitmapDrawable = mBackDrawAbles.get(3);
            if (bitmapDrawable == null) {
                bitmapDrawable = new BitmapDrawable(null, drawCircle(radius,
                        Color.argb(255, 255, 57, 34)));
                mBackDrawAbles.put(3, bitmapDrawable);
            }

            return bitmapDrawable;
        } else {
            Drawable bitmapDrawable = mBackDrawAbles.get(4);
            if (bitmapDrawable == null) {
                bitmapDrawable = new BitmapDrawable(null, drawCircle(radius,
                        Color.argb(255, 191, 54, 12)));
                mBackDrawAbles.put(4, bitmapDrawable);
            }

            return bitmapDrawable;
        }
    }

    private Bitmap drawCircle(int radius, int color) {

        Bitmap bitmap = Bitmap.createBitmap(radius * 2, radius * 2,
                Bitmap.Config.ARGB_8888);
        Canvas canvas = new Canvas(bitmap);
        Paint paint = new Paint();
        RectF rectF = new RectF(0, 0, radius * 2, radius * 2);
        paint.setColor(color);
        canvas.drawArc(rectF, 0, 360, true, paint);
        return bitmap;
    }

    @Override
    public void onClick(Marker marker, Cluster cluster) {
        LatLngBounds.Builder builder = new LatLngBounds.Builder();
        List<ClusterItem> clusterItems = cluster.getClusterItems();
        if (clusterItems.size() == 1) {
            final Map<String, Object> data = new HashMap<>(1);
            data.put("clusterId", cluster.getClusterItems().get(0).getId());
            methodChannel.invokeMethod("cluster#onTap", data);
        } else {
            for (ClusterItem clusterItem : clusterItems) {
                builder.include(clusterItem.getPosition());
            }
            LatLngBounds latLngBounds = builder.build();
            amap.animateCamera(CameraUpdateFactory.newLatLngBounds(latLngBounds, 150));
        }
    }

    public void onDestroy() {
        clusterOverlay.onDestroy();
    }
}
