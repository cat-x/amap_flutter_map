// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' show hashValues, Offset;
import 'package:amap_flutter_map/src/types/base_overlay.dart';
import 'package:amap_flutter_base/amap_flutter_base.dart';
import 'bitmap.dart';
import 'base_overlay.dart';
import 'package:flutter/foundation.dart' show listEquals;

/// 点覆盖物的类
class ClusterItem extends BaseOverlay {
  ClusterItem({
    required this.position,
    this.icon = BitmapDescriptor.defaultMarker,
    this.rotation = 0.0,
    this.onTap,
  })  : super();

  /// 覆盖物的图标
  BitmapDescriptor icon;

  /// 位置,不能为空
  final LatLng position;

  /// 回调的参数是对应的id
  final ArgumentCallback<String>? onTap;

  /// 旋转角度,以锚点为中心,顺时针旋转（单位：度数）
  ///
  /// 注意：iOS端目前仅支持绕marker中心点旋转
  final double rotation;

  /// copy的真正复制的参数，主要用于需要修改某个属性参数时使用
  ClusterItem copyWith({
    BitmapDescriptor? iconParam,
    LatLng? positionParam,
    double? rotationParam,
    ArgumentCallback<String?> ? onTapParam,
  }) {
    ClusterItem copyClusterItem = ClusterItem(
      icon: iconParam ?? icon,
      position: positionParam ?? position,
      rotation: rotationParam ?? rotation,
      onTap: onTapParam ?? onTap,
    );
    copyClusterItem.setIdForCopy(id);
    return copyClusterItem;
  }

  ClusterItem clone() => copyWith();

  @override
  Map<String, dynamic> toMap() {
    final Map<String, dynamic> json = <String, dynamic>{};

    void addIfPresent(String fieldName, dynamic value) {
      if (value != null) {
        json[fieldName] = value;
      }
    }

    addIfPresent('id', id);
    addIfPresent('icon', icon.toMap());
    addIfPresent('position', position.toJson());
    addIfPresent('rotation', rotation);
    return json;
  }

  dynamic _offsetToJson(Offset offset) {
    return <dynamic>[offset.dx, offset.dy];
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other.runtimeType != runtimeType) return false;
    if(other is !ClusterItem) return false;
    final ClusterItem typedOther = other;
    return id == typedOther.id &&
        icon == typedOther.icon &&
        position == typedOther.position &&
        rotation == typedOther.rotation;
  }

  @override
  int get hashCode => super.hashCode;

  @override
  String toString() {
    return 'ClusterItem{id: $id, icon: $icon, position: $position, rotation: $rotation, onTap: $onTap}';
  }
}

Map<String, ClusterItem> keyByClusterItemId(Iterable<ClusterItem> clusters) {
  return Map<String, ClusterItem>.fromEntries(clusters.map(
      (ClusterItem clusterItem) => MapEntry<String, ClusterItem>(clusterItem.id, clusterItem.clone())));
}
