// Model ánh xạ response từ API Login
class LoginRequest {
  final String email;
  final String password;

  LoginRequest({required this.email, required this.password});

  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
      };
}

class LoginResponse {
  final bool isSuccess;
  final String? token;
  final String? message;

  LoginResponse({
    required this.isSuccess,
    this.token,
    this.message,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    // ignore: avoid_print
    print('[AUTH] Parsing JSON: $json');
    return LoginResponse(
      // Hỗ trợ nhiều key có thể từ backend .NET
      isSuccess: json['isSuccess'] ?? json['IsSuccess'] ?? json['success'] ?? false,
      token: json['token'] ?? json['Token'] ?? json['accessToken'],
      message: json['message'] ?? json['Message'],
    );
  }
}
