import 'booking_model.dart';

class VehicleDto {
  final String id;
  final String customerId;
  final String licensePlate;
  final VehicleType vehicleType;
  final String brand;
  final String model;
  final String color;
  final bool isActive;

  VehicleDto({
    required this.id,
    required this.customerId,
    required this.licensePlate,
    required this.vehicleType,
    required this.brand,
    required this.model,
    required this.color,
    required this.isActive,
  });

  factory VehicleDto.fromJson(Map<String, dynamic> json) {
    return VehicleDto(
      id: json['id']?.toString() ?? '',
      customerId: json['customerId']?.toString() ?? '',
      licensePlate: json['licensePlate'] ?? '',
      vehicleType: VehicleType.values[json['vehicleType'] ?? 0],
      brand: json['brand'] ?? '',
      model: json['model'] ?? '',
      color: json['color'] ?? '',
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'customerId': customerId,
        'licensePlate': licensePlate,
        'vehicleType': vehicleType.index,
        'brand': brand,
        'model': model,
        'color': color,
      };

  String get vehicleTypeLabel {
    switch (vehicleType) {
      case VehicleType.sedan: return 'Sedan';
      case VehicleType.suv: return 'SUV';
      case VehicleType.motorcycle: return 'Xe máy';
    }
  }
}

class CreateVehicleDto {
  final String customerId;
  final String licensePlate;
  final VehicleType vehicleType;
  final String brand;
  final String model;
  final String color;

  CreateVehicleDto({
    required this.customerId,
    required this.licensePlate,
    required this.vehicleType,
    required this.brand,
    required this.model,
    required this.color,
  });

  Map<String, dynamic> toJson() => {
        'customerId': customerId,
        'licensePlate': licensePlate,
        'vehicleType': vehicleType.index,
        'brand': brand,
        'model': model,
        'color': color,
      };
}
