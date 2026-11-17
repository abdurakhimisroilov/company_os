import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../data/models/employee_model.dart';
import '../bloc/employees_bloc.dart';

class AddEmployeePage extends StatefulWidget {
  const AddEmployeePage({super.key});

  @override
  State<AddEmployeePage> createState() => _AddEmployeePageState();
}

class _AddEmployeePageState extends State<AddEmployeePage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _positionController = TextEditingController();
  final _passwordController = TextEditingController();

  String _selectedDepartment = 'Продажи';
  String _selectedRole = 'EMPLOYEE';

  final List<String> _departments = ['IT', 'Продажи', 'Финансы', 'Склад', 'HR', 'Руководство'];

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _positionController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _saveEmployee() {
    if (!_formKey.currentState!.validate()) return;

    final data = {
      'fullName': _fullNameController.text.trim(),
      'email': _emailController.text.trim(),
      'phone': _phoneController.text.trim(),
      'position': _positionController.text.trim(),
      'departmentName': _selectedDepartment,
      'role': _selectedRole,
      'password': _passwordController.text.trim(),
    };

    context.read<EmployeesBloc>().add(CreateEmployeeEvent(data));
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Новый сотрудник'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  borderRadius: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ФИО сотрудника *', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _fullNameController,
                        decoration: _inputDeco('Алиев Тимур Бахтиярович'),
                        validator: (v) => (v == null || v.isEmpty) ? 'Введите ФИО' : null,
                      ),
                      const SizedBox(height: 16),

                      Text('Электронная почта (Логин) *', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _inputDeco('employee@company.uz'),
                        validator: (v) => (v == null || v.isEmpty) ? 'Введите email' : null,
                      ),
                      const SizedBox(height: 16),

                      Text('Номер телефона *', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: _inputDeco('+998 90 123 45 67'),
                        validator: (v) => (v == null || v.isEmpty) ? 'Введите телефон' : null,
                      ),
                      const SizedBox(height: 16),

                      Text('Должность *', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _positionController,
                        decoration: _inputDeco('Менеджер по продажам'),
                        validator: (v) => (v == null || v.isEmpty) ? 'Укажите должность' : null,
                      ),
                      const SizedBox(height: 16),

                      Text('Отдел', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedDepartment,
                            isExpanded: true,
                            items: _departments.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                            onChanged: (v) => setState(() => _selectedDepartment = v!),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text('Роль в системе', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedRole,
                            isExpanded: true,
                            items: EmployeeRoleInfo.allRoles.map((r) {
                              return DropdownMenuItem<String>(
                                value: r.id,
                                child: Row(
                                  children: [
                                    Icon(r.icon, size: 16, color: r.color),
                                    const SizedBox(width: 8),
                                    Text(r.title, style: const TextStyle(fontSize: 13)),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (v) => setState(() => _selectedRole = v!),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text('Временный пароль *', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: _inputDeco('••••••••'),
                        validator: (v) => (v == null || v.length < 6) ? 'Минимум 6 символов' : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                AppButton(
                  label: 'Зарегистрировать сотрудника',
                  onPressed: _saveEmployee,
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.cardBorder)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}
