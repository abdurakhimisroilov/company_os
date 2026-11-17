import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../bloc/employees_bloc.dart';
import '../../data/models/employee_model.dart';

class EmployeeDetailPage extends StatefulWidget {
  final String employeeId;

  const EmployeeDetailPage({super.key, required this.employeeId});

  @override
  State<EmployeeDetailPage> createState() => _EmployeeDetailPageState();
}

class _EmployeeDetailPageState extends State<EmployeeDetailPage> {
  @override
  void initState() {
    super.initState();
    context.read<EmployeesBloc>().add(LoadEmployeeDetailEvent(widget.employeeId));
  }

  void _showRoleDialog(EmployeeModel employee) {
    String selectedRole = employee.role;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
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
                    color: Colors.grey.shade300,
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
                        const Text(
                          'Назначение роли',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        Text(
                          employee.fullName,
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Выберите уровень доступа сотрудника в компании:',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),

              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: EmployeeRoleInfo.allRoles.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final role = EmployeeRoleInfo.allRoles[index];
                    final isSelected = selectedRole.toUpperCase() == role.id ||
                        (selectedRole.toUpperCase() == 'DEPARTMENT_MANAGER' && role.id == 'MANAGER');

                    return InkWell(
                      onTap: () => setSheetState(() => selectedRole = role.id),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected ? role.bgColor.withOpacity(0.7) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? role.color : Colors.grey.shade200,
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
                                      Text(
                                        role.title,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: isSelected ? role.color : AppColors.textPrimary,
                                        ),
                                      ),
                                      const Spacer(),
                                      if (isSelected)
                                        Icon(Icons.check_circle_rounded, color: role.color, size: 20)
                                      else
                                        Icon(Icons.radio_button_unchecked, color: Colors.grey.shade400, size: 20),
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

              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
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
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.read<EmployeesBloc>().add(
                              UpdateEmployeeRoleEvent(employeeId: employee.id, role: selectedRole),
                            );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Назначить роль', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditDialog(EmployeeModel employee) {
    final nameCtrl = TextEditingController(text: employee.fullName);
    final phoneCtrl = TextEditingController(text: employee.phone);
    final positionCtrl = TextEditingController(text: employee.position);
    final deptCtrl = TextEditingController(text: employee.departmentName ?? 'Общий');
    String selectedRole = employee.role;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Редактировать сотрудника'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'ФИО')),
                TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Телефон')),
                TextField(controller: positionCtrl, decoration: const InputDecoration(labelText: 'Должность')),
                TextField(controller: deptCtrl, decoration: const InputDecoration(labelText: 'Отдел')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: EmployeeRoleInfo.allRoles.any((r) => r.id == selectedRole)
                      ? selectedRole
                      : (selectedRole == 'DEPARTMENT_MANAGER' ? 'MANAGER' : 'EMPLOYEE'),
                  decoration: const InputDecoration(labelText: 'Роль в системе'),
                  items: EmployeeRoleInfo.allRoles.map((role) {
                    return DropdownMenuItem<String>(
                      value: role.id,
                      child: Row(
                        children: [
                          Icon(role.icon, size: 16, color: role.color),
                          const SizedBox(width: 8),
                          Text(role.title, style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setDlgState(() => selectedRole = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.read<EmployeesBloc>().add(
                      UpdateEmployeeEvent(
                        employeeId: employee.id,
                        data: {
                          'fullName': nameCtrl.text.trim(),
                          'phone': phoneCtrl.text.trim(),
                          'position': positionCtrl.text.trim(),
                          'departmentName': deptCtrl.text.trim(),
                          'role': selectedRole,
                        },
                      ),
                    );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Профиль сотрудника'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          BlocBuilder<EmployeesBloc, EmployeesState>(
            builder: (context, state) {
              if (state is EmployeeDetailLoaded) {
                return IconButton(
                  icon: const Icon(Icons.edit_outlined, color: AppColors.primaryBlue),
                  tooltip: 'Редактировать',
                  onPressed: () => _showEditDialog(state.employee),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: BlocConsumer<EmployeesBloc, EmployeesState>(
          listener: (context, state) {
            if (state is EmployeesActionSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message), backgroundColor: AppColors.success),
              );
            }
          },
          builder: (context, state) {
            if (state is EmployeesLoading) {
              return const LoadingShimmer();
            }
            if (state is EmployeeDetailLoaded) {
              return _buildContent(state.employee);
            }
            if (state is EmployeesError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(state.message, style: AppTextStyles.bodyMedium),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => context.read<EmployeesBloc>().add(LoadEmployeeDetailEvent(widget.employeeId)),
                      child: const Text('Повторить'),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildContent(EmployeeModel emp) {
    return ListView(
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
              const SizedBox(height: 4),
              Text(emp.position, style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
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
              const SizedBox(height: 12),

              // Action button to change role
              OutlinedButton.icon(
                onPressed: () => _showRoleDialog(emp),
                icon: const Icon(Icons.shield_outlined, size: 16),
                label: const Text('Назначить роль в системе'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: emp.roleColor,
                  side: BorderSide(color: emp.roleColor.withOpacity(0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),

              const Divider(height: 32),
              _infoRow('Email:', emp.email, Icons.email_outlined),
              _infoRow('Телефон:', emp.phone.isNotEmpty ? emp.phone : 'Не указан', Icons.phone_outlined),
              _infoRow('Отдел:', emp.departmentName ?? 'Общий', Icons.business_outlined),
              _infoRow('Статус:', emp.isActive ? 'Активен' : 'Заблокирован', Icons.check_circle_outline),
              _infoRow('Активных задач:', '${emp.activeTasksCount}', Icons.task_alt),
            ],
          ),
        ),
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
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
