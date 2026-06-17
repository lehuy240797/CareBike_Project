class Branch {
  final int id;
  final String name;
  final String address;
  final String phone;
  final double? latitude;
  final double? longitude;
  final String status;

  Branch({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    this.latitude,
    this.longitude,
    required this.status,
  });

  factory Branch.fromJson(Map<String, dynamic> json) {
    return Branch(
      id: json['id'],
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      phone: json['phone'] ?? '',
      latitude: json['latitude'] != null ? double.parse(json['latitude'].toString()) : null,
      longitude: json['longitude'] != null ? double.parse(json['longitude'].toString()) : null,
      status: json['status'] ?? 'ACTIVE',
    );
  }
}