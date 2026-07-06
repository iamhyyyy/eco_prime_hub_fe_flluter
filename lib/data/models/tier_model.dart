class TierDto {
  final String id;
  final String name;
  final int minPointsRequired;
  final int bookingWindowDays;
  final int priorityLevel;
  final double pointMultiplier;
  final String? perksDescription;
  final bool isActive;

  TierDto({
    required this.id,
    required this.name,
    required this.minPointsRequired,
    required this.bookingWindowDays,
    required this.priorityLevel,
    required this.pointMultiplier,
    this.perksDescription,
    required this.isActive,
  });

  factory TierDto.fromJson(Map<String, dynamic> json) {
    return TierDto(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      minPointsRequired: json['minPointsRequired'] ?? 0,
      bookingWindowDays: json['bookingWindowDays'] ?? 0,
      priorityLevel: json['priorityLevel'] ?? 0,
      pointMultiplier: (json['pointMultiplier'] as num?)?.toDouble() ?? 1.0,
      perksDescription: json['perksDescription'],
      isActive: json['isActive'] ?? true,
    );
  }
}

class CustomerProfileDto {
  final String id;
  final String currentTierId;
  final TierDto? currentTier;
  final int availablePoints;
  final int lifetimePoints;
  final int totalVisits;
  final double totalSpending;
  final DateTime? tierUpgradedAt;
  final DateTime lastTierReviewDate;

  CustomerProfileDto({
    required this.id,
    required this.currentTierId,
    this.currentTier,
    required this.availablePoints,
    required this.lifetimePoints,
    required this.totalVisits,
    required this.totalSpending,
    this.tierUpgradedAt,
    required this.lastTierReviewDate,
  });

  factory CustomerProfileDto.fromJson(Map<String, dynamic> json) {
    return CustomerProfileDto(
      id: json['id']?.toString() ?? '',
      currentTierId: json['currentTierId']?.toString() ?? '',
      currentTier: json['currentTier'] != null ? TierDto.fromJson(json['currentTier']) : null,
      availablePoints: json['availablePoints'] ?? 0,
      lifetimePoints: json['lifetimePoints'] ?? 0,
      totalVisits: json['totalVisits'] ?? 0,
      totalSpending: (json['totalSpending'] as num?)?.toDouble() ?? 0.0,
      tierUpgradedAt: json['tierUpgradedAt'] != null ? DateTime.tryParse(json['tierUpgradedAt']) : null,
      lastTierReviewDate: DateTime.parse(json['lastTierReviewDate']),
    );
  }
}
