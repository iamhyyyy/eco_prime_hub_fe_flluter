import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import '../../../data/datasources/api_client.dart';

// Định nghĩa các trạng thái UI có thể xảy ra
abstract class AuthState {}
class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}
class AuthSuccess extends AuthState { final String role; AuthSuccess(this.role); }
class AuthFailure extends AuthState { final String message; AuthFailure(this.message); }

class AuthCubit extends Cubit<AuthState> {
  final ApiClient apiClient = ApiClient();

  AuthCubit() : super(AuthInitial());

  Future<void> login(String email, String password) async {
    emit(AuthLoading());
    try {
      final response = await apiClient.dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });

      if (response.data['isSuccess'] == true) {
        String token = response.data['token'];
        // Lưu token lại cho các request sau
        await apiClient.storage.write(key: 'jwt_token', value: token);

        // Giả lập bóc tách hoặc đọc role để điều hướng giao diện (Role-based UI)
        emit(AuthSuccess("customer")); 
      } else {
        emit(AuthFailure(response.data['message'] ?? 'Đăng nhập thất bại'));
      }
    } catch (e) {
      emit(AuthFailure('Lỗi kết nối hệ thống!'));
    }
  }
}