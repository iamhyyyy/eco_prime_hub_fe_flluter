import '../../data/datasources/api_client.dart';
import '../../data/models/auth_model.dart';

class AuthRepository {
  final ApiClient _apiClient = ApiClient();

  /// Đăng nhập và trả về LoginResponse (có token)
  Future<LoginResponse> login(String email, String password) async {
    final response = await _apiClient.dio.post(
      '/auth/login',
      data: LoginRequest(email: email, password: password).toJson(),
    );
    return LoginResponse.fromJson(response.data);
  }

  /// Đăng ký tài khoản mới
  Future<Map<String, dynamic>> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    DateTime? dateOfBirth,
  }) async {
    final response = await _apiClient.dio.post(
      '/auth/register',
      data: {
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'password': password,
        'dateOfBirth': dateOfBirth?.add(const Duration(hours: 7)).toIso8601String(),
      },
    );
    return response.data;
  }
}
