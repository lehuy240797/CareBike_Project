import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:mobile_app/core/config/ai_config.dart';
import 'package:mobile_app/features/inspection/models/damage_models.dart';

class VisionPhotoInput {
  final Uint8List imageBytes;
  final String viewName;

  const VisionPhotoInput({
    required this.imageBytes,
    required this.viewName,
  });
}

/// Photo analysis using the Python YOLO vision API in `python-vision-api`.
class VisionApiService {
  static final Uri _endpoint = Uri.parse('$visionApiBaseUrl/api/vision/analyze');
  static final Uri _precheckEndpoint = Uri.parse('$visionApiBaseUrl/api/vision/precheck');
  static const int guidedRequiredPhotoCount = 5;
  static const Map<String, String> _invalidLabelMessages = {
    'invalid_person': 'This photo may contain a person or face. Please upload only the tire area.',
    'invalid_house': 'This photo looks like a room, building, or indoor scene. Please capture the tire clearly.',
    'invalid_scenery': 'This photo looks like scenery, not a tire. Please capture the tire, tread, or sidewall.',
    'invalid_food': 'This photo looks like food. Please upload only the tire, tread, or sidewall.',
  };

  static Future<void> precheck(
    Uint8List imageBytes, {
    String sourceView = 'Inspection photo',
  }) async {
    try {
      final decoded = await _postImage(_precheckEndpoint, imageBytes);
      final status = (decoded['status'] ?? '').toString();
      if (status != 'success') {
        if (status == 'invalid_photo') {
          throw _invalidPhotoExceptionFrom(
            decoded,
            sourceView: sourceView,
            fallback: 'This photo is not suitable for tire inspection.',
          );
        }
        final msg = (decoded['message'] ?? '').toString().trim();
        throw AiException(msg.isNotEmpty ? msg : 'Could not verify this photo. Please try again.');
      }

      final precheck = _asMap(decoded['precheck']);
      if (precheck == null) {
        throw const AiException('Could not verify this photo. Please try a clearer tire photo.');
      }

      final valid = precheck['valid'] == true;
      if (!valid) {
        throw _invalidPhotoExceptionFrom(
          {'precheck': precheck},
          sourceView: sourceView,
          fallback: 'This photo does not look suitable for tire inspection.',
        );
      }
    } on AiException {
      rethrow;
    } on TimeoutException {
      throw const AiException('The vision server took too long to verify the photo. Please try again.');
    } on FormatException {
      throw const AiException('Could not read the pre-check result. Please try again.');
    } catch (e) {
      debugPrint('VisionApiService precheck error: $e');
      throw _networkAwareException(e, fallback: 'Could not verify this photo: $e');
    }
  }

  static Future<DamageReport> analyze(
    Uint8List imageBytes, {
    InspectionMode mode = InspectionMode.quickScan,
    String sourceView = 'Quick photo',
    bool verifyPhoto = true,
  }) async {
    if (verifyPhoto) {
      await precheck(imageBytes, sourceView: sourceView);
    }

    final detections = await _fetchDetections(imageBytes, sourceView: sourceView);
    return _toReport(
      detections,
      mode: mode,
      sourceView: sourceView,
      photosAnalyzed: 1,
      requiredPhotos: mode == InspectionMode.guidedFullCheck ? guidedRequiredPhotoCount : 1,
      capturedViews: [sourceView],
    );
  }

  static Future<DamageReport> analyzeGuided(List<VisionPhotoInput> photos) async {
    if (photos.isEmpty) {
      throw const AiException('Please capture at least one photo before analyzing.');
    }

    final items = <DamageItem>[];
    var topConfidence = 0.0;
    final views = photos.map((p) => p.viewName).toList(growable: false);

    for (final photo in photos) {
      final detections = await _fetchDetections(photo.imageBytes, sourceView: photo.viewName);
      final report = _toReport(
        detections,
        mode: InspectionMode.guidedFullCheck,
        sourceView: photo.viewName,
        photosAnalyzed: photos.length,
        requiredPhotos: guidedRequiredPhotoCount,
        capturedViews: views,
      );

      items.addAll(report.items);
      if (report.detectionConfidence > topConfidence) {
        topConfidence = report.detectionConfidence;
      }
    }

    return _buildReport(
      items: items,
      topConfidence: topConfidence,
      mode: InspectionMode.guidedFullCheck,
      photosAnalyzed: photos.length,
      requiredPhotos: guidedRequiredPhotoCount,
      capturedViews: views,
    );
  }

  static Future<List<dynamic>> _fetchDetections(
    Uint8List imageBytes, {
    required String sourceView,
  }) async {
    try {
      final decoded = await _postImage(_endpoint, imageBytes);
      final status = (decoded['status'] ?? '').toString();
      if (status != 'success') {
        if (status == 'invalid_photo') {
          throw _invalidPhotoExceptionFrom(
            decoded,
            sourceView: sourceView,
            fallback: 'This photo is not suitable for tire inspection.',
          );
        }
        final msg = (decoded['message'] ?? '').toString().trim();
        throw AiException(msg.isNotEmpty ? msg : 'Could not analyze the photo. Please try again.');
      }

      final precheck = _asMap(decoded['precheck']);
      if (precheck != null && precheck['valid'] == false) {
        throw _invalidPhotoExceptionFrom(
          decoded,
          sourceView: sourceView,
          fallback: 'This photo is not suitable for tire inspection.',
        );
      }

      return (decoded['detections'] as List?) ?? const [];
    } on AiException {
      rethrow;
    } on TimeoutException {
      throw const AiException(
        'The vision server took too long to respond. Please try again.',
      );
    } on FormatException {
      throw const AiException(
        'Could not read the vision result. Please try again.',
      );
    } catch (e) {
      debugPrint('VisionApiService error: $e');
      throw _networkAwareException(e, fallback: 'Could not analyze the photo: $e');
    }
  }

  static InvalidInspectionPhotoException _invalidPhotoExceptionFrom(
    Map<String, dynamic> payload, {
    required String sourceView,
    required String fallback,
  }) {
    final precheck = _asMap(payload['precheck']);
    final message = _invalidPhotoMessage(
      precheck,
      payloadMessage: (payload['message'] ?? '').toString(),
      fallback: fallback,
    );
    final invalidDetection = _topInvalidValidatorDetection(precheck);
    final label = _normalizeValidatorLabel((invalidDetection?['label'] ?? '').toString());
    final confidence = _asDouble(invalidDetection?['confidence']);
    final reason = (precheck?['reason'] ?? '').toString().trim();

    return InvalidInspectionPhotoException(
      _withSourceView(sourceView, message),
      reason: reason.isEmpty ? null : reason,
      label: label.isEmpty ? null : label,
      confidence: confidence > 0 ? confidence : null,
    );
  }

  static String _invalidPhotoMessage(
    Map<String, dynamic>? precheck, {
    required String payloadMessage,
    required String fallback,
  }) {
    final label = _normalizeValidatorLabel((_topInvalidValidatorDetection(precheck)?['label'] ?? '').toString());
    final labelMessage = _invalidLabelMessages[label];
    if (labelMessage != null) return labelMessage;

    final precheckMessage = (precheck?['message'] ?? '').toString().trim();
    if (precheckMessage.isNotEmpty) return precheckMessage;

    final msg = payloadMessage.trim();
    if (msg.isNotEmpty) return msg;

    final reason = (precheck?['reason'] ?? '').toString().trim();
    if (reason == 'low_quality') {
      return 'This photo is too unclear for tire inspection. Please retake it with the tire sharp and well lit.';
    }
    if (reason == 'person_or_sensitive_content') {
      return 'This photo may contain a person or sensitive content. Please upload only the tire area.';
    }
    if (reason == 'wrong_component') {
      return 'I could not confirm a tire in this photo. Please capture the tire, tread, or sidewall clearly.';
    }
    return fallback;
  }

  static Map<String, dynamic>? _topInvalidValidatorDetection(Map<String, dynamic>? precheck) {
    final validator = _asMap(precheck?['validator']);
    final detections = validator?['detections'];
    if (detections is! List) return null;
    final threshold = _asDouble(validator?['invalid_image_confidence_threshold']);
    final minConfidence = threshold > 0 ? threshold : 0.45;

    Map<String, dynamic>? best;
    var bestConfidence = -1.0;
    for (final raw in detections) {
      final item = _asMap(raw);
      if (item == null) continue;

      final label = _normalizeValidatorLabel((item['label'] ?? '').toString());
      if (!label.startsWith('invalid_')) continue;

      final confidence = _asDouble(item['confidence']);
      if (confidence < minConfidence) continue;
      if (confidence > bestConfidence) {
        best = item;
        bestConfidence = confidence;
      }
    }

    return best;
  }

  static String _withSourceView(String sourceView, String message) {
    final source = sourceView.trim();
    final msg = message.trim();
    if (source.isEmpty || msg.startsWith('$source:')) return msg;
    return '$source: $msg';
  }

  static Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }

  static double _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? '').toString()) ?? 0;
  }

  static String _normalizeValidatorLabel(String label) {
    return label.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
  }

  static Future<Map<String, dynamic>> _postImage(Uri endpoint, Uint8List imageBytes) async {
    final request = http.MultipartRequest('POST', endpoint)
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: 'inspection.jpg',
      ));

    final streamed = await request.send().timeout(const Duration(seconds: 45));
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode >= 400) {
      throw AiException(
        'Vision server error (${response.statusCode}). '
        'Make sure the Python API is running: uvicorn main:app --host 0.0.0.0 --port 8000',
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const AiException('Could not read the vision result. Please try again.');
    }

    return decoded;
  }

  static AiException _networkAwareException(Object e, {required String fallback}) {
    final s = e.toString().toLowerCase();
    if (s.contains('socket') ||
        s.contains('host lookup') ||
        s.contains('connection') ||
        s.contains('refused') ||
        s.contains('network')) {
      return AiException(
        "Can't reach the vision server at $visionApiBaseUrl. "
        'Check it is running and the IP is correct in core/config/ai_config.dart.',
      );
    }
    return AiException(fallback);
  }

  static DamageReport _toReport(
    List<dynamic> detections, {
    required InspectionMode mode,
    required String sourceView,
    required int photosAnalyzed,
    required int requiredPhotos,
    required List<String> capturedViews,
  }) {
    final items = <DamageItem>[];
    var topConfidence = 0.0;

    for (final d in detections.whereType<Map>()) {
      final label = (d['label'] ?? '').toString().trim();
      final conf = (d['confidence'] is num) ? (d['confidence'] as num).toDouble() : 0.0;
      if (conf > topConfidence) topConfidence = conf;

      items.add(DamageItem(
        part: _friendlyLabel(label),
        issue: _issueCopy(label),
        severity: _severityFromConfidence(conf),
        suggestion: _suggestionFor(label, conf),
        confidence: conf,
        sourceView: sourceView,
      ));
    }

    return _buildReport(
      items: items,
      topConfidence: topConfidence,
      mode: mode,
      photosAnalyzed: photosAnalyzed,
      requiredPhotos: requiredPhotos,
      capturedViews: capturedViews,
    );
  }

  static DamageReport _buildReport({
    required List<DamageItem> items,
    required double topConfidence,
    required InspectionMode mode,
    required int photosAnalyzed,
    required int requiredPhotos,
    required List<String> capturedViews,
  }) {
    final hasDamage = items.isNotEmpty;
    final recommend = items.any((i) => i.severity == 'severe' || i.severity == 'moderate');
    final coverageLevel = _coverageFor(mode, photosAnalyzed, requiredPhotos);
    final strongestSeverity = _strongestSeverity(items);
    final decision = _decisionCopy(hasDamage, strongestSeverity, mode);

    return DamageReport(
      relevant: true,
      component: visionComponent,
      hasDamage: hasDamage,
      summary: _summaryCopy(
        hasDamage: hasDamage,
        issueCount: items.length,
        mode: mode,
        photosAnalyzed: photosAnalyzed,
      ),
      items: items,
      recommendService: recommend,
      mode: mode,
      coverageLevel: coverageLevel,
      detectionConfidence: topConfidence,
      photosAnalyzed: photosAnalyzed,
      requiredPhotos: requiredPhotos,
      capturedViews: capturedViews,
      decisionTitle: decision.title,
      decisionMessage: decision.message,
      rideAdvice: decision.rideAdvice,
      nextAction: decision.nextAction,
    );
  }

  static InspectionCoverageLevel _coverageFor(
    InspectionMode mode,
    int photosAnalyzed,
    int requiredPhotos,
  ) {
    if (mode == InspectionMode.quickScan) return InspectionCoverageLevel.low;
    if (photosAnalyzed >= requiredPhotos) return InspectionCoverageLevel.high;
    if (photosAnalyzed >= 3) return InspectionCoverageLevel.medium;
    return InspectionCoverageLevel.low;
  }

  static String _strongestSeverity(List<DamageItem> items) {
    if (items.any((i) => i.severity == 'severe')) return 'severe';
    if (items.any((i) => i.severity == 'moderate')) return 'moderate';
    if (items.any((i) => i.severity == 'minor')) return 'minor';
    return 'none';
  }

  static _DecisionCopy _decisionCopy(bool hasDamage, String severity, InspectionMode mode) {
    if (!hasDamage) {
      if (mode == InspectionMode.quickScan) {
        return const _DecisionCopy(
          title: 'No obvious issue in this photo',
          message: 'The AI did not find visible damage in the uploaded image, but one photo cannot confirm the whole tire is safe.',
          rideAdvice: 'Ride normally only if the tire also looks and feels fine in real life.',
          nextAction: 'Run a guided full check for stronger coverage.',
        );
      }
      return const _DecisionCopy(
        title: 'No obvious issue across guided photos',
        message: 'The AI did not find clear visible damage in the guided photo set.',
        rideAdvice: 'Keep normal riding habits and continue routine tire checks.',
        nextAction: 'Recheck later if you notice slipping, vibration, cracks, or low pressure.',
      );
    }

    if (severity == 'severe') {
      return const _DecisionCopy(
        title: 'Needs attention before risky rides',
        message: 'A visible issue may affect grip or tire safety.',
        rideAdvice: 'Avoid rain, high speed, heavy loads, and long trips until checked.',
        nextAction: 'Have a technician inspect this tire as soon as possible.',
      );
    }

    if (severity == 'moderate') {
      return const _DecisionCopy(
        title: 'Schedule a check soon',
        message: 'The photo shows a possible wear or damage pattern that should not be ignored.',
        rideAdvice: 'Short, careful rides may be acceptable if there is no vibration or pressure loss.',
        nextAction: 'Book a tire check and avoid delaying maintenance.',
      );
    }

    return const _DecisionCopy(
      title: 'Monitor and recheck',
      message: 'The AI found a minor visible concern.',
      rideAdvice: 'Ride carefully and watch for changes in grip, noise, or pressure.',
      nextAction: 'Capture clearer guided photos or ask a technician during your next visit.',
    );
  }

  static String _summaryCopy({
    required bool hasDamage,
    required int issueCount,
    required InspectionMode mode,
    required int photosAnalyzed,
  }) {
    if (mode == InspectionMode.quickScan) {
      if (hasDamage) {
        return 'Possible issue found in the uploaded photo. Use this as a quick screen, then check more angles before judging the whole tire.';
      }
      return 'No clear issue was found in this photo. This is a quick screen only, not proof that the whole tire is safe.';
    }

    if (hasDamage) {
      return 'Detected $issueCount possible issue(s) across $photosAnalyzed guided photos. Review the priority and riding advice below.';
    }
    return 'No clear issue was detected across $photosAnalyzed guided photos. This improves coverage, but it is still not a professional safety check.';
  }

  static String _issueCopy(String label) {
    final key = label.toLowerCase();
    if (key.contains('wear') || key.contains('worn') || key.contains('mon')) {
      return 'Visible tread wear detected in this view.';
    }
    if (key.contains('crack')) return 'Visible crack-like damage detected in this view.';
    if (key.contains('tear') || key.contains('rach')) return 'Visible tear-like damage detected in this view.';
    if (key.contains('flat')) return 'Possible low-pressure or flat-tire sign detected.';
    if (key.contains('puncture') || key.contains('thung')) return 'Possible puncture sign detected.';
    return 'Visible issue detected by the AI model.';
  }

  static String _suggestionFor(String label, double conf) {
    final key = label.toLowerCase();
    if (conf >= 0.75) {
      return 'Have this checked at a CareBike branch before continuing risky rides.';
    }
    if (key.contains('wear') || key.contains('worn') || key.contains('mon')) {
      return 'Compare this with other tread areas and consider a technician check.';
    }
    return 'Capture more angles or have a technician confirm the issue.';
  }

  static String _severityFromConfidence(double conf) {
    if (conf >= 0.75) return 'severe';
    if (conf >= 0.50) return 'moderate';
    if (conf > 0) return 'minor';
    return 'unknown';
  }

  static String _friendlyLabel(String label) {
    if (label.isEmpty) return 'Damage';
    const map = <String, String>{
      'crack': 'Crack',
      'tear': 'Tear',
      'wear': 'Worn tread',
      'worn': 'Worn tread',
      'flat': 'Flat / low pressure',
      'puncture': 'Puncture',
      'rach': 'Tear',
      'mon': 'Worn tread',
      'thung': 'Puncture',
    };
    final key = label.toLowerCase();
    if (map.containsKey(key)) return map[key]!;
    return label
        .split(RegExp(r'[_\s]+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
}

class _DecisionCopy {
  final String title;
  final String message;
  final String rideAdvice;
  final String nextAction;

  const _DecisionCopy({
    required this.title,
    required this.message,
    required this.rideAdvice,
    required this.nextAction,
  });
}
