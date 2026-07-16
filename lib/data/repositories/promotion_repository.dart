import '../../data/datasources/api_client.dart';
import '../../data/models/promotion_model.dart';

class PromotionRepository {
  final ApiClient _apiClient = ApiClient();

  Future<List<PromotionDto>> getAllPromotions() async {
    final res = await _apiClient.dio.get('/promotions');
    final List data = res.data is List ? res.data : (res.data['data'] ?? []);
    return data.map((e) => PromotionDto.fromJson(e)).toList();
  }

  Future<PromotionDto> getPromotionById(String id) async {
    final res = await _apiClient.dio.get('/promotion/$id');
    return PromotionDto.fromJson(res.data);
  }

// Hàm create đang bị lỗi 405, hãy thử cách này:
  Future<void> createPromotion(Map<String, dynamic> data) async {
    try {
      // Đổi lại thành /promotion, in ra status code để dễ debug
      await _apiClient.dio.post('/promotion', data: data);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updatePromotion(String id, Map<String, dynamic> data) async {
    await _apiClient.dio.patch('/promotion/$id', data: data);
  }

  Future<void> deletePromotion(String id) async {
    await _apiClient.dio.delete('/promotion/$id');
  }
}
