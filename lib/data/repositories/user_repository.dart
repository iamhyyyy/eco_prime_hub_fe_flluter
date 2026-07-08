import '../../data/datasources/api_client.dart';
import '../../data/models/user_model.dart';

class UserRepository {
  final ApiClient _apiClient = ApiClient();

  Future<List<UserDto>> getAllUsers() async {
    final res = await _apiClient.dio.get('/users');
    final List data = res.data is List ? res.data : (res.data['data'] ?? []);
    return data.map((e) => UserDto.fromJson(e)).toList();
  }

  Future<UserDto> getUserById(String id) async {
    final res = await _apiClient.dio.get('/users/$id');
    return UserDto.fromJson(res.data);
  }

  Future<UserDto> updateUser(String id, Map<String, dynamic> data) async {
    final res = await _apiClient.dio.put('/users/$id', data: data);
    return UserDto.fromJson(res.data);
  }

  Future<void> changePassword(String id, String currentPassword, String newPassword) async {
    await _apiClient.dio.put('/users/$id/change-password', data: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }


  Future<void> lockUser(String id) async {
    await _apiClient.dio.put('/users/$id/lock');
  }

  Future<void> unlockUser(String id) async {
    await _apiClient.dio.put('/users/$id/unlock');
  }

  Future<UserDto> createUser(CreateUserDto dto) async {
    final res = await _apiClient.dio.post('/users', data: dto.toJson());
    return UserDto.fromJson(res.data);
  }
}
