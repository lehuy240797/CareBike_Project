class Appointment {
  final int id;
  final String appointmentDate;
  final String? note;
  final String status;
  final String? branchName;

  const Appointment({
    required this.id,
    required this.appointmentDate,
    this.note,
    required this.status,
    this.branchName,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) => Appointment(
        id: json['id'] as int,
        appointmentDate: json['appointmentDate'] as String? ?? '',
        note: json['note'] as String?,
        status: json['status'] as String? ?? 'PENDING',
        branchName: (json['branch'] as Map<String, dynamic>?)?['name'] as String?,
      );

  String get statusLabel {
    switch (status) {
      case 'CONFIRMED':  return 'Đã xác nhận';
      case 'COMPLETED':  return 'Hoàn thành';
      case 'CANCELLED':  return 'Đã hủy';
      default:           return 'Chờ xác nhận';
    }
  }

  bool get canCancel => status == 'PENDING' || status == 'CONFIRMED';

  String get formattedDate {
    try {
      // Format: 2024-06-15T10:30:00
      final dt = DateTime.parse(appointmentDate);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return appointmentDate;
    }
  }
}
