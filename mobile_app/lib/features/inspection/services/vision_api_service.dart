import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:mobile_app/core/config/ai_config.dart';
import 'package:mobile_app/features/inspection/models/damage_models.dart';

/// Photo → damage report using the **Python YOLO vision API** in the
/// `python-vision-api` folder (FastAPI `main.py`, endpoint `POST
/// /api/vision/analyze`).
///
/// It uploads the photo as multipart form-data (field name `file`, matching the
/// FastAPI `UploadFile = File(...)` parameter) and converts the returned YOLO
/// detections into the same [DamageReport] the inspection result screen already
/// renders — so the UI is unchanged, only the "brain" behind the camera button
/// switches from Gemini to your own trained model.
class VisionApiService {
  static final Uri _endpoint = Uri.parse(
    '$visionApiBaseUrl/api/vision/analyze',
  );

  static Future<DamageReport> analyze(Uint8List imageBytes) async {
    try {
      final request = http.MultipartRequest('POST', _endpoint)
        ..files.add(
          http.MultipartFile.fromBytes(
            'file', // must match `file: UploadFile` in main.py
            imageBytes,
            filename: 'inspection.jpg',
          ),
        );

      final streamed = await request.send().timeout(
        const Duration(seconds: 45),
      );
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode >= 400) {
        throw AiException(
          'Vision server error (${response.statusCode}). '
          'Make sure the Python API is running: uvicorn main:app --host 0.0.0.0 --port 8000',
        );
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const AiException(
          'Could not read the vision result. Please try again.',
        );
      }

      // FastAPI returns {"status": "error", "message": ...} on failure.
      if (decoded['status'] != 'success') {
        final msg = (decoded['message'] ?? '').toString().trim();
        throw AiException(
          msg.isNotEmpty
              ? msg
              : 'Could not analyze the photo. Please try again.',
        );
      }

      final detections = (decoded['detections'] as List?) ?? const [];
      return _toReport(detections);
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
      final s = e.toString().toLowerCase();
      if (s.contains('socket') ||
          s.contains('host lookup') ||
          s.contains('connection') ||
          s.contains('refused') ||
          s.contains('network')) {
        throw AiException(
          "Can't reach the vision server at $visionApiBaseUrl. "
          'Check it is running and the IP is correct in core/config/ai_config.dart.',
        );
      }
      throw AiException('Could not analyze the photo: $e');
    }
  }

  /// Turn raw YOLO detections into a [DamageReport].
  static DamageReport _toReport(List<dynamic> detections) {
    final items = <DamageItem>[];
    var topConfidence = 0.0;

    for (final d in detections.whereType<Map>()) {
      final label = (d['label'] ?? '').toString().trim();
      final conf = (d['confidence'] is num)
          ? (d['confidence'] as num).toDouble()
          : 0.0;
      if (conf > topConfidence) topConfidence = conf;

      items.add(
        DamageItem(
          part: _friendlyLabel(label),
          issue:
              'Detected by the AI model (${(conf * 100).round()}% confidence).',
          severity: _severityFromConfidence(conf),
          suggestion: 'Have this checked at a CareBike branch to be safe.',
        ),
      );
    }

    final hasDamage = items.isNotEmpty;
    final recommend = items.any(
      (i) => i.severity == 'severe' || i.severity == 'moderate',
    );

    return DamageReport(
      relevant:
          true, // the YOLO model can't reject unrelated images; treat 0 hits as "looks fine"
      component: visionComponent,
      hasDamage: hasDamage,
      summary: hasDamage
          ? 'Found ${items.length} possible issue(s), with confidence up to '
                '${(topConfidence * 100).round()}%. See the details below.'
          : 'The AI model found no visible damage. It looks fine!',
      items: items,
      recommendService: recommend,
    );
  }

  /// Detection confidence is not the same as damage severity, but for this demo
  /// scanner a higher-confidence hit is surfaced more prominently.
  static String _severityFromConfidence(double conf) {
    if (conf >= 0.75) return 'severe';
    if (conf >= 0.50) return 'moderate';
    if (conf > 0) return 'minor';
    return 'unknown';
  }

  /// Make raw model class names readable. Extend this map to match the labels
  /// your `best.pt` was trained with (from Roboflow).
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
    // Title-case the raw label as a fallback.
    return label
        .split(RegExp(r'[_\s]+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
}
