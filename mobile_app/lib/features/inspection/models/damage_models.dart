/// Shared data models for the photo inspection flow.
///
/// These are produced by [VisionApiService] (the Python YOLO API) and rendered
/// by the inspection result screen. Kept provider-agnostic so the scanner's
/// backend can change without touching the UI.

/// Thrown for any user-facing problem during analysis. [message] is already
/// in plain English and safe to show directly in the UI.
class AiException implements Exception {
  final String message;
  const AiException(this.message);
  @override
  String toString() => message;
}

/// One detected issue from the photo.
class DamageItem {
  final String part; // e.g. "front tire", "brake pad"
  final String issue; // short description of the visible problem
  final String severity; // minor | moderate | severe | unknown
  final String suggestion; // suggested action

  const DamageItem({
    required this.part,
    required this.issue,
    required this.severity,
    required this.suggestion,
  });
}

/// The full suggested report for one photo.
class DamageReport {
  final bool relevant; // false when the photo is NOT a bike, tire, or brake pad
  final String component; // bike | tire | brake_pad | unknown
  final bool hasDamage; // visible damage was found
  final String summary; // 1-2 sentence overview
  final List<DamageItem> items;
  final bool recommendService; // suggest booking a branch check

  const DamageReport({
    required this.relevant,
    required this.component,
    required this.hasDamage,
    required this.summary,
    required this.items,
    required this.recommendService,
  });
}
