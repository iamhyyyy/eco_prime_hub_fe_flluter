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
    print("===== REQUEST JSON =====");
    print(dto.toJson());

    final res = await _apiClient.dio.post(
      '/booking',
      data: dto.toJson(),
    );

    return BookingDto.fromJson(res.data);
  }

  Future<void> cancelBooking(String id, String reason) async {
    await _apiClient.dio.patch('/booking/$id', data: {'cancelReason': reason});
  }

  Future<void> updateBookingStatus(String id, int status) async {
    await _apiClient.dio.patch('/booking/$id', data: {'status': status});
  }

  Future<void> checkinBooking(String id) async {
    await _apiClient.dio.patch('/booking/$id');
  }

  Future<void> completeBooking(String id) async {
    await _apiClient.dio.patch('/booking/$id/complete');
  }
}
