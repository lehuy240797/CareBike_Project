import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/features/inspection/models/vehicle_tire_spec_models.dart';

class VehicleTireSpecService {
  static Future<List<VehicleTireSpec>> getAll() async {
    final response = await ApiClient.get('/vehicle-tire-specs');
    final decoded = ApiClient.parseResponse(response);
    if (decoded is! List) return const [];

    return decoded
        .whereType<Map>()
        .map((item) => VehicleTireSpec.fromJson(Map<String, dynamic>.from(item)))
        .where((spec) => spec.id > 0)
        .toList(growable: false);
  }
}
