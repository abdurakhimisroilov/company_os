import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../data/models/employee_model.dart';
import '../../data/repositories/employees_repository.dart';
import '../widgets/temporary_password_dialog.dart';

class AddEmployeePage extends StatefulWidget {
  const AddEmployeePage({super.key});

  @override
  State<AddEmployeePage> createState() => _AddEmployeePageState();
}

class _AddEmployeePageState extends State<AddEmployeePage> {
  // Dropdown values that are not department ids.
  static const String _noDepartment = '';
  static const String _newDepartment = '__new__';

  final _repository = getIt<EmployeesRepository>();
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _positionController = TextEditingController();
  final _passwordController = TextEditingController();
  final _newDepartmentController = TextEditingController();

  List<DepartmentModel> _departments = [];
  bool _departmentsLoading = true;
  String? _departmentsError;
  String _selectedDepartment = _noDepartment;
  String _selectedRole = 'EMPLOYEE';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _positionController.dispose();
    _passwordController.dispose();
    _newDepartmentController.dispose();
    super.dispose();
  }

  Future<void> _loadDepartments() async {
    setState(() {
      _departmentsLoading = true;
      _departmentsError = null;
    });
    try {
      final list = await _repository.getDepartmentList();
      if (!mounted) return;
      setState(() {
        _departments = list;
        _departmentsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _departmentsLoading = false;
        _departmentsError = apiErrorMessage(e, fallback: 'Не удалось загрузить отделы');
      });
    }
  }

  Future<void> _saveEmployee() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final data = <String, dynamic>{
      'fullName': _fullNameController.text.trim(),
      'email': email,
      'phone': _phoneController.text.trim(),
      'position': _positionController.text.trim(),
      'role': _selectedRole,
      if (_selectedDepartment == _newDepartment)
        'departmentName': _newDepartmentController.text.trim()
      else if (_selectedDepartment != _noDepartment)
        'departmentId': _selectedDepartment,
      if (password.isNotEmpty) 'password': password,
    };

    setState(() => _isSaving = true);
    try {
      final created = await _repository.createEmployee(data);
      if (!mounted) return;

      final generated = created.temporaryPassword;
      if (generated != null) {
        await showTemporaryPasswordDialog(
          context,
          title: 'Сотрудник добавлен',
          login: created.employee.email.isNotEmpty ? created.employee.email : email,
          password: generated,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 6),
            content: Text(
              password.isNotEmpty
                  ? 'Сотрудник добавлен. Если этот адрес уже был зарегистрирован в Opero, сотрудник входит со своим прежним паролем'
                  : 'Сотрудник добавлен. Этот адрес уже зарегистрирован в Opero — сотрудник входит со своим паролем',
            ),
          ),
        );
      }
      if (mounted) context.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(apiErrorMessage(e, fallback: 'Не удалось добавить сотрудника')),
            backgroundColor: AppColors.error,
          ),
        );
    }
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
          icon: Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: _isSaving ? null : () => context.pop(),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
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
                        textCapitalization: TextCapitalization.words,
                        decoration: _inputDeco('Алиев Тимур Бахтиярович'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Введите ФИО' : null,
                      ),
                      const SizedBox(height: 16),

                      Text('Электронная почта (Логин) *', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        decoration: _inputDeco('employee@company.uz'),
                        validator: Validators.email,
                      ),
                      const SizedBox(height: 16),

                      Text('Номер телефона', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: _inputDeco('+998 90 123 45 67'),
                      ),
                      const SizedBox(height: 16),

                      Text('Должность', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _positionController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: _inputDeco('Менеджер по продажам'),
                      ),
                      const SizedBox(height: 16),

                      Text('Отдел', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 8),
                      _buildDepartmentPicker(),
                      const SizedBox(height: 16),

                      Text('Роль в системе', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
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
                                    Expanded(
                                      child: Text(
                                        r.title,
                                        style: const TextStyle(fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: _isSaving ? null : (v) => setState(() => _selectedRole = v!),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text('Пароль (необязательно)', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: _inputDeco('Не менее 6 символов'),
                        validator: (v) => (v != null && v.isNotEmpty && v.length < 6) ? 'Минимум 6 символов' : null,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Оставьте поле пустым — система создаст временный пароль и покажет его после сохранения.',
                        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                AppButton(
                  label: 'Зарегистрировать сотрудника',
                  isLoading: _isSaving,
                  onPressed: _isSaving ? null : _saveEmployee,
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDepartmentPicker() {
    if (_departmentsLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: LinearProgressIndicator(minHeight: 2, color: AppColors.primaryBlue),
      );
    }
    if (_departmentsError != null) {
      return Row(
        children: [
          Expanded(
            child: Text(_departmentsError!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
          ),
          TextButton(onPressed: _loadDepartments, child: const Text('Повторить')),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedDepartment,
              isExpanded: true,
              items: [
                const DropdownMenuItem(value: _noDepartment, child: Text('Без отдела')),
                ..._departments.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))),
                const DropdownMenuItem(value: _newDepartment, child: Text('Новый отдел…')),
              ],
              onChanged: _isSaving ? null : (v) => setState(() => _selectedDepartment = v ?? _noDepartment),
            ),
          ),
        ),
        if (_selectedDepartment == _newDepartment) ...[
          const SizedBox(height: 8),
          TextFormField(
            controller: _newDepartmentController,
            textCapitalization: TextCapitalization.sentences,
            decoration: _inputDeco('Название нового отдела'),
            validator: (v) => (_selectedDepartment == _newDepartment && (v == null || v.trim().isEmpty))
                ? 'Введите название отдела'
                : null,
          ),
        ],
      ],
    );
  }

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: AppColors.cardBackground,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.cardBorder)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}
