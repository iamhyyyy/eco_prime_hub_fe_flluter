import 'booking_model.dart';

class FeedbackDto {
  final String id;
  final String bookingId;
  final String customerId;
  final int rating;
  final String? comment;
  final DateTime createdAt;

  FeedbackDto({
    required this.id,
    required this.bookingId,
    required this.customerId,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  factory FeedbackDto.fromJson(Map<String, dynamic> json) {
    return FeedbackDto(
      id: json['id']?.toString() ?? '',
      bookingId: json['bookingId']?.toString() ?? '',
      customerId: json['customerId']?.toString() ?? '',
      rating: json['rating'] ?? 5,
      comment: json['comment'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'bookingId': bookingId,
        'customerId': customerId,
        'rating': rating,
        if (comment != null) 'comment': comment,
      };
}

class PointLogDto {
  final String id;
  final String customerId;
  final int points;
  final PointTransactionType transactionType;
  final String? note;
  final String? bookingId;
  final DateTime createdAt;
  final DateTime? expiresAt;

  PointLogDto({
    required this.id,
    required this.customerId,
    required this.points,
    required this.transactionType,
    this.note,
    this.bookingId,
    required this.createdAt,
    this.expiresAt,
  });

  factory PointLogDto.fromJson(Map<String, dynamic> json) {
    return PointLogDto(
      id: json['id']?.toString() ?? '',
      customerId: json['customerId']?.toString() ?? '',
      points: json['points'] ?? 0,
      transactionType: PointTransactionType.values[json['transactionType'] ?? 0],
      note: json['note'],
      bookingId: json['bookingId']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      expiresAt: json['expiresAt'] != null ? DateTime.tryParse(json['expiresAt']) : null,
    );
  }
}
