## 【3.0.1】 - 2023-11-07.
增加showInfoWindow 参数来源于 https://github.com/ninetowns/amap_flutter_map/commit/765facd97eef487a15ef870ab02941abf8d56f3a 但是iOS端未实现
增加Clusters 和 MarkerMoveListener 参数来源于 https://github.com/jalen-mar/amap_flutter_map
增加 gestureScaleByMapCenter 参数来源于 https://gitee.com/mywentop/xbr_gaode_amap

## 【3.0.0】 - 2021-11-23.
* AMapWidget初始化时需要传入高德隐私合规配置参数privacyStatement
* 高德SDK合规使用方案请参考：https://lbs.amap.com/news/sdkhgsy
* 适配高德地图SDK 8.1.0及以后版本

## [2.0.2] - 2021-08-19.
* 修复在初始化地图时添加的Marker无法点击、移除的问题
* 修复在初始化地图时添加的Polyline无法点击、移除、修改的问题
* 修复在初始化地图时添加的Polygon无法点击、移除、修改的问题
## [2.0.1] - 2021-04-21.
* 支持Flutter 2.0.0以上版本
* 升级支持null-safety
* 修复2.0版本自定义地图样式不生效的问题
## [2.0.0] - 2021-04-21.
* 支持Flutter 2.0.0以上版本
* 升级支持null-safety
## [1.0.2] - 2021-02-02.
* debug模式，Android native端输出调试日志，方便排查问题。
## [1.0.1] - 2021-01-27.
* 修复iOS端动态库依赖静态库导致的pod install失败问题。
## [1.0.0] - 2020-12-22.
* 1.0.0版本发布