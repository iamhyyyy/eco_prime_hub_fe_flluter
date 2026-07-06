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
    return LoginResponse(
      isSuccess: json['isSuccess'] ?? false,
      token: json['token'],
      message: json['message'],
    );
  }
}
