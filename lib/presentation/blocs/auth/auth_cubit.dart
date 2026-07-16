import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../core/utils/jwt_helper.dart';

// ─── Trạng thái (States) ───────────────────────────────────────────────────
abstract class AuthState {}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthSuccess extends AuthState {
  final String role;
  final String userId;
  AuthSuccess({required this.role, required this.userId});
}

class AuthFailure extends AuthState {
  final String message;
  AuthFailure(this.message);
}

class RegisterSuccess extends AuthState {}

class RegisterFailure extends AuthState {
  final String message;
  RegisterFailure(this.message);
}

// ─── Cubit (Logic) ─────────────────────────────────────────────────────────
class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _repo = AuthRepository();

  AuthCubit() : super(AuthInitial());

  /// Đăng nhập
  Future<void> login(String email, String password) async {
    emit(AuthLoading());
    try {
      final response = await _repo.login(email, password);

      if (response.isSuccess && response.token != null) {
        final token = response.token!;

        // Giải mã JWT để lấy role và userId thật sự
        final role = JwtHelper.getRoleFromToken(token) ?? 'Customer';
        final userId = JwtHelper.getUserIdFromToken(token) ?? '';

        // Lưu session
        await AuthSession.save(token: token, userId: userId, role: role);

        emit(AuthSuccess(role: role, userId: userId));
      } else {
        emit(AuthFailure(response.message ?? 'Đăng nhập thất bại'));
      }
    } on DioException catch (e) {
      // ignore: avoid_print
      print('[AUTH] DioException TYPE: ${e.type}');
      // ignore: avoid_print
      print('[AUTH] DioException MESSAGE: ${e.message}');
      // ignore: avoid_print
      print('[AUTH] DioException ERROR: ${e.error}');
      // ignore: avoid_print
      print('[AUTH] DioException STATUS: ${e.response?.statusCode}');
      // ignore: avoid_print
      print('[AUTH] DioException DATA: ${e.response?.data}');

      String msg;
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.unknown) {
        msg = 'Không thể kết nối server. Kiểm tra internet hoặc server đang tắt!';
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        msg = 'Server phản hồi quá chậm, vui lòng thử lại!';
      } else if (e.type == DioExceptionType.badCertificate) {
        msg = 'Lỗi SSL/Certificate!';
      } else {
        msg = e.response?.data?['message']
            ?? e.response?.data?['Message']
            ?? 'Lỗi kết nối! (${e.response?.statusCode})';
      }
      emit(AuthFailure(msg));
    } catch (e, st) {
      // ignore: avoid_print
      print('[AUTH] Unknown error: $e\n$st');
      emit(AuthFailure('Lỗi: $e'));
    }
  }

  /// Đăng ký
  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    DateTime? dateOfBirth,
  }) async {
    emit(AuthLoading());
    try {
      await _repo.register(
        firstName: firstName,
        lastName: lastName,
        email: email,
        password: password,
        dateOfBirth: dateOfBirth,
      );
      emit(RegisterSuccess());
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Đăng ký thất bại!';
      emit(RegisterFailure(msg));
    } catch (_) {
      emit(RegisterFailure('Đã có lỗi xảy ra, vui lòng thử lại!'));
    }
  }

  /// Đăng xuất
  Future<void> logout() async {
    await AuthSession.clear();
    emit(AuthInitial());
  }

  /// Kiểm tra trạng thái đăng nhập khi mở app
  Future<void> checkLoginStatus() async {
    emit(AuthLoading()); // Đang kiểm tra → hiện splash
    final isLoggedIn = await AuthSession.isLoggedIn();
    if (isLoggedIn) {
      final role = await AuthSession.getRole() ?? 'Customer';
      final userId = await AuthSession.getUserId() ?? '';
      emit(AuthSuccess(role: role, userId: userId));
    } else {
      emit(AuthInitial()); // Chưa đăng nhập → vào LoginScreen
    }
  }
}