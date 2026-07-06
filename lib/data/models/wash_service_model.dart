class WashServiceDto {
  final String id;
  final String name;
  final String? description;
  final double basePrice;
  final int estimatedDurationMinutes;
  final int pointsPerTransaction;
  final bool isActive;

  WashServiceDto({
    required this.id,
    required this.name,
    this.description,
    required this.basePrice,
    required this.estimatedDurationMinutes,
    required this.pointsPerTransaction,
    required this.isActive,
  });

  factory WashServiceDto.fromJson(Map<String, dynamic> json) {
    return WashServiceDto(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      basePrice: (json['basePrice'] as num?)?.toDouble() ?? 0.0,
      estimatedDurationMinutes: json['estimatedDurationMinutes'] ?? 0,
      pointsPerTransaction: json['pointsPerTransaction'] ?? 0,
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'basePrice': basePrice,
        'estimatedDurationMinutes': estimatedDurationMinutes,
        'pointsPerTransaction': pointsPerTransaction,
        'isActive': isActive,
      };
}
