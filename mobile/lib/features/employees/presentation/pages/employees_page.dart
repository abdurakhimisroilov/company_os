import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../bloc/employees_bloc.dart';
import '../../data/models/employee_model.dart';

class EmployeesPage extends StatefulWidget {
  const EmployeesPage({super.key});

  @override
  State<EmployeesPage> createState() => _EmployeesPageState();
}

class _EmployeesPageState extends State<EmployeesPage> {
  final _searchController = TextEditingController();
  String? _selectedDepartmentId;

  @override
  void initState() {
    super.initState();
    context.read<EmployeesBloc>().add(const LoadEmployeesEvent());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Adding, editing roles and removing employees is for administrators.
  bool _isAdmin = false;

  Future<void> _reload() {
    final done = Completer<void>();
    context.read<EmployeesBloc>().add(LoadEmployeesEvent(
          departmentId: _selectedDepartmentId,
          search: _searchController.text.trim(),
          done: done,
        ));
    return done.future;
  }

  void _onDepartmentSelect(String? departmentId) {
    setState(() => _selectedDepartmentId = departmentId);
    _reload();
  }

  void _onSearch(String query) => _reload();

  Future<void> _openAdd() async {
    final added = await context.push<bool>(AppRoutes.employeeAdd);
    if (added == true && mounted) _reload();
  }

  Future<void> _openDetail(EmployeeModel emp) async {
    await context.push('/employees/${emp.id}');
    // The profile may have been edited or the employee removed.
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    _isAdmin = context.select<AuthBloc, bool>((bloc) {
      final auth = bloc.state;
      return auth is AuthAuthenticated && auth.user.isAdmin;
    });
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildHeader(),
              _buildSearchBar(),
              Expanded(
                child: BlocConsumer<EmployeesBloc, EmployeesState>(
                  listenWhen: (previous, current) => current is EmployeesLoaded && current.refreshError != null,
                  listener: (context, state) {
                    if (state is EmployeesLoaded && state.refreshError != null) {
                      // The list on screen belongs to the previous filter again.
                      setState(() => _selectedDepartmentId = state.selectedDepartmentId);
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(SnackBar(content: Text(state.refreshError!), backgroundColor: AppColors.error));
                    }
                  },
                  builder: (context, state) {
                    if (state is EmployeesLoading || state is EmployeesInitial) {
                      return const LoadingShimmer();
                    }
                    if (state is EmployeesError) {
                      return _buildErrorState(state.message);
                    }
                    if (state is EmployeesLoaded) {
                      return _buildContent(state);
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _isAdmin
          ? FloatingActionButton.extended(
              onPressed: _openAdd,
              backgroundColor: AppColors.primaryBlue,
              icon: const Icon(Icons.person_add, color: Colors.white),
              label: const Text('Сотрудник', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
            onPressed: () => context.pop(),
          ),
          Expanded(
            child: Text(
              'Сотрудники компании',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: TextField(
          controller: _searchController,
          onSubmitted: _onSearch,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Поиск по имени, email, телефону...',
            hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 14),
            prefixIcon: const Icon(Icons.search, color: AppColors.primaryBlue),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildDepartmentChip({required String label, required bool isSelected, required VoidCallback onSelected}) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primaryBlue,
      backgroundColor: AppColors.cardBackground.withOpacity(0.7),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      onSelected: (_) => onSelected(),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildContent(EmployeesLoaded state) {
    final isFiltered = state.selectedDepartmentId != null || state.searchQuery.isNotEmpty;
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (state.isRefreshing)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: LinearProgressIndicator(minHeight: 2, color: AppColors.primaryBlue),
            ),
          // Department chips
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: state.departments.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildDepartmentChip(
                    label: 'Все',
                    isSelected: state.selectedDepartmentId == null,
                    onSelected: () => _onDepartmentSelect(null),
                  );
                }
                final d = state.departments[index - 1];
                return _buildDepartmentChip(
                  label: d.name,
                  isSelected: d.id == state.selectedDepartmentId,
                  onSelected: () => _onDepartmentSelect(d.id),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          if (state.employees.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.badge_outlined, size: 56, color: AppColors.textTertiary),
                    const SizedBox(height: 12),
                    Text(
                      isFiltered ? 'Никого не найдено' : 'Данных пока нет',
                      style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isFiltered ? 'Измените запрос или выберите другой отдел' : 'В организации пока нет сотрудников',
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    if (_isAdmin && !isFiltered) ...[
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _openAdd,
                        icon: const Icon(Icons.person_add, size: 18),
                        label: const Text('Добавить сотрудника'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.78,
              ),
              itemCount: state.employees.length,
              itemBuilder: (context, index) {
                final emp = state.employees[index];
                return _buildEmployeeCard(emp);
              },
            ),

          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildEmployeeCard(EmployeeModel emp) {
    return GlassCard(
      onTap: () => _openDetail(emp),
      padding: const EdgeInsets.all(12),
      borderRadius: 18,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: emp.roleBgColor,
            backgroundImage:
                emp.photoUrl != null ? NetworkImage(getIt<ApiClient>().resolveFileUrl(emp.photoUrl!)) : null,
            child: emp.photoUrl == null
                ? Text(
                    emp.fullName.isNotEmpty ? emp.fullName[0].toUpperCase() : '?',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: emp.roleColor),
                  )
                : null,
          ),
          const SizedBox(height: 8),
          Text(
            emp.fullName,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            emp.position.isNotEmpty ? emp.position : emp.email,
            style: AppTextStyles.caption.copyWith(fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          // Role Badge with colored icon & text
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: emp.roleBgColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(emp.roleIcon, size: 11, color: emp.roleColor),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    emp.roleShort,
                    style: TextStyle(fontSize: 10, color: emp.roleColor, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            emp.departmentName ?? 'Без отдела',
            style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(message, style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _reload,
            child: const Text('Повторить'),
          ),
        ],
      ),
    );
  }
}
