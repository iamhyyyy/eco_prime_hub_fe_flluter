import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiClient {
  final Dio dio = Dio();
  final storage = const FlutterSecureStorage();

  ApiClient() {
    dio.options.baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:8080/api';
    // Tăng timeout cho Render free-tier (có thể mất 30-60s khi wake up)
    dio.options.connectTimeout = const Duration(seconds: 60);
    dio.options.receiveTimeout = const Duration(seconds: 60);

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Tự động gắn JWT Token vào mọi request
          String? token = await storage.read(key: 'jwt_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) {
          // Xử lý lỗi toàn cục
          return handler.next(e);
        },
      ),
    );
  }
}