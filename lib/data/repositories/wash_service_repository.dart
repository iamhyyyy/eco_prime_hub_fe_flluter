import '../../data/datasources/api_client.dart';
import '../../data/models/wash_service_model.dart';

class WashServiceRepository {
  final ApiClient _apiClient = ApiClient();

  Future<List<WashServiceDto>> getAllServices() async {
    final res = await _apiClient.dio.get('/washes');
    final List data = res.data is List ? res.data : (res.data['data'] ?? []);
    return data.map((e) => WashServiceDto.fromJson(e)).toList();
  }

  Future<WashServiceDto> getServiceById(String id) async {
    final res = await _apiClient.dio.get('/wash/$id');
    return WashServiceDto.fromJson(res.data);
  }

  Future<void> createService(WashServiceDto s) async {
    await _apiClient.dio.post('/wash', data: s.toJson());
  }

  Future<void> updateService(String id, Map<String, dynamic> data) async {
    await _apiClient.dio.patch('/wash/$id', data: data);
  }

  Future<void> deleteService(String id) async {
    await _apiClient.dio.delete('/wash/$id');
  }
}
