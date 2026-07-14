// ─── Enums ────────────────────────────────────────────────────────────────
enum BookingStatus { pending, confirmed, inProgress, completed, cancelled, noShow }
enum PaymentMethod { cash, transfer, points }

extension PaymentMethodX on PaymentMethod {
  String get label {
    switch (this) {
      case PaymentMethod.cash:
        return 'Tiền mặt';
      case PaymentMethod.transfer:
        return 'Chuyển khoản';
      case PaymentMethod.points:
        return 'Điểm thưởng';
    }
  }
}
enum VehicleType { motorbike, scooter, other }
enum PromoType { discount, freeWash, addon, pointBonus }
enum PointTransactionType { earn, redeem, expire, bonus, adjustment }

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

class UpdateBookingDto {
  final String? promoId;
  final DateTime scheduledTime;
  final DateTime? checkinTime;
  final DateTime? completedTime;
  final BookingStatus status;
  final PaymentMethod paymentMethod;
  final String? cancelReason;
  final String? staffNotes;

  UpdateBookingDto({
    this.promoId,
    required this.scheduledTime,
    this.checkinTime,
    this.completedTime,
    required this.status,
    required this.paymentMethod,
    this.cancelReason,
    this.staffNotes,
  });

  Map<String, dynamic> toJson() => {
        'promoId': promoId,
        'scheduledTime': scheduledTime.toUtc().toIso8601String(),
        if (checkinTime != null) 'checkinTime': checkinTime!.toUtc().toIso8601String(),
        if (completedTime != null) 'completedTime': completedTime!.toUtc().toIso8601String(),
        'status': status.index,
        'paymentMethod': paymentMethod.index,
        if (cancelReason != null) 'cancelReason': cancelReason,
        if (staffNotes != null) 'staffNotes': staffNotes,
      };
}