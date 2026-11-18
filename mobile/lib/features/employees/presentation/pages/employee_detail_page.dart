import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/models/employee_model.dart';
import '../../data/repositories/employees_repository.dart';
import '../widgets/temporary_password_dialog.dart';

/// Profile of one employee. It loads and changes the employee through the
/// repository on its own, so the list behind it keeps its state; the list
/// reloads when this page is closed.
class EmployeeDetailPage extends StatefulWidget {
  final String employeeId;

  const EmployeeDetailPage({super.key, required this.employeeId});

  @override
  State<EmployeeDetailPage> createState() => _EmployeeDetailPageState();
}

class _EmployeeDetailPageState extends State<EmployeeDetailPage> {
  final _repository = getIt<EmployeesRepository>();
  EmployeeModel? _employee;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_employee == null) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final employee = await _repository.getEmployeeById(widget.employeeId);
      if (!mounted) return;
      setState(() {
        _employee = employee;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      final message = apiErrorMessage(e, fallback: 'Не удалось загрузить данные сотрудника');
      if (_employee != null) {
        _showSnack(message, isError: true);
      } else {
        setState(() {
          _isLoading = false;
          _error = message;
        });
      }
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), backgroundColor: isError ? AppColors.error : AppColors.success),
      );
  }

  /// Role and other fields the list does not return (recent tasks) stay as loaded.
  void _applyUpdate(EmployeeModel updated) {
    setState(() => _employee = updated.copyWith(recentActivity: _employee?.recentActivity));
  }

  Future<void> _showRoleSheet(EmployeeModel employee, {required bool canGrantSuperAdmin}) async {
    final updated = await showModalBottomSheet<EmployeeModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RoleSheet(
        repository: _repository,
        employee: employee,
        canGrantSuperAdmin: canGrantSuperAdmin,
      ),
    );
    if (updated == null || !mounted) return;
    _applyUpdate(updated);
    _showSnack('Роль успешно назначена');
  }

  Future<void> _showEditDialog(EmployeeModel employee, {required bool isSelf}) async {
    final updated = await showDialog<EmployeeModel>(
      context: context,
      builder: (_) => _EditEmployeeDialog(repository: _repository, employee: employee),
    );
    if (updated == null || !mounted) return;
    _applyUpdate(updated);
    _showSnack('Данные сотрудника обновлены');

    // The signed-in user's own name is shown elsewhere in the app.
    if (isSelf) {
      final authBloc = context.read<AuthBloc>();
      try {
        authBloc.add(UserUpdated(await getIt<AuthRepository>().fetchCurrentUser()));
      } catch (_) {}
    }
  }

  Future<void> _resetPassword(EmployeeModel employee) async {
    final password = await showDialog<String>(
      context: context,
      builder: (_) => _ConfirmActionDialog<String>(
        title: 'Сбросить пароль?',
        message:
            'Для сотрудника «${employee.fullName}» будет создан новый временный пароль. Прежний пароль перестанет работать, а сотрудник выйдет из системы на всех устройствах.',
        confirmLabel: 'Сбросить пароль',
        fallbackError: 'Не удалось сбросить пароль',
        action: () => _repository.resetPassword(employee.id),
      ),
    );
    if (password == null || !mounted) return;
    await showTemporaryPasswordDialog(
      context,
      title: 'Пароль сброшен',
      login: employee.email,
      password: password,
    );
  }

  Future<void> _removeEmployee(EmployeeModel employee) async {
    final removed = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmActionDialog<bool>(
        title: 'Удалить сотрудника?',
        message:
            'Сотрудник «${employee.fullName}» потеряет доступ к этой организации. Созданные им записи сохранятся.',
        confirmLabel: 'Удалить',
        isDanger: true,
        fallbackError: 'Не удалось удалить сотрудника',
        action: () async {
          await _repository.removeEmployee(employee.id);
          return true;
        },
      ),
    );
    if (removed != true || !mounted) return;
    _showSnack('Сотрудник удалён из организации');
    context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final me = auth is AuthAuthenticated ? auth.user : null;
    final employee = _employee;
    final isSelf = me != null && employee != null && me.id == employee.id;
    final isAdmin = me?.isAdmin ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Профиль сотрудника'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (employee != null && (isAdmin || isSelf))
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: AppColors.primaryBlue),
              tooltip: 'Редактировать',
              onPressed: () => _showEditDialog(employee, isSelf: isSelf),
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Builder(
          builder: (context) {
            if (employee != null) {
              return RefreshIndicator(
                onRefresh: _load,
                child: _buildContent(
                  employee,
                  canManage: isAdmin && !isSelf,
                  canGrantSuperAdmin: me?.role == 'SUPER_ADMIN',
                ),
              );
            }
            if (_isLoading) return const LoadingShimmer();
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                    const SizedBox(height: 12),
                    Text(
                      _error ?? 'Не удалось загрузить данные сотрудника',
                      style: AppTextStyles.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: _load, child: const Text('Повторить')),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent(EmployeeModel emp, {required bool canManage, required bool canGrantSuperAdmin}) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        GlassCard(
          padding: const EdgeInsets.all(20),
          borderRadius: 20,
          child: Column(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: emp.roleBgColor,
                child: Text(
                  emp.fullName.isNotEmpty ? emp.fullName[0].toUpperCase() : '?',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: emp.roleColor),
                ),
              ),
              const SizedBox(height: 14),
              Text(emp.fullName, style: AppTextStyles.titleLarge, textAlign: TextAlign.center),
              if (emp.position.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(emp.position, style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              ],
              const SizedBox(height: 12),

              // Role Badge with Icon & Color
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: emp.roleBgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: emp.roleColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(emp.roleIcon, color: emp.roleColor, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      emp.roleDisplay,
                      style: TextStyle(color: emp.roleColor, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),

              // Action button to change role (administrators only)
              if (canManage) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _showRoleSheet(emp, canGrantSuperAdmin: canGrantSuperAdmin),
                  icon: const Icon(Icons.shield_outlined, size: 16),
                  label: const Text('Назначить роль в системе'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: emp.roleColor,
                    side: BorderSide(color: emp.roleColor.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ],

              const Divider(height: 32),
              _infoRow('Email:', emp.email, Icons.email_outlined),
              _infoRow('Телефон:', emp.phone.isNotEmpty ? emp.phone : 'Не указан', Icons.phone_outlined),
              _infoRow('Отдел:', emp.departmentName ?? 'Не указан', Icons.business_outlined),
              _infoRow('Статус:', emp.isActive ? 'Активен' : 'Заблокирован', Icons.check_circle_outline),
              _infoRow('Активных задач:', '${emp.activeTasksCount}', Icons.task_alt),
            ],
          ),
        ),
        if (emp.recentActivity.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Последние задачи', style: AppTextStyles.titleMedium),
          const SizedBox(height: 8),
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            borderRadius: 16,
            child: Column(
              children: [
                for (final task in emp.recentActivity)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Icon(
                      task.status == 'done' ? Icons.task_alt : Icons.assignment_outlined,
                      color: task.status == 'done' ? AppColors.success : AppColors.primaryBlue,
                      size: 20,
                    ),
                    title: Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                    ),
                    subtitle: task.date != null
                        ? Text(Formatters.formatDateTime(task.date), style: AppTextStyles.caption)
                        : null,
                    trailing: Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.textTertiary),
                    onTap: () => context.push('/tasks/${task.id}'),
                  ),
              ],
            ),
          ),
        ],
        if (canManage) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _resetPassword(emp),
            icon: const Icon(Icons.lock_reset_rounded, size: 20),
            label: const Text('Сбросить пароль', style: TextStyle(fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryBlue,
              side: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _removeEmployee(emp),
            icon: const Icon(Icons.person_remove_outlined, color: AppColors.error, size: 20),
            label: const Text(
              'Удалить из организации',
              style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.errorLight, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _infoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Text(label, style: AppTextStyles.caption),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _inlineError(String message) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(color: AppColors.errorLight, borderRadius: BorderRadius.circular(12)),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: AppColors.error, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: const TextStyle(color: AppColors.error, fontSize: 13))),
      ],
    ),
  );
}

/// Confirmation that stays open while [action] runs and shows the server's
/// refusal in place. Pops with the action's result on success.
class _ConfirmActionDialog<T> extends StatefulWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String fallbackError;
  final bool isDanger;
  final Future<T> Function() action;

  const _ConfirmActionDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.fallbackError,
    required this.action,
    this.isDanger = false,
  });

  @override
  State<_ConfirmActionDialog<T>> createState() => _ConfirmActionDialogState<T>();
}

class _ConfirmActionDialogState<T> extends State<_ConfirmActionDialog<T>> {
  bool _isBusy = false;
  String? _error;

  Future<void> _run() async {
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      final result = await widget.action();
      if (mounted) Navigator.pop(context, result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _error = apiErrorMessage(e, fallback: widget.fallbackError);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isDanger ? AppColors.error : AppColors.primaryBlue;
    return PopScope(
      canPop: !_isBusy,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(widget.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.message),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _inlineError(_error!),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: _isBusy ? null : () => Navigator.pop(context), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: _isBusy ? null : _run,
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(widget.confirmLabel),
          ),
        ],
      ),
    );
  }
}

/// Role picker. Pops with the updated employee once the server accepted the role.
class _RoleSheet extends StatefulWidget {
  final EmployeesRepository repository;
  final EmployeeModel employee;
  final bool canGrantSuperAdmin;

  const _RoleSheet({required this.repository, required this.employee, required this.canGrantSuperAdmin});

  @override
  State<_RoleSheet> createState() => _RoleSheetState();
}

class _RoleSheetState extends State<_RoleSheet> {
  late String _selectedRole = EmployeeRoleInfo.fromId(widget.employee.role).id;
  bool _isSaving = false;
  String? _error;

  Future<void> _save() async {
    if (_selectedRole == EmployeeRoleInfo.fromId(widget.employee.role).id) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final updated = await widget.repository.updateEmployeeRole(widget.employee.id, _selectedRole);
      if (mounted) Navigator.pop(context, updated);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = apiErrorMessage(e, fallback: 'Не удалось изменить роль');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only the head of the organization may hand out the top role.
    final roles = EmployeeRoleInfo.allRoles
        .where((r) => r.id != 'SUPER_ADMIN' || widget.canGrantSuperAdmin || _selectedRole == 'SUPER_ADMIN')
        .toList();

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.neutral300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shield_outlined, color: AppColors.primaryBlue, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Назначение роли',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        Text(
                          widget.employee.fullName,
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Выберите уровень доступа сотрудника в компании:',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),

              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: roles.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final role = roles[index];
                    final isSelected = _selectedRole == role.id;

                    return InkWell(
                      onTap: _isSaving ? null : () => setState(() => _selectedRole = role.id),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected ? role.bgColor.withOpacity(0.7) : AppColors.neutral50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? role.color : AppColors.neutral200,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: role.bgColor,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(role.icon, color: role.color, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          role.title,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: isSelected ? role.color : AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      if (isSelected)
                                        Icon(Icons.check_circle_rounded, color: role.color, size: 20)
                                      else
                                        Icon(Icons.radio_button_unchecked, color: AppColors.neutral400, size: 20),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    role.description,
                                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                _inlineError(_error!),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Отмена'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Назначить роль', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
        ],
      ),
    );
  }
}

/// Name, phone, position and department. Pops with the updated employee.
class _EditEmployeeDialog extends StatefulWidget {
  final EmployeesRepository repository;
  final EmployeeModel employee;

  const _EditEmployeeDialog({required this.repository, required this.employee});

  @override
  State<_EditEmployeeDialog> createState() => _EditEmployeeDialogState();
}

class _EditEmployeeDialogState extends State<_EditEmployeeDialog> {
  late final _nameCtrl = TextEditingController(text: widget.employee.fullName);
  late final _phoneCtrl = TextEditingController(text: widget.employee.phone);
  late final _positionCtrl = TextEditingController(text: widget.employee.position);

  List<DepartmentModel>? _departments;
  String? _departmentsError;
  late String? _departmentId = widget.employee.departmentId;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _positionCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDepartments() async {
    setState(() => _departmentsError = null);
    try {
      final list = await widget.repository.getDepartmentList();
      if (!mounted) return;
      setState(() {
        _departments = list;
        if (!list.any((d) => d.id == _departmentId)) _departmentId = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _departmentsError = apiErrorMessage(e, fallback: 'Не удалось загрузить отделы'));
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Укажите ФИО сотрудника');
      return;
    }
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final updated = await widget.repository.updateEmployee(widget.employee.id, {
        'fullName': name,
        'phone': _phoneCtrl.text.trim(),
        'position': _positionCtrl.text.trim(),
        if (_departmentId != null && _departmentId != widget.employee.departmentId) 'departmentId': _departmentId,
      });
      if (mounted) Navigator.pop(context, updated);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = apiErrorMessage(e, fallback: 'Не удалось сохранить изменения');
      });
    }
  }

  Widget _buildDepartmentField() {
    final departments = _departments;
    if (_departmentsError != null) {
      return Row(
        children: [
          Expanded(child: Text(_departmentsError!, style: const TextStyle(color: AppColors.error, fontSize: 12))),
          TextButton(onPressed: _loadDepartments, child: const Text('Повторить')),
        ],
      );
    }
    if (departments == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: LinearProgressIndicator(minHeight: 2, color: AppColors.primaryBlue),
      );
    }
    return DropdownButtonFormField<String>(
      value: _departmentId,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Отдел'),
      hint: const Text('Не указан'),
      items: departments.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))).toList(),
      onChanged: _isSaving ? null : (v) => setState(() => _departmentId = v),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSaving,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Редактировать сотрудника'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameCtrl,
                enabled: !_isSaving,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'ФИО'),
              ),
              TextField(
                controller: _phoneCtrl,
                enabled: !_isSaving,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Телефон'),
              ),
              TextField(
                controller: _positionCtrl,
                enabled: !_isSaving,
                decoration: const InputDecoration(labelText: 'Должность'),
              ),
              _buildDepartmentField(),
              if (_error != null) ...[
                const SizedBox(height: 12),
                _inlineError(_error!),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: _isSaving ? null : () => Navigator.pop(context), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: _isSaving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Сохранить'),
          ),
        ],
      ),
    );
  }
}
