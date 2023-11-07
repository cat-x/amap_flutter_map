import 'dart:ui' show hashValues;

import 'package:flutter/foundation.dart' show setEquals;

import 'types.dart';
import 'cluster.dart';

class ClusterUpdates {
  ClusterUpdates.from(Set<ClusterItem> previous, Set<ClusterItem> current) {
    // ignore: unnecessary_null_comparison
    if (previous == null) {
      previous = Set<ClusterItem>.identity();
    }

    // ignore: unnecessary_null_comparison
    if (current == null) {
      current = Set<ClusterItem>.identity();
    }

    final Map<String, ClusterItem> previousClusters = keyByClusterItemId(previous);
    final Map<String, ClusterItem> currentClusters = keyByClusterItemId(current);

    final Set<String> prevClusterIds = previousClusters.keys.toSet();
    final Set<String> currentClusterIds = currentClusters.keys.toSet();

    ClusterItem idToCurrentClusterItem(String id) {
      return currentClusters[id]!;
    }

    final Set<String> _clusterIdsToRemove = prevClusterIds.difference(currentClusterIds);

    final Set<ClusterItem> _clustersToAdd = currentClusterIds
        .difference(prevClusterIds)
        .map(idToCurrentClusterItem)
        .toSet();

    bool hasChanged(ClusterItem current) {
      final ClusterItem? previous = previousClusters[current.id];
      return current != previous;
    }

    final Set<ClusterItem> _clustersToChange = currentClusterIds
        .intersection(prevClusterIds)
        .map(idToCurrentClusterItem)
        .where(hasChanged)
        .toSet();

    clustersToAdd = _clustersToAdd;
    clusterIdsToRemove = _clusterIdsToRemove;
    clustersToChange = _clustersToChange;
  }

  Set<ClusterItem>? clustersToAdd;

  Set<String>? clusterIdsToRemove;

  Set<ClusterItem>? clustersToChange;

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> updateMap = <String, dynamic>{};

    void addIfNonNull(String fieldName, dynamic value) {
      if (value != null) {
        updateMap[fieldName] = value;
      }
    }

    addIfNonNull('clustersToAdd', serializeOverlaySet(clustersToAdd!));
    addIfNonNull('clustersToChange', serializeOverlaySet(clustersToChange!));
    addIfNonNull('clusterIdsToRemove', clusterIdsToRemove?.toList());

    return updateMap;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other.runtimeType != runtimeType) return false;
    if(other is !ClusterUpdates) return false;
    final ClusterUpdates typedOther = other;
    return setEquals(clustersToAdd, typedOther.clustersToAdd) &&
        setEquals(clusterIdsToRemove, typedOther.clusterIdsToRemove) &&
        setEquals(clustersToChange, typedOther.clustersToChange);
  }

  @override
  int get hashCode =>
      hashValues(clustersToAdd, clusterIdsToRemove, clustersToChange);

  @override
  String toString() {
    return 'ClusterUpdates{clustersToAdd: $clustersToAdd, '
        'clusterIdsToRemove: $clusterIdsToRemove, '
        'clustersToChange: $clustersToChange}';
  }
}
