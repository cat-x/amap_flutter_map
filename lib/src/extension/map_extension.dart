///
/// [Author] Alex (https://github.com/AlexV525)
/// [Date] 2021/12/28 11:38
///
extension MapExtension on Map<dynamic, dynamic> {
  void removeAllEmptyEntry() => removeWhere(
        (dynamic k, dynamic v) => k == null || v == null || v == '',
      );
}
