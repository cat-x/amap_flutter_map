/// 高德地图Flutter插件入口文件
library amap_flutter_map;

import 'dart:async';
import 'dart:typed_data';

import 'package:amap_flutter_base/amap_flutter_base.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/core/amap_flutter_platform.dart';
import 'src/core/map_event.dart';
import 'src/core/method_channel_amap_flutter_map.dart';
import 'src/extension/map_extension.dart';
import 'src/types/types.dart';

export 'src/types/types.dart';

part 'src/amap_controller.dart';

part 'src/amap_widget.dart';
