class UserDto {
  final String id;
  final String userName;
  final String email;
  final String firstName;
  final String lastName;
  final String? phoneNumber;
  final DateTime? dateOfBirth;
  final bool isActive;
  final String? role;

  UserDto({
    required this.id,
    required this.userName,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.phoneNumber,
    this.dateOfBirth,
    required this.isActive,
    this.role,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory UserDto.fromJson(Map<String, dynamic> json) {
    return UserDto(
      id: json['id']?.toString() ?? '',
      userName: json['userName'] ?? '',
      email: json['email'] ?? '',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      phoneNumber: json['phoneNumber'],
      dateOfBirth: json['dateOfBirth'] != null ? DateTime.tryParse(json['dateOfBirth']) : null,
      isActive: json['isActive'] ?? true,
      role: json['role'],
    );
  }

  Map<String, dynamic> toJson() => {
        'email': email,
        'phoneNumber': phoneNumber,
        'firstName': firstName,
        'lastName': lastName,
        if (dateOfBirth != null) 'dateOfBirth': dateOfBirth!.toIso8601String(),
        'isActive': isActive,
      };
}

class CreateUserDto {
  final String userName;
  final String email;
  final String password;
  final String firstName;
  final String lastName;
  final String? phoneNumber;
  final DateTime? dateOfBirth;
  final bool isActive;

  CreateUserDto({
    required this.userName,
    required this.email,
    required this.password,
    required this.firstName,
    required this.lastName,
    this.phoneNumber,
    this.dateOfBirth,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() => {
        'userName': userName,
        'email': email,
        'password': password,
        'firstName': firstName,
        'lastName': lastName,
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
        if (dateOfBirth != null) 'dateOfBirth': dateOfBirth!.toIso8601String(),
        'isActive': isActive,
      };
}
