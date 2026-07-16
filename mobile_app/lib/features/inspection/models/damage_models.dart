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

/// How deeply the user chose to inspect the part.
enum InspectionMode {
  quickScan,
  guidedFullCheck,
}

/// How much of the part the current photo set covers.
enum InspectionCoverageLevel {
  low,
  medium,
  high,
}

/// One detected issue from the photo.
class DamageItem {
  final String part; // e.g. "front tire", "brake pad"
  final String issue; // short description of the visible problem
  final String severity; // minor | moderate | severe | unknown
  final String suggestion; // suggested action
  final double confidence; // model confidence for this detected issue, 0..1
  final String sourceView; // e.g. "Center tread"

  const DamageItem({
    required this.part,
    required this.issue,
    required this.severity,
    required this.suggestion,
    required this.confidence,
    required this.sourceView,
  });
}

/// The full suggested report for a quick photo or a guided photo set.
class DamageReport {
  final bool relevant; // false when the photo is NOT a bike, tire, or brake pad
  final String component; // bike | tire | brake_pad | unknown
  final bool hasDamage; // visible damage was found
  final String summary; // 1-2 sentence overview
  final List<DamageItem> items;
  final bool recommendService; // suggest booking a branch check
  final InspectionMode mode;
  final InspectionCoverageLevel coverageLevel;
  final double detectionConfidence; // highest issue confidence, 0..1
  final int photosAnalyzed;
  final int requiredPhotos;
  final List<String> capturedViews;
  final String decisionTitle;
  final String decisionMessage;
  final String rideAdvice;
  final String nextAction;

  const DamageReport({
    required this.relevant,
    required this.component,
    required this.hasDamage,
    required this.summary,
    required this.items,
    required this.recommendService,
    required this.mode,
    required this.coverageLevel,
    required this.detectionConfidence,
    required this.photosAnalyzed,
    required this.requiredPhotos,
    required this.capturedViews,
    required this.decisionTitle,
    required this.decisionMessage,
    required this.rideAdvice,
    required this.nextAction,
  });

  String get modeLabel {
    switch (mode) {
      case InspectionMode.quickScan:
        return 'Quick scan';
      case InspectionMode.guidedFullCheck:
        return 'Guided full check';
    }
  }

  String get coverageLabel {
    switch (coverageLevel) {
      case InspectionCoverageLevel.low:
        return 'Low';
      case InspectionCoverageLevel.medium:
        return 'Medium';
      case InspectionCoverageLevel.high:
        return 'High';
    }
  }

  String get coverageDescription {
    if (mode == InspectionMode.quickScan) {
      return 'Single-photo coverage';
    }
    return '$photosAnalyzed/$requiredPhotos guided views';
  }

  String get detectionConfidenceLabel {
    if (!hasDamage || detectionConfidence <= 0) return 'No hit';
    return '${(detectionConfidence * 100).round()}%';
  }
}
