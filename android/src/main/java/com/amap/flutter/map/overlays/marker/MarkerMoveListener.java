package com.amap.flutter.map.overlays.marker;

import android.os.Handler;
import android.os.Looper;
import android.os.Message;

import androidx.annotation.NonNull;

import com.amap.api.maps.utils.overlay.MovingPointOverlay;
import com.amap.flutter.map.utils.LogUtil;

import java.util.HashMap;
import java.util.Map;

import io.flutter.plugin.common.MethodChannel;

public class MarkerMoveListener extends Handler implements MovingPointOverlay.MoveListener {
    private MethodChannel methodChannel;
    private String markerId;
    private MovingPointOverlay marker;

    public MarkerMoveListener(MethodChannel methodChannel, String markerId, MovingPointOverlay marker) {
        super(Looper.myLooper());
        this.methodChannel = methodChannel;
        this.markerId = markerId;
        this.marker = marker;
    }

    @Override
    public void move(double v) {
        final Map<String, Object> data = new HashMap<>(3);
        data.put("markerId", markerId);
        data.put("distance", (int) v);
        data.put("index", marker.getIndex());
        LogUtil.i("MarkerMoveListener", "methodChannelTaskThread===> marker#onMove" + marker.getIndex());
        Message message = obtainMessage();
        message.obj = data;
        sendMessage(message);
    }

    @Override
    public void handleMessage(@NonNull Message msg) {
        LogUtil.i("MarkerMoveListener", "methodChannel===> marker#onMove");
        methodChannel.invokeMethod("marker#onMove", msg.obj);
    }
}
