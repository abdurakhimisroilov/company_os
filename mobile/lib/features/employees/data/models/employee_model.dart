import 'package:flutter/material.dart';
import '../../../../core/utils/json_helpers.dart';
import '../../../../core/theme/app_colors.dart';

class EmployeeRoleInfo {
  final String id;
  final String title;
  final String shortTitle;
  final String description;
  final IconData icon;
  final Color color;
  final Color bgColor;

  const EmployeeRoleInfo({
    required this.id,
    required this.title,
    required this.shortTitle,
    required this.description,
    required this.icon,
    required this.color,
    required this.bgColor,
  });

  static const List<EmployeeRoleInfo> allRoles = [
    EmployeeRoleInfo(
      id: 'SUPER_ADMIN',
      title: 'Главный администратор',
      shortTitle: 'Главный админ',
      description: 'Владелец / Руководитель. Полный доступ ко всем модулям, финансам и назначению ролей.',
      icon: Icons.stars_rounded,
      color: Color(0xFF8B5CF6),
      bgColor: Color(0xFFF3E8FF),
    ),
    EmployeeRoleInfo(
      id: 'ADMIN',
      title: 'Администратор',
      shortTitle: 'Админ',
      description: 'Операционное управление. Управление персоналом, складом, закупками, сделками и задачами.',
      icon: Icons.security_rounded,
      color: AppColors.primaryBlue,
      bgColor: Color(0xFFEFF6FF),
    ),
    EmployeeRoleInfo(
      id: 'MANAGER',
      title: 'Менеджер проектов / CRM',
      shortTitle: 'Менеджер',
      description: 'Управление клиентами, воронка сделок, постановка и контроль задач.',
      icon: Icons.business_center_rounded,
      color: Color(0xFF06B6D4),
      bgColor: Color(0xFFECFEFF),
    ),
    EmployeeRoleInfo(
      id: 'ACCOUNTANT',
      title: 'Бухгалтер / Финансист',
      shortTitle: 'Бухгалтер',
      description: 'Финансовый учет, кассы, доходы, расходы, выплаты и расчет зарплат.',
      icon: Icons.account_balance_wallet_rounded,
      color: AppColors.success,
      bgColor: Color(0xFFECFDF5),
    ),
    EmployeeRoleInfo(
      id: 'WAREHOUSE_KEEPER',
      title: 'Кладовщик / Склад',
      shortTitle: 'Склад',
      description: 'Приемка поставок, контроль остатков товаров, списания и инвентаризация.',
      icon: Icons.inventory_2_rounded,
      color: AppColors.warning,
      bgColor: Color(0xFFFFFBEB),
    ),
    EmployeeRoleInfo(
      id: 'EMPLOYEE',
      title: 'Сотрудник / Специалист',
      shortTitle: 'Сотрудник',
      description: 'Выполнение назначенных задач, корпоративный мессенджер и файлы.',
      icon: Icons.person_rounded,
      color: Color(0xFF64748B),
      bgColor: Color(0xFFF1F5F9),
    ),
  ];

  static EmployeeRoleInfo fromId(String? roleId) {
    final cleanId = (roleId ?? 'EMPLOYEE').toUpperCase();
    if (cleanId == 'DEPARTMENT_MANAGER') {
      return allRoles.firstWhere((r) => r.id == 'MANAGER');
    }
    return allRoles.firstWhere(
      (r) => r.id == cleanId,
      orElse: () => allRoles.last, // EMPLOYEE
    );
  }
}

class EmployeeModel {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String? photoUrl;
  final String role; // 'SUPER_ADMIN', 'ADMIN', 'MANAGER', 'ACCOUNTANT', 'WAREHOUSE_KEEPER', 'EMPLOYEE'
  final String? departmentId;
  final String? departmentName;
  final String position;
  final bool isActive;
  final int activeTasksCount;
  final List<String> recentActivity;

  const EmployeeModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    this.photoUrl,
    required this.role,
    this.departmentId,
    this.departmentName,
    required this.position,
    this.isActive = true,
    this.activeTasksCount = 0,
    this.recentActivity = const [],
  });

  EmployeeRoleInfo get roleInfo => EmployeeRoleInfo.fromId(role);
  String get roleDisplay => roleInfo.title;
  String get roleShort => roleInfo.shortTitle;
  Color get roleColor => roleInfo.color;
  Color get roleBgColor => roleInfo.bgColor;
  IconData get roleIcon => roleInfo.icon;

  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
    final activity = JsonHelpers.toList(json['recentActivity'])
        .map((e) => e.toString())
        .toList();

    return EmployeeModel(
      id: JsonHelpers.toStr(json['id']),
      fullName: JsonHelpers.toStr(json['fullName'] ?? json['full_name'] ?? json['name'], 'Сотрудник'),
      email: JsonHelpers.toStr(json['email']),
      phone: JsonHelpers.toStr(json['phone']),
      photoUrl: JsonHelpers.extractOptionalString(json['photoUrl'] ?? json['avatarUrl'] ?? json['avatar']),
      role: JsonHelpers.toStr(json['role'], 'EMPLOYEE').toUpperCase(),
      departmentId: JsonHelpers.extractOptionalString(json['departmentId'] ?? json['department_id']),
      departmentName: JsonHelpers.extractOptionalString(
            json['department'],
            preferredKeys: ['name', 'title'],
          ) ??
          JsonHelpers.extractOptionalString(json['departmentName'] ?? json['department_name']) ??
          'Общий',
      position: JsonHelpers.toStr(json['position'], 'Специалист'),
      isActive: JsonHelpers.toBool(json['isActive'] ?? json['is_active'], true),
      activeTasksCount: JsonHelpers.toInt(json['activeTasksCount'] ?? json['tasks_count']),
      recentActivity: activity,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'role': role,
      'departmentName': departmentName,
      'position': position,
      'isActive': isActive,
    };
  }

  EmployeeModel copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phone,
    String? photoUrl,
    String? role,
    String? departmentId,
    String? departmentName,
    String? position,
    bool? isActive,
    int? activeTasksCount,
    List<String>? recentActivity,
  }) {
    return EmployeeModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      departmentId: departmentId ?? this.departmentId,
      departmentName: departmentName ?? this.departmentName,
      position: position ?? this.position,
      isActive: isActive ?? this.isActive,
      activeTasksCount: activeTasksCount ?? this.activeTasksCount,
      recentActivity: recentActivity ?? this.recentActivity,
    );
  }
}
