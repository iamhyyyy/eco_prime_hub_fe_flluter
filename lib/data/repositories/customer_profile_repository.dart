import '../../data/datasources/api_client.dart';
import '../../data/models/tier_model.dart';

class CustomerProfileRepository {
  final ApiClient _apiClient = ApiClient();

  Future<CustomerProfileDto> getProfileByCustomerId(String customerId) async {
    final res = await _apiClient.dio.get('/customer-profiles/$customerId');
    return CustomerProfileDto.fromJson(res.data);
  }

  Future<List<TierDto>> getAllTiers() async {
    final res = await _apiClient.dio.get('/tiers/active');
    final List data = res.data is List ? res.data : (res.data['data'] ?? []);
    return data.map((e) => TierDto.fromJson(e)).toList();
  }
}
