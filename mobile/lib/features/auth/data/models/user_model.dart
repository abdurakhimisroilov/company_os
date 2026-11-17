import '../../../../core/utils/json_helpers.dart';

class UserModel {
  final String id;
  final String email;
  final String fullName;
  final String role;
  final String? departmentId;
  final String? departmentName;
  final String? phone;
  final String? avatarUrl;
  final bool isActive;
  final DateTime? createdAt;

  const UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.departmentId,
    this.departmentName,
    this.phone,
    this.avatarUrl,
    this.isActive = true,
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: JsonHelpers.toStr(json['id']),
      email: JsonHelpers.toStr(json['email']),
      fullName: JsonHelpers.toStr(json['fullName'] ?? json['name']),
      role: JsonHelpers.toStr(json['role'], 'EMPLOYEE').toUpperCase(),
      departmentId: JsonHelpers.extractOptionalString(json['departmentId']),
      departmentName: JsonHelpers.extractOptionalString(json['department'], preferredKeys: ['name', 'title']) ??
          JsonHelpers.extractOptionalString(json['departmentName']),
      phone: JsonHelpers.extractOptionalString(json['phone']),
      avatarUrl: JsonHelpers.extractOptionalString(json['avatarUrl'] ?? json['avatar'] ?? json['photoUrl']),
      isActive: JsonHelpers.toBool(json['isActive'], true),
      createdAt: JsonHelpers.toOptionalDateTime(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'fullName': fullName,
      'role': role,
      'departmentId': departmentId,
      'departmentName': departmentName,
      'phone': phone,
      'avatarUrl': avatarUrl,
      'isActive': isActive,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  bool get isAdmin => role == 'SUPER_ADMIN' || role == 'ADMIN';
  bool get isManager => role == 'MANAGER' || role == 'DEPARTMENT_MANAGER' || isAdmin;
  bool get isAccountant => role == 'ACCOUNTANT' || isAdmin;
  bool get isWarehouseKeeper => role == 'WAREHOUSE_KEEPER' || isAdmin;
}
