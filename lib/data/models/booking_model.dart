// Khai báo Enum trạng thái dựa trên SRS
enum BookingStatus { pending, confirmed, inProgress, completed, cancelled, noShow }
enum PaymentMethod { cash, transfer, points }

class BookingDto {
  final String id;
  final String customerId;
  final String vehicleId;
  final String serviceId;
  final DateTime scheduledTime;
  final double finalAmount;
  final BookingStatus status;
  final PaymentMethod paymentMethod;

  BookingDto({
    required this.id,
    required this.customerId,
    required this.vehicleId,
    required this.serviceId,
    required this.scheduledTime,
    required this.finalAmount,
    required this.status,
    required this.paymentMethod,
  });

  factory BookingDto.fromJson(Map<String, dynamic> json) {
    return BookingDto(
      id: json['id'],
      customerId: json['customerId'],
      vehicleId: json['vehicleId'],
      serviceId: json['serviceId'],
      scheduledTime: DateTime.parse(json['scheduledTime']),
      finalAmount: (json['finalAmount'] as num).toDouble(),
      status: BookingStatus.values[json['status']], // Map từ int sang Enum
      paymentMethod: PaymentMethod.values[json['paymentMethod']],
    );
  }
}