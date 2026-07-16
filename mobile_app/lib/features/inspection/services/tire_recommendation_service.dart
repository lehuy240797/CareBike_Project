import 'dart:convert';

import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/features/inspection/models/tire_quote_models.dart';

class TireRecommendationService {
  static Future<TireRecommendation> getRecommendation({
    required int vehicleId,
    required TirePosition position,
  }) async {
    final response = await ApiClient.get(
      '/tire-recommendations?vehicleId=$vehicleId&position=${position.apiValue}',
    );
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));

    if (response.statusCode >= 400) {
      final message = decoded is Map
          ? (decoded['message'] ?? decoded['error'] ?? 'Could not prepare the tire estimate.')
          : 'Could not prepare the tire estimate.';
      throw TireRecommendationException(message.toString());
    }

    if (decoded is! Map) {
      throw const TireRecommendationException('Could not read the tire estimate.');
    }

    return TireRecommendation.fromJson(Map<String, dynamic>.from(decoded));
  }

  static Future<TireRecommendation> getRecommendationBySpec({
    required int specId,
    required TirePosition position,
  }) async {
    final response = await ApiClient.get(
      '/tire-recommendations/by-spec?specId=$specId&position=${position.apiValue}',
    );
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));

    if (response.statusCode >= 400) {
      final message = decoded is Map
          ? (decoded['message'] ?? decoded['error'] ?? 'Could not prepare the tire estimate.')
          : 'Could not prepare the tire estimate.';
      throw TireRecommendationException(message.toString());
    }

    if (decoded is! Map) {
      throw const TireRecommendationException('Could not read the tire estimate.');
    }

    return TireRecommendation.fromJson(Map<String, dynamic>.from(decoded));
  }
}

class TireRecommendationException implements Exception {
  final String message;
  const TireRecommendationException(this.message);

  @override
  String toString() => message;
}
