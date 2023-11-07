package com.amap.flutter.map.overlays.cluster;

import com.amap.api.maps.model.BitmapDescriptor;
import com.amap.api.maps.model.LatLng;

public class RegionItem implements ClusterItem {
    private String id;
    private LatLng latLng;
    private BitmapDescriptor descriptor;
    private float rotation;

    @Override
    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    @Override
    public LatLng getPosition() {
        return latLng;
    }

    public void setPosition(LatLng latLng) {
        this.latLng = latLng;
    }

    @Override
    public BitmapDescriptor getIcon() {
        return descriptor;
    }

    public void setIcon(BitmapDescriptor descriptor) {
        this.descriptor = descriptor;
    }

    @Override
    public float getRotation() {
        return rotation;
    }

    public void setRotation(float rotation) {
        this.rotation = rotation;
    }
}
