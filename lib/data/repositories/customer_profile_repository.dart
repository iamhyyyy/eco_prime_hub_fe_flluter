import '../../data/datasources/api_client.dart';
import '../../data/models/tier_model.dart';

class CustomerProfileRepository {
  final ApiClient _apiClient = ApiClient();

  /// Lấy tất cả customer profiles
  Future<List<CustomerProfileDto>> getAllProfiles() async {
    final res = await _apiClient.dio.get('/customer-profiles');
    final List data = res.data is List ? res.data : (res.data['data'] ?? []);
    return data.map((e) => CustomerProfileDto.fromJson(e)).toList();
  }

  /// Lấy profile theo customer ID
  Future<CustomerProfileDto> getProfileByCustomerId(String customerId) async {
    final res = await _apiClient.dio.get('/customer-profiles/$customerId');
    return CustomerProfileDto.fromJson(res.data);
  }

  /// Lấy profiles theo tier
  Future<List<CustomerProfileDto>> getProfilesByTier(String tierId) async {
    final res = await _apiClient.dio.get('/customer-profiles/tier/$tierId');
    final List data = res.data is List ? res.data : (res.data['data'] ?? []);
    return data.map((e) => CustomerProfileDto.fromJson(e)).toList();
  }

  /// Tạo mới customer profile
  Future<CustomerProfileDto> createProfile(String customerId, {String? tierId}) async {
    final body = <String, dynamic>{'id': customerId};
    if (tierId != null) body['currentTierId'] = tierId;
    final res = await _apiClient.dio.post('/customer-profiles', data: body);
    return CustomerProfileDto.fromJson(res.data);
  }

  /// Cập nhật customer profile
  Future<void> updateProfile(String id, UpdateCustomerProfileDto dto) async {
    await _apiClient.dio.put('/customer-profiles/$id', data: dto.toJson());
  }

  /// Cộng điểm cho customer
  Future<void> addPoints(String id, int points, {String? note, String? bookingId}) async {
    final queryParams = <String, dynamic>{'points': points};
    if (note != null) queryParams['note'] = note;
    if (bookingId != null) queryParams['bookingId'] = bookingId;
    await _apiClient.dio.post('/customer-profiles/$id/add-points', queryParameters: queryParams);
  }

  /// Đổi điểm (redeem)
  Future<void> redeemPoints(String id, int points, {String? note}) async {
    final queryParams = <String, dynamic>{'points': points};
    if (note != null) queryParams['note'] = note;
    await _apiClient.dio.post('/customer-profiles/$id/redeem-points', queryParameters: queryParams);
  }

  /// Lấy danh sách tiers đang active
  Future<List<TierDto>> getAllTiers() async {
    final res = await _apiClient.dio.get('/tiers/active');
    final List data = res.data is List ? res.data : (res.data['data'] ?? []);
    return data.map((e) => TierDto.fromJson(e)).toList();
  }
}

