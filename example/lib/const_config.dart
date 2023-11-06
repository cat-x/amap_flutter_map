import 'package:amap_flutter_base/amap_flutter_base.dart';

class ConstConfig {
  static const AMapApiKey amapApiKeys = AMapApiKey(androidKey: '', iosKey: '');
  static const AMapPrivacyStatement amapPrivacyStatement = AMapPrivacyStatement(
    hasContains: true,
    hasShow: true,
    hasAgree: true,
  );
}
