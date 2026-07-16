class VehicleTireSpec {
  final int id;
  final String brand;
  final String vehicleName;
  final String vehicleType;
  final int? engineCapacity;
  final String frontTireSize;
  final String rearTireSize;
  final String? note;

  const VehicleTireSpec({
    required this.id,
    required this.brand,
    required this.vehicleName,
    required this.vehicleType,
    required this.engineCapacity,
    required this.frontTireSize,
    required this.rearTireSize,
    required this.note,
  });

  factory VehicleTireSpec.fromJson(Map<String, dynamic> json) {
    return VehicleTireSpec(
      id: (json['id'] as num?)?.toInt() ?? 0,
      brand: json['brand'] as String? ?? '',
      vehicleName: json['vehicleName'] as String? ?? '',
      vehicleType: json['vehicleType'] as String? ?? '',
      engineCapacity: (json['engineCapacity'] as num?)?.toInt(),
      frontTireSize: json['frontTireSize'] as String? ?? '',
      rearTireSize: json['rearTireSize'] as String? ?? '',
      note: json['note'] as String?,
    );
  }

  String get modelLabel {
    final parts = [brand.trim(), vehicleName.trim()].where((part) => part.isNotEmpty);
    return parts.isEmpty ? 'Vehicle spec #$id' : parts.join(' ');
  }

  String get typeLabel => vehicleType == 'XE_SO' ? 'Manual' : 'Scooter';

  String get engineLabel => engineCapacity == null ? 'General' : '$engineCapacity cc';
}
