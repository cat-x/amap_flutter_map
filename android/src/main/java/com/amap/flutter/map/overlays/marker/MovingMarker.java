package com.amap.flutter.map.overlays.marker;

import com.amap.api.maps.AMap;
import com.amap.api.maps.model.BasePointOverlay;
import com.amap.api.maps.model.LatLng;
import com.amap.api.maps.utils.overlay.MovingPointOverlay;

import java.util.LinkedList;
import java.util.List;

public class MovingMarker extends MovingPointOverlay implements MovingPointOverlay.MoveListener {
    private List<LatLng> basePoints;
    private List<LatLng> currentPoints;
    private MovingPointOverlay.MoveListener var1;

    public MovingMarker(AMap aMap, BasePointOverlay basePointOverlay) {
        super(aMap, basePointOverlay);
        super.setMoveListener(this);
    }

    @Override
    public void setPoints(List<LatLng> list) {
        this.basePoints = list;
        this.currentPoints = new LinkedList<>(basePoints);
        currentPoints.remove(0);
        super.setPoints(basePoints);
    }

    public void changeTotalDuration(int i) {
        LatLng currentLatLng = super.getPosition();
        currentPoints.add(0, currentLatLng);
        super.setPoints(currentPoints);
        currentPoints = new LinkedList<>(currentPoints);
        currentPoints.remove(0);
        super.setTotalDuration(i);
    }

    @Override
    public void startSmoothMove() {
        if (currentPoints.size() == 0) {
            this.currentPoints = new LinkedList<>(basePoints);
            super.setPoints(basePoints);
            currentPoints.remove(0);
        }
        super.startSmoothMove();
    }

    @Override
    public void setMoveListener(MoveListener moveListener) {
        var1 = moveListener;
    }

    @Override
    public int getIndex() {
        if (basePoints == null) {
            return 0;
        }
        return basePoints.size() - currentPoints.size() - 1;
    }

    @Override
    public void move(double v) {
        currentPoints.remove(0);
        if (var1 != null) {
            var1.move(v);
        }
    }
}
