import '../../data/datasources/api_client.dart';
import '../../data/models/feedback_model.dart';

class FeedbackRepository {
  final ApiClient _apiClient = ApiClient();

  Future<List<FeedbackDto>> getMyFeedbacks(String customerId) async {
    final res = await _apiClient.dio.get('/feedbacks/customer/$customerId');
    final List data = res.data is List ? res.data : (res.data['data'] ?? []);
    return data.map((e) => FeedbackDto.fromJson(e)).toList();
  }

  Future<void> createFeedback(FeedbackDto dto) async {
    await _apiClient.dio.post('/feedback', data: dto.toJson());
  }

  Future<List<PointLogDto>> getPointLogs(String customerId) async {
    final res = await _apiClient.dio.get('/point-logs/customer/$customerId');
    final List data = res.data is List ? res.data : (res.data['data'] ?? []);
    return data.map((e) => PointLogDto.fromJson(e)).toList();
  }
}
