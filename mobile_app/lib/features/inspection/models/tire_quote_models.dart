enum TirePosition {
  front,
  rear,
}

extension TirePositionX on TirePosition {
  String get apiValue => this == TirePosition.front ? 'FRONT' : 'REAR';

  String get label => this == TirePosition.front ? 'Front tire' : 'Rear tire';
}

class TireQuoteOption {
  final int id;
  final String name;
  final double price;
  final String? description;
  final String? imageUrl;
  final int? categoryId;
  final String tireSize;
  final double laborMin;
  final double laborMax;
  final double estimateMin;
  final double estimateMax;
  final int fitConfidence;
  final String fitReason;

  const TireQuoteOption({
    required this.id,
    required this.name,
    required this.price,
    required this.description,
    required this.imageUrl,
    required this.categoryId,
    required this.tireSize,
    required this.laborMin,
    required this.laborMax,
    required this.estimateMin,
    required this.estimateMax,
    required this.fitConfidence,
    required this.fitReason,
  });

  factory TireQuoteOption.fromJson(Map<String, dynamic> json) {
    double money(String key) => (json[key] as num? ?? 0).toDouble();

    return TireQuoteOption(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      price: money('price'),
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      categoryId: json['categoryId'] as int?,
      tireSize: json['tireSize'] as String? ?? '',
      laborMin: money('laborMin'),
      laborMax: money('laborMax'),
      estimateMin: money('estimateMin'),
      estimateMax: money('estimateMax'),
      fitConfidence: (json['fitConfidence'] as num? ?? 0).toInt(),
      fitReason: json['fitReason'] as String? ?? '',
    );
  }
}

class TireRecommendation {
  final int vehicleId;
  final String brand;
  final String vehicleName;
  final TirePosition tirePosition;
  final String tireSize;
  final double laborMin;
  final double laborMax;
  final String quoteDisclaimer;
  final List<TireQuoteOption> options;

  const TireRecommendation({
    required this.vehicleId,
    required this.brand,
    required this.vehicleName,
    required this.tirePosition,
    required this.tireSize,
    required this.laborMin,
    required this.laborMax,
    required this.quoteDisclaimer,
    required this.options,
  });

  factory TireRecommendation.fromJson(Map<String, dynamic> json) {
    final positionValue = (json['tirePosition'] as String? ?? 'REAR').toUpperCase();
    final rawOptions = json['options'];
    final optionList = rawOptions is List
        ? rawOptions
            .whereType<Map>()
            .map((option) => TireQuoteOption.fromJson(Map<String, dynamic>.from(option)))
            .toList(growable: false)
        : <TireQuoteOption>[];

    return TireRecommendation(
      vehicleId: json['vehicleId'] as int? ?? 0,
      brand: json['brand'] as String? ?? '',
      vehicleName: json['vehicleName'] as String? ?? '',
      tirePosition: positionValue == 'FRONT' ? TirePosition.front : TirePosition.rear,
      tireSize: json['tireSize'] as String? ?? '',
      laborMin: (json['laborMin'] as num? ?? 0).toDouble(),
      laborMax: (json['laborMax'] as num? ?? 0).toDouble(),
      quoteDisclaimer: json['quoteDisclaimer'] as String? ?? '',
      options: optionList,
    );
  }
}
