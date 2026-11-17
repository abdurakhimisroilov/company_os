import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../bloc/employees_bloc.dart';
import '../../data/models/employee_model.dart';

class EmployeesPage extends StatefulWidget {
  const EmployeesPage({super.key});

  @override
  State<EmployeesPage> createState() => _EmployeesPageState();
}

class _EmployeesPageState extends State<EmployeesPage> {
  final _searchController = TextEditingController();
  String _selectedDepartment = 'Все';

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

  void _onDepartmentSelect(String dept) {
    setState(() => _selectedDepartment = dept);
    context.read<EmployeesBloc>().add(
          LoadEmployeesEvent(department: dept, search: _searchController.text.trim()),
        );
  }

  void _onSearch(String query) {
    context.read<EmployeesBloc>().add(
          LoadEmployeesEvent(department: _selectedDepartment, search: query),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildHeader(),
              _buildSearchBar(),
              Expanded(
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/employees/add'),
        backgroundColor: AppColors.primaryBlue,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Сотрудник', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
            onPressed: () => context.pop(),
          ),
          const Expanded(
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
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: TextField(
          controller: _searchController,
          onSubmitted: _onSearch,
          decoration: InputDecoration(
            hintText: 'Поиск по имени, должности...',
            hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 14),
            prefixIcon: const Icon(Icons.search, color: AppColors.primaryBlue),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(EmployeesLoaded state) {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<EmployeesBloc>().add(
              LoadEmployeesEvent(department: _selectedDepartment, search: _searchController.text.trim()),
            );
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Department chips
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: state.departments.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final d = state.departments[index];
                final isSelected = d == state.selectedDepartment;
                return ChoiceChip(
                  label: Text(d),
                  selected: isSelected,
                  selectedColor: AppColors.primaryBlue,
                  backgroundColor: Colors.white.withOpacity(0.7),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  onSelected: (_) => _onDepartmentSelect(d),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                    Text('Данных пока нет', style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary)),
                    const SizedBox(height: 6),
                    Text('Добавьте сотрудников в штат компании', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => context.push('/employees/add'),
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
      onTap: () => context.push('/employees/${emp.id}'),
      padding: const EdgeInsets.all(12),
      borderRadius: 18,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: emp.roleBgColor,
            backgroundImage: emp.photoUrl != null ? NetworkImage(emp.photoUrl!) : null,
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
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            emp.position,
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
            emp.departmentName ?? 'Общий',
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
          Text(message, style: AppTextStyles.bodyMedium),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.read<EmployeesBloc>().add(const LoadEmployeesEvent()),
            child: const Text('Повторить'),
          ),
        ],
      ),
    );
  }
}
