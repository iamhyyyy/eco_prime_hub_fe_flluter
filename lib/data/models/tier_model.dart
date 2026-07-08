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
  final String? currentTierName;
  final TierDto? currentTier;
  final int availablePoints;
  final int lifetimePoints;
  final int totalVisits;
  final double totalSpending;
  final DateTime? tierUpgradedAt;
  final DateTime? lastTierReviewDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? updateBy;

  CustomerProfileDto({
    required this.id,
    required this.currentTierId,
    this.currentTierName,
    this.currentTier,
    required this.availablePoints,
    required this.lifetimePoints,
    required this.totalVisits,
    required this.totalSpending,
    this.tierUpgradedAt,
    this.lastTierReviewDate,
    this.createdAt,
    this.updatedAt,
    this.updateBy,
  });

  String get tierDisplayName => currentTierName ?? currentTier?.name ?? 'Member';

  factory CustomerProfileDto.fromJson(Map<String, dynamic> json) {
    return CustomerProfileDto(
      id: json['id']?.toString() ?? '',
      currentTierId: json['currentTierId']?.toString() ?? '',
      currentTierName: json['currentTierName'],
      currentTier: json['currentTier'] != null ? TierDto.fromJson(json['currentTier']) : null,
      availablePoints: json['availablePoints'] ?? 0,
      lifetimePoints: json['lifetimePoints'] ?? 0,
      totalVisits: json['totalVisits'] ?? 0,
      totalSpending: (json['totalSpending'] as num?)?.toDouble() ?? 0.0,
      tierUpgradedAt: json['tierUpgradedAt'] != null ? DateTime.tryParse(json['tierUpgradedAt']) : null,
      lastTierReviewDate: json['lastTierReviewDate'] != null ? DateTime.tryParse(json['lastTierReviewDate']) : null,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt']) : null,
      updateBy: json['updateBy'],
    );
  }
}

class UpdateCustomerProfileDto {
  final String? currentTierId;
  final int? availablePoints;
  final int? lifetimePoints;
  final int? totalVisits;
  final double? totalSpending;
  final DateTime? tierUpgradedAt;
  final DateTime? lastTierReviewDate;

  UpdateCustomerProfileDto({
    this.currentTierId,
    this.availablePoints,
    this.lifetimePoints,
    this.totalVisits,
    this.totalSpending,
    this.tierUpgradedAt,
    this.lastTierReviewDate,
  });

  Map<String, dynamic> toJson() => {
    if (currentTierId != null) 'currentTierId': currentTierId,
    if (availablePoints != null) 'availablePoints': availablePoints,
    if (lifetimePoints != null) 'lifetimePoints': lifetimePoints,
    if (totalVisits != null) 'totalVisits': totalVisits,
    if (totalSpending != null) 'totalSpending': totalSpending,
    if (tierUpgradedAt != null) 'tierUpgradedAt': tierUpgradedAt!.toIso8601String(),
    if (lastTierReviewDate != null) 'lastTierReviewDate': lastTierReviewDate!.toIso8601String(),
  };
}
