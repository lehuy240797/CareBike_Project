class MaintenanceRecord {
  final int id;
  final String serviceDate;
  final int? currentKm;
  final String? serviceDetails;
  final double? totalCost;
  final String? branchName;

  const MaintenanceRecord({
    required this.id,
    required this.serviceDate,
    this.currentKm,
    this.serviceDetails,
    this.totalCost,
    this.branchName,
  });

  factory MaintenanceRecord.fromJson(Map<String, dynamic> json) => MaintenanceRecord(
        id: json['id'] as int,
        serviceDate: json['serviceDate'] as String? ?? '',
        currentKm: json['currentKm'] as int?,
        serviceDetails: json['serviceDetails'] as String?,
        totalCost: (json['totalCost'] as num?)?.toDouble(),
        branchName: json['branchName'] as String? ??
            (json['branch'] as Map<String, dynamic>?)?['name'] as String?,
      );

  String get formattedCost {
    if (totalCost == null) return '—';
    return '${totalCost!.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.')} VND';
  }

  String get formattedDate {
    try {
      final parts = serviceDate.split('-');
      return '${parts[2]}/${parts[1]}/${parts[0]}';
    } catch (_) {
      return serviceDate;
    }
  }
}
