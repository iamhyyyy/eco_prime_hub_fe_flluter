import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

/// Tiện ích đọc thông tin từ JWT Token (không cần gọi API)
class JwtHelper {
  static Map<String, dynamic>? _decodePayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      // Giải mã Base64 phần payload (phần thứ 2 của JWT)
      String payload = parts[1];
      // Thêm padding nếu thiếu
      while (payload.length % 4 != 0) {
        payload += '=';
      }
      final decoded = utf8.decode(base64Url.decode(payload));
      return jsonDecode(decoded) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Lấy role từ JWT Token
  static String? getRoleFromToken(String token) {
    final payload = _decodePayload(token);
    if (payload == null) return null;

    // .NET thường lưu role ở claim này
    return payload['http://schemas.microsoft.com/ws/2008/06/identity/claims/role']
        ?? payload['role']
        ?? payload['Role'];
  }

  /// Lấy userId từ JWT Token
  static String? getUserIdFromToken(String token) {
    final payload = _decodePayload(token);
    if (payload == null) return null;

    return payload['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier']
        ?? payload['sub']
        ?? payload['userId'];
  }

  /// Lấy email từ JWT Token
  static String? getEmailFromToken(String token) {
    final payload = _decodePayload(token);
    if (payload == null) return null;

    return payload['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress']
        ?? payload['email'];
  }

  /// Kiểm tra token có hết hạn chưa
  static bool isTokenExpired(String token) {
    final payload = _decodePayload(token);
    if (payload == null) return true;
    final exp = payload['exp'];
    if (exp == null) return false;
    final expDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    return DateTime.now().isAfter(expDate);
  }
}

/// Lớp lưu trữ thông tin user đã đăng nhập trong session
class AuthSession {
  static final _storage = const FlutterSecureStorage();
  static const _tokenKey = 'jwt_token';
  static const _userIdKey = 'user_id';
  static const _roleKey = 'user_role';

  static Future<void> save({
    required String token,
    required String userId,
    required String role,
  }) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userIdKey, value: userId);
    await _storage.write(key: _roleKey, value: role);
  }

  static Future<String?> getToken() => _storage.read(key: _tokenKey);
  static Future<String?> getUserId() => _storage.read(key: _userIdKey);
  static Future<String?> getRole() => _storage.read(key: _roleKey);

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    if (token == null) return false;
    return !JwtHelper.isTokenExpired(token);
  }

  static Future<void> clear() => _storage.deleteAll();
}
