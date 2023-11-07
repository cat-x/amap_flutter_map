package com.amap.flutter.map.overlays.cluster;

import com.amap.api.maps.model.BitmapDescriptor;
import com.amap.api.maps.model.LatLng;

public interface ClusterItem {
    String getId();

    LatLng getPosition();

    BitmapDescriptor getIcon();

    float getRotation();
}
