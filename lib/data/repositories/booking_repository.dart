import '../../data/datasources/api_client.dart';
import '../../data/models/booking_model.dart';

class BookingRepository {
  final ApiClient _apiClient = ApiClient();

  Future<List<BookingDto>> getAllBookings() async {
    final res = await _apiClient.dio.get('/bookings');
    final List data = res.data is List ? res.data : (res.data['data'] ?? []);
    return data.map((e) => BookingDto.fromJson(e)).toList();
  }

  Future<List<BookingDto>> getBookingsByCustomer(String customerId) async {
    final res = await _apiClient.dio.get('/bookings/customer/$customerId');
    final List data = res.data is List ? res.data : (res.data['data'] ?? []);
    return data.map((e) => BookingDto.fromJson(e)).toList();
  }

  Future<BookingDto> getBookingById(String id) async {
    final res = await _apiClient.dio.get('/booking/$id');
    return BookingDto.fromJson(res.data);
  }

  Future<BookingDto> createBooking(CreateBookingDto dto) async {
    final res = await _apiClient.dio.post('/booking', data: dto.toJson());
    return BookingDto.fromJson(res.data);
  }

  Future<void> updateBooking(String id, UpdateBookingDto dto) async {
    await _apiClient.dio.patch('/booking/$id', data: dto.toJson());
  }

  Future<void> cancelBooking(String id, String reason) async {
    try {
      await _apiClient.dio.delete('/booking/$id');
    } catch (_) {
      final booking = await getBookingById(id);
      await updateBooking(
        id,
        UpdateBookingDto(
          promoId: booking.promoId,
          scheduledTime: booking.scheduledTime,
          status: BookingStatus.cancelled,
          paymentMethod: booking.paymentMethod,
          cancelReason: reason.isEmpty ? null : reason,
        ),
      );
    }
  }

  Future<void> confirmBooking(BookingDto booking) async {
    await updateBooking(
      booking.id,
      UpdateBookingDto(
        promoId: booking.promoId,
        scheduledTime: booking.scheduledTime,
        status: BookingStatus.confirmed,
        paymentMethod: booking.paymentMethod,
        staffNotes: booking.staffNotes,
      ),
    );
  }

  Future<void> checkinBooking(BookingDto booking) async {
    await updateBooking(
      booking.id,
      UpdateBookingDto(
        promoId: booking.promoId,
        scheduledTime: booking.scheduledTime,
        checkinTime: DateTime.now(),
        status: BookingStatus.inProgress,
        paymentMethod: booking.paymentMethod,
        staffNotes: booking.staffNotes,
      ),
    );
  }

  Future<void> completeBooking(BookingDto booking) async {
    await updateBooking(
      booking.id,
      UpdateBookingDto(
        promoId: booking.promoId,
        scheduledTime: booking.scheduledTime,
        checkinTime: booking.checkinTime ?? DateTime.now(),
        completedTime: DateTime.now(),
        status: BookingStatus.completed,
        paymentMethod: booking.paymentMethod,
        staffNotes: booking.staffNotes,
      ),
    );
  }
}
