import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiClient {
  final Dio dio = Dio();
  final storage = const FlutterSecureStorage();

  ApiClient() {
    dio.options.baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:8080/api';
    dio.options.connectTimeout = const Duration(seconds: 10);

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Lấy token từ vùng nhớ bảo mật ra để gắn vào Header
          String? token = await storage.read(key: 'jwt_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
      ),
    );
  }
}