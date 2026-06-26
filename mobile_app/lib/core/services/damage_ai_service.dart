import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../config/ai_config.dart';

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

  factory DamageItem.fromJson(Map<dynamic, dynamic> j) => DamageItem(
        part: (j['part'] ?? '').toString().trim(),
        issue: (j['issue'] ?? '').toString().trim(),
        severity: (j['severity'] ?? 'unknown').toString().trim().toLowerCase(),
        suggestion: (j['suggestion'] ?? '').toString().trim(),
      );
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

  factory DamageReport.fromJson(Map<String, dynamic> j) {
    final raw = (j['items'] as List?) ?? const [];
    return DamageReport(
      relevant: j['relevant'] != false, // default to relevant unless explicitly false
      component: (j['component'] ?? 'unknown').toString().trim().toLowerCase(),
      hasDamage: j['has_damage'] == true,
      summary: (j['summary'] ?? '').toString().trim(),
      recommendService: j['recommend_service'] == true,
      items: raw
          .whereType<Map>()
          .map(DamageItem.fromJson)
          .where((it) => it.part.isNotEmpty || it.issue.isNotEmpty)
          .toList(),
    );
  }
}

/// Photo → suggested damage report for motorbike TIRES and BRAKE PADS.
///
/// The whole "brain" lives behind this one static method, so swapping Gemini
/// for a backend proxy (or Claude) later only touches this file.
class DamageAiService {
  // ───────────────────────────────────────────────────────────────────────────
  // CHANGE SCOPE HERE: this prompt is what limits the scanner to a motorbike,
  // its tires, and its brake pads. To inspect more parts later (chain, lights),
  // edit the wording below and the example "component" values — nothing else
  // changes. The relevance/safety rules also live here.
  // ───────────────────────────────────────────────────────────────────────────
  static const String _prompt = '''
You are an AI inspection assistant for the CareBike app. You inspect motorbikes —
the whole BIKE, its TIRES, and its BRAKE PADS — from a single photo.

Base your answer strictly on what is clearly VISIBLE in the image. Do not guess
about hidden parts or internal wear you cannot actually see.

Relevance & safety rules (very important):
- The image is RELEVANT only if it clearly shows a motorbike, a motorbike tire,
  or a motorbike brake pad.
- If the image shows ANYTHING else — and ESPECIALLY adult / NSFW / 18+ / sexual,
  violent, gory, or otherwise inappropriate content, or any subject unrelated to
  a motorbike — set "relevant" to false, set "component" to "unknown", leave
  "items" empty, and put a brief, polite reason in "summary".
- Never describe or engage with inappropriate content. Just reject it.

Inspection rules:
- Set "component" to "bike" (whole motorbike), "tire", "brake_pad", or "unknown".
- If you see NO clear damage, set "has_damage" to false and leave "items" empty.
  Do NOT invent damage when you are not sure.
- "severity" must be one of: minor, moderate, severe, unknown.
- Write everything in clear, friendly English, short and easy to understand.
- This is only a reference suggestion, not a professional inspection.

Return ONLY valid JSON in exactly this structure, with no extra text:
{
  "relevant": true,
  "component": "bike",
  "has_damage": false,
  "summary": "1-2 sentence overview of the bike / tire / brake pad condition",
  "items": [
    {
      "part": "part name (e.g. front tire, rear brake pad, body)",
      "issue": "short description of the visible damage",
      "severity": "minor | moderate | severe | unknown",
      "suggestion": "short suggested action"
    }
  ],
  "recommend_service": false
}
''';

  static Future<DamageReport> analyze(Uint8List imageBytes) async {
    if (!isAiConfigured) {
      throw const AiException(
        'AI key not configured. Add your Gemini key in core/config/ai_config.dart.',
      );
    }

    try {
      final model = GenerativeModel(
        model: geminiModel,
        apiKey: geminiApiKey,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          temperature: 0.2,
        ),
      );

      final response = await model.generateContent([
        Content.multi([
          TextPart(_prompt),
          DataPart('image/jpeg', imageBytes),
        ]),
      ]);

      // Gemini's own safety filter blocked the image (e.g. NSFW/violent) before
      // it ever produced text → reject cleanly.
      if (response.promptFeedback?.blockReason != null) {
        throw const AiException(
          "This image can't be processed. Please use a clear photo of your bike, tire, or brake pad.",
        );
      }

      var text = response.text?.trim() ?? '';
      if (text.isEmpty) {
        throw const AiException('The AI returned no result. Please try again.');
      }

      text = _stripCodeFences(text);
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) {
        throw const AiException('Could not read the AI result. Please try again.');
      }
      return DamageReport.fromJson(decoded);
    } on AiException {
      rethrow;
    } on GenerativeAIException catch (e) {
      debugPrint('Gemini error: ${e.message}');
      throw AiException(_mapGemini(e.message));
    } on FormatException {
      throw const AiException('Could not read the AI result. Please try again.');
    } catch (e) {
      debugPrint('DamageAiService error: $e');
      final s = e.toString().toLowerCase();
      if (s.contains('socket') ||
          s.contains('host lookup') ||
          s.contains('connection') ||
          s.contains('network')) {
        throw const AiException(
          'No internet connection. Check your device/emulator network and try again.',
        );
      }
      throw AiException('Could not analyze the photo: $e');
    }
  }

  /// Turn a raw Gemini error message into a clear, actionable English one.
  static String _mapGemini(String m) {
    final s = m.toLowerCase();
    if (s.contains('safety') ||
        s.contains('blocked') ||
        s.contains('prohibited') ||
        s.contains('sexual') ||
        s.contains('harm')) {
      return "This image can't be processed. Please use a clear photo of your bike, tire, or brake pad.";
    }
    if (s.contains('api key') ||
        s.contains('api_key') ||
        s.contains('api key not valid') ||
        s.contains('invalid') ||
        s.contains('unauthor') ||
        s.contains('permission')) {
      return 'Invalid Gemini API key. A valid key starts with "AIza…" — '
          'get one at aistudio.google.com/app/apikey.';
    }
    if (s.contains('location') || s.contains('user location')) {
      return 'Your current region is not supported by Gemini yet (try a VPN to another region).';
    }
    if (s.contains('quota') ||
        s.contains('rate') ||
        s.contains('429') ||
        s.contains('exhausted')) {
      return 'Free usage limit reached. Please wait a moment and try again.';
    }
    if (s.contains('not found') || s.contains('not supported') || s.contains('model')) {
      return 'Model "$geminiModel" is not available for this key. '
          'Try "gemini-flash-latest" in ai_config.dart.';
    }
    return 'Gemini error: $m';
  }

  /// Some models still wrap JSON in ```json ... ``` fences despite the mime
  /// type request — strip them so jsonDecode succeeds.
  static String _stripCodeFences(String s) {
    var t = s.trim();
    if (t.startsWith('```')) {
      t = t.replaceFirst(RegExp(r'^```[a-zA-Z]*\s*'), '');
      if (t.endsWith('```')) {
        t = t.substring(0, t.length - 3);
      }
    }
    return t.trim();
  }
}
