import '../../data/datasources/api_client.dart';
import '../../data/models/feedback_model.dart';

class FeedbackRepository {
  final ApiClient _apiClient = ApiClient();

  Future<List<FeedbackDto>> getAllFeedbacks() async {
    final res = await _apiClient.dio.get('/feedbacks');
    final List data = res.data is List ? res.data : (res.data['data'] ?? []);
    return data.map((e) => FeedbackDto.fromJson(e)).toList();
  }

  Future<FeedbackDto> getFeedbackById(String id) async {
    final res = await _apiClient.dio.get('/feedback/$id');
    return FeedbackDto.fromJson(res.data);
  }

  Future<List<FeedbackDto>> getMyFeedbacks(String customerId) async {
    final res = await _apiClient.dio.get('/feedbacks/customer/$customerId');
    final List data = res.data is List ? res.data : (res.data['data'] ?? []);
    return data.map((e) => FeedbackDto.fromJson(e)).toList();
  }

  Future<FeedbackDto> createFeedback(CreateFeedbackDto dto) async {
    final res = await _apiClient.dio.post('/feedback', data: dto.toJson());
    return FeedbackDto.fromJson(res.data);
  }

  Future<void> updateFeedback(String id, UpdateFeedbackDto dto) async {
    await _apiClient.dio.patch('/feedback/$id', data: dto.toJson());
  }

  Future<List<PointLogDto>> getPointLogs(String customerId) async {
    final res = await _apiClient.dio.get('/point-logs/customer/$customerId');
    final List data = res.data is List ? res.data : (res.data['data'] ?? []);
    return data.map((e) => PointLogDto.fromJson(e)).toList();
  }
}
