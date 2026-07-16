import '../../data/datasources/api_client.dart';
import '../../data/models/vehicle_model.dart';

class VehicleRepository {
  final ApiClient _apiClient = ApiClient();

  Future<List<VehicleDto>> getMyVehicles(String customerId) async {
    final res = await _apiClient.dio.get('/vehicles/customer/$customerId');
    final List data = res.data is List ? res.data : (res.data['data'] ?? []);
    return data.map((e) => VehicleDto.fromJson(e)).toList();
  }

  Future<List<VehicleDto>> getAllVehicles() async {
    final res = await _apiClient.dio.get('/vehicles');
    final List data = res.data is List ? res.data : (res.data['data'] ?? []);
    return data.map((e) => VehicleDto.fromJson(e)).toList();
  }

  Future<VehicleDto> getVehicleById(String id) async {
    final res = await _apiClient.dio.get('/vehicle/$id');
    return VehicleDto.fromJson(res.data);
  }

  Future<VehicleDto> createVehicle(CreateVehicleDto dto) async {
    final res = await _apiClient.dio.post('/vehicle', data: dto.toJson());
    return VehicleDto.fromJson(res.data);
  }

  Future<void> updateVehicle(String id, UpdateVehicleDto dto) async {
    await _apiClient.dio.patch('/vehicle/$id', data: dto.toJson());
  }
}
