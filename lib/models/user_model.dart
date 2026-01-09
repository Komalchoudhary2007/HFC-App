class User {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String role;
  final DateTime createdAt;

  User({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    required this.role,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      email: json['email'] as String?,
      role: json['role'] as String? ?? 'USER',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'role': role,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'User{id: $id, name: $name, phone: $phone, email: $email}';
  }
}

class AuthResponse {
  final bool success;
  final String? message;
  final User? user;
  final String? token;
  final String? expiresIn;
  final String? error;
  final String? otpId;

  AuthResponse({
    required this.success,
    this.message,
    this.user,
    this.token,
    this.expiresIn,
    this.error,
    this.otpId,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String?,
      user: json['user'] != null ? User.fromJson(json['user']) : null,
      token: json['token'] as String?,
      expiresIn: json['expiresIn'] as String?,
      error: json['error'] as String?,
      otpId: json['otpId'] as String?,
    );
  }

  @override
  String toString() {
    return 'AuthResponse{success: $success, message: $message, user: $user, error: $error}';
  }
}

class HC20DataResponse {
  final bool success;
  final List<HC20Data> data;
  final int count;
  final Pagination? pagination;
  final String? error;

  HC20DataResponse({
    required this.success,
    required this.data,
    required this.count,
    this.pagination,
    this.error,
  });

  factory HC20DataResponse.fromJson(Map<String, dynamic> json) {
    return HC20DataResponse(
      success: json['success'] as bool? ?? false,
      data: json['data'] != null
          ? (json['data'] as List).map((e) => HC20Data.fromJson(e)).toList()
          : [],
      count: json['count'] as int? ?? 0,
      pagination: json['pagination'] != null
          ? Pagination.fromJson(json['pagination'])
          : null,
      error: json['error'] as String?,
    );
  }
}

class HC20Data {
  final String id;
  final String deviceId;
  final String? userId;
  final String timestamp;
  final int? heartRate;
  final int? spO2;
  final int? systolic;
  final int? diastolic;
  final double? bodyTemperature;
  final int? steps;
  final double? distance;
  final int? calories;
  final int? batteryLevel;
  final int? stressLevel;
  final int? sleepScore;

  HC20Data({
    required this.id,
    required this.deviceId,
    this.userId,
    required this.timestamp,
    this.heartRate,
    this.spO2,
    this.systolic,
    this.diastolic,
    this.bodyTemperature,
    this.steps,
    this.distance,
    this.calories,
    this.batteryLevel,
    this.stressLevel,
    this.sleepScore,
  });

  factory HC20Data.fromJson(Map<String, dynamic> json) {
    return HC20Data(
      id: json['id'] as String,
      deviceId: json['deviceId'] as String,
      userId: json['userId'] as String?,
      timestamp: json['timestamp'] as String,
      heartRate: json['heartRate'] as int?,
      spO2: json['spO2'] as int?,
      systolic: json['systolic'] as int?,
      diastolic: json['diastolic'] as int?,
      bodyTemperature: json['bodyTemperature'] != null
          ? (json['bodyTemperature'] as num).toDouble()
          : null,
      steps: json['steps'] as int?,
      distance:
          json['distance'] != null ? (json['distance'] as num).toDouble() : null,
      calories: json['calories'] as int?,
      batteryLevel: json['batteryLevel'] as int?,
      stressLevel: json['stressLevel'] as int?,
      sleepScore: json['sleepScore'] as int?,
    );
  }
}

class Pagination {
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  Pagination({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) {
    return Pagination(
      page: json['page'] as int,
      limit: json['limit'] as int,
      total: json['total'] as int,
      totalPages: json['totalPages'] as int,
    );
  }
}
