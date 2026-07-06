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
    required String fullName,
    required String email,
    required String password,
    String? phoneNumber,
  }) async {
    final response = await _apiClient.dio.post(
      '/auth/register',
      data: {
        'fullName': fullName,
        'email': email,
        'password': password,
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
      },
    );
    return response.data;
  }
}
