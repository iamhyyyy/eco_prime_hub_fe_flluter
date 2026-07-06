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
    );
  }

  bool get isValid {
    final now = DateTime.now();
    return isActive && now.isAfter(validFrom) && now.isBefore(validTo);
  }

  String get promoTypeLabel {
    switch (promoType) {
      case PromoType.percentage: return 'Giảm ${discountPercent.toStringAsFixed(0)}%';
      case PromoType.flat: return 'Giảm ${discountAmount.toStringAsFixed(0)}đ';
      case PromoType.pointsMultiplier: return 'Nhân điểm';
      case PromoType.freeService: return 'Miễn phí';
    }
  }

  // So sánh theo id để Dropdown không bị crash khi reload data
  @override
  bool operator ==(Object other) => other is PromotionDto && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
