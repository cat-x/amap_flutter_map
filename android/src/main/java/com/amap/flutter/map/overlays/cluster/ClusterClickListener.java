package com.amap.flutter.map.overlays.cluster;

import com.amap.api.maps.model.Marker;

public interface ClusterClickListener {
    /**
     * 点击聚合点的回调处理函数
     *
     * @param marker
     *            点击的聚合点
     *            聚合点所包含的元素
     */
    public void onClick(Marker marker, Cluster cluster);
}
