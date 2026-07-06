// ─── Enums ────────────────────────────────────────────────────────────────
enum BookingStatus { pending, confirmed, inProgress, completed, cancelled, noShow }
enum PaymentMethod { cash, card, eWallet }
enum VehicleType { sedan, suv, motorcycle }
enum PromoType { percentage, flat, pointsMultiplier, freeService }
enum PointTransactionType { earned, redeemed, expired, refunded, adjusted }

// ─── BookingDto ───────────────────────────────────────────────────────────
class BookingDto {
  final String id;
  final String customerId;
  final String vehicleId;
  final String serviceId;
  final String? promoId;
  final DateTime scheduledTime;
  final DateTime? checkinTime;
  final DateTime? completedTime;
  final double finalAmount;
  final BookingStatus status;
  final PaymentMethod paymentMethod;
  final String? cancelReason;
  final String? staffNotes;

  BookingDto({
    required this.id,
    required this.customerId,
    required this.vehicleId,
    required this.serviceId,
    this.promoId,
    required this.scheduledTime,
    this.checkinTime,
    this.completedTime,
    required this.finalAmount,
    required this.status,
    required this.paymentMethod,
    this.cancelReason,
    this.staffNotes,
  });

  factory BookingDto.fromJson(Map<String, dynamic> json) {
    return BookingDto(
      id: json['id']?.toString() ?? '',
      customerId: json['customerId']?.toString() ?? '',
      vehicleId: json['vehicleId']?.toString() ?? '',
      serviceId: json['serviceId']?.toString() ?? '',
      promoId: json['promoId']?.toString(),
      scheduledTime: DateTime.parse(json['scheduledTime']),
      checkinTime: json['checkinTime'] != null ? DateTime.parse(json['checkinTime']) : null,
      completedTime: json['completedTime'] != null ? DateTime.parse(json['completedTime']) : null,
      finalAmount: (json['finalAmount'] as num?)?.toDouble() ?? 0.0,
      status: BookingStatus.values[json['status'] ?? 0],
      paymentMethod: PaymentMethod.values[json['paymentMethod'] ?? 0],
      cancelReason: json['cancelReason'],
      staffNotes: json['staffNotes'],
    );
  }
}

// ─── CreateBookingDto ─────────────────────────────────────────────────────
class CreateBookingDto {
  final String customerId;
  final String vehicleId;
  final String serviceId;
  final String? promoId;
  final DateTime scheduledTime;
  final PaymentMethod paymentMethod;
  final String? staffNotes;

  CreateBookingDto({
    required this.customerId,
    required this.vehicleId,
    required this.serviceId,
    this.promoId,
    required this.scheduledTime,
    required this.paymentMethod,
    this.staffNotes,
  });

  Map<String, dynamic> toJson() => {
        'customerId': customerId,
        'vehicleId': vehicleId,
        'serviceId': serviceId,
        'promoId': promoId,
        'scheduledTime': scheduledTime.toUtc().toIso8601String(),
        'paymentMethod': paymentMethod.index,
        'staffNotes': staffNotes,
      };
}