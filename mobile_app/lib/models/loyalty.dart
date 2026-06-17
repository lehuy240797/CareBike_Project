class LoyaltyProfile {
  final int accumulatedPoints;
  final String memberTier;
  final double totalSpent;

  const LoyaltyProfile({
    required this.accumulatedPoints,
    required this.memberTier,
    required this.totalSpent,
  });

  factory LoyaltyProfile.fromJson(Map<String, dynamic> json) => LoyaltyProfile(
        accumulatedPoints: json['accumulatedPoints'] as int? ?? 0,
        memberTier: json['memberTier'] as String? ?? 'STANDARD',
        totalSpent: (json['totalSpent'] as num?)?.toDouble() ?? 0.0,
      );

  String get tierLabel {
    switch (memberTier) {
      case 'SILVER':   return '🥈 Bạc';
      case 'GOLD':     return '🥇 Vàng';
      case 'PLATINUM': return '💎 Bạch kim';
      default:         return '⭐ Tiêu chuẩn';
    }
  }

  String get formattedSpent {
    return '${totalSpent.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.')} ₫';
  }
}
