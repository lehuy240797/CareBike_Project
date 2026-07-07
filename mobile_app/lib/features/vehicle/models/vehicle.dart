class Vehicle {
  final int? id;
  final String brand;
  final String vehicleType;
  final String vehicleName;

  // 3 New data fields
  final String licensePlate;
  final int? engineCapacity;
  final int? currentKm;

  final int? ownerId;

  const Vehicle({
    this.id,
    required this.brand,
    required this.vehicleType,
    required this.vehicleName,
    required this.licensePlate,
    this.engineCapacity,
    this.currentKm,
    this.ownerId,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) => Vehicle(
    id: json['id'] as int?,
    brand: json['brand'] as String? ?? '',
    vehicleType: json['vehicleType'] as String? ?? 'XE_TAY_GA',
    vehicleName: json['vehicleName'] as String? ?? '',
    licensePlate: json['licensePlate'] as String? ?? '',
    engineCapacity: json['engineCapacity'] as int?,
    currentKm: json['currentKm'] as int?,
    ownerId: (json['owner'] as Map<String, dynamic>?)?['id'] as int?,
  );

  Map<String, dynamic> toJson() => {
    'brand': brand,
    'vehicleType': vehicleType,
    'vehicleName': vehicleName,
    'licensePlate': licensePlate,
    'engineCapacity': engineCapacity ?? 0,
    'currentKm': currentKm ?? 0,
  };

  String get typeLabel => vehicleType == 'XE_SO' ? 'Manual' : 'Scooter';
}