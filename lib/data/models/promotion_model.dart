import 'booking_model.dart';

class PromotionDto {
  final String id;
  final String promoName;
  final String description;
  final String? minTierId;
  final PromoType promoType;
  final int pointsCost;
  final double discountAmount;
  final double discountPercent;
  final DateTime validFrom;
  final DateTime validTo;
  final int? maxUsesTotal;
  final int maxUsesPerCustomer;
  final bool isActive;
  final String? createdBy; // Thêm trường này theo database

  PromotionDto({
    required this.id,
    required this.promoName,
    required this.description,
    this.minTierId,
    required this.promoType,
    required this.pointsCost,
    required this.discountAmount,
    required this.discountPercent,
    required this.validFrom,
    required this.validTo,
    this.maxUsesTotal,
    required this.maxUsesPerCustomer,
    required this.isActive,
    this.createdBy,
  });

  factory PromotionDto.fromJson(Map<String, dynamic> json) {
    return PromotionDto(
      id: json['id']?.toString() ?? '',
      promoName: json['promoName'] ?? '',
      description: json['description'] ?? '',
      minTierId: json['minTierId']?.toString(),
      promoType: PromoType.values[json['promoType'] ?? 0],
      pointsCost: json['pointsCost'] ?? 0,
      discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0.0,
      discountPercent: (json['discountPercent'] as num?)?.toDouble() ?? 0.0,
      validFrom: DateTime.parse(json['validFrom']),
      validTo: DateTime.parse(json['validTo']),
      maxUsesTotal: json['maxUsesTotal'],
      maxUsesPerCustomer: json['maxUsesPerCustomer'] ?? 1,
      isActive: json['isActive'] ?? true,
      createdBy: json['createdBy']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'promoName': promoName,
      'description': description,
      'promoType': promoType.index,
      'pointsCost': pointsCost,
      'discountAmount': discountAmount,
      'discountPercent': discountPercent,
      'validFrom': validFrom.toUtc().toIso8601String(),
      'validTo': validTo.toUtc().toIso8601String(),
      'maxUsesPerCustomer': maxUsesPerCustomer,
      'isActive': isActive,
    };

    if (id.isNotEmpty) map['id'] = id;
    if (minTierId != null && minTierId!.isNotEmpty) map['minTierId'] = minTierId;
    if (maxUsesTotal != null) map['maxUsesTotal'] = maxUsesTotal;
    if (createdBy != null) map['createdBy'] = createdBy;

    return map;
  }

  bool get isValid {
    final now = DateTime.now();
    return isActive && now.isAfter(validFrom) && now.isBefore(validTo);
  }

  String get promoTypeLabel {
    switch (promoType) {
      case PromoType.discount:
        return discountAmount > 0
            ? 'Giảm ${discountAmount.toStringAsFixed(0)}đ'
            : 'Giảm ${discountPercent.toStringAsFixed(0)}%';
      case PromoType.freeWash:
        return 'Miễn phí rửa xe';
      case PromoType.addon:
        return discountAmount > 0
            ? 'Tặng kèm (Giảm ${discountAmount.toStringAsFixed(0)}đ)'
            : 'Tặng kèm (Giảm ${discountPercent.toStringAsFixed(0)}%)';
      case PromoType.pointBonus:
        return 'Tặng thêm $pointsCost điểm';
    }
  }

  @override
  bool operator ==(Object other) => other is PromotionDto && other.id == id;

  @override
  int get hashCode => id.hashCode;
}