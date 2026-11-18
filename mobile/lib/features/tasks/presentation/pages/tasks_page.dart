import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../bloc/tasks_bloc.dart';
import '../../data/models/task_model.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _filters = ['all', 'my', 'created'];
  final List<String> _filterLabels = ['Все', 'Мои задачи', 'Созданные мной'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _filters.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && _tabController.index != _loadedTab) _load();
    });
    // Coming back to the screen keeps the loaded list visible while it refreshes.
    final state = context.read<TasksBloc>().state;
    _load(silent: state is TasksLoaded && state.currentFilter == 'all');
  }

  int _loadedTab = 0;

  String get _currentUserId {
    final auth = context.read<AuthBloc>().state;
    return auth is AuthAuthenticated ? auth.user.id : '';
  }

  void _load({bool silent = false, Completer<void>? completer}) {
    _loadedTab = _tabController.index;
    context.read<TasksBloc>().add(LoadTasksEvent(
          filter: _filters[_tabController.index],
          currentUserId: _currentUserId,
          silent: silent,
          completer: completer,
        ));
  }

  Future<void> _refresh() {
    final completer = Completer<void>();
    _load(silent: true, completer: completer);
    return completer.future;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildHeader(),
              _buildTabs(),
              Expanded(
                child: BlocConsumer<TasksBloc, TasksState>(
                  listener: (context, state) {
                    if (state is TasksLoaded && state.refreshError != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(state.refreshError!), backgroundColor: AppColors.error),
                      );
                    }
                  },
                  builder: (context, state) {
                    if (state is TasksError) {
                      return _buildErrorState(state.message);
                    }
                    if (state is TasksLoaded) {
                      return _buildContent(state.tasks);
                    }
                    return const LoadingShimmer();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/tasks/add'),
        backgroundColor: AppColors.primaryBlue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Задание', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
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
              'Задания',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: AppColors.primaryBlue,
        ),
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        tabs: _filterLabels.map((l) => Tab(text: l)).toList(),
      ),
    );
  }

  Widget _buildContent(List<TaskModel> tasks) {
    if (tasks.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 60),
          children: [
            Center(
              child: Column(
                children: [
                  Icon(Icons.assignment_outlined, size: 56, color: AppColors.textTertiary),
                  const SizedBox(height: 12),
                  Text('Данных пока нет', style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary)),
                  const SizedBox(height: 6),
                  Text(_emptyHint, textAlign: TextAlign.center, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/tasks/add'),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Создать задачу'),
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
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          final task = tasks[index];
          return _buildTaskCard(task);
        },
      ),
    );
  }

  String get _emptyHint {
    switch (_filters[_tabController.index]) {
      case 'my':
        return 'Вам пока не назначено ни одной задачи';
      case 'created':
        return 'Вы пока не создали ни одной задачи';
      default:
        return 'Создайте задачу для сотрудников компании';
    }
  }

  Widget _buildTaskCard(TaskModel task) {
    Color priorityColor;
    if (task.priority == 'high' || task.priority == 'urgent') {
      priorityColor = AppColors.error;
    } else if (task.priority == 'medium') {
      priorityColor = AppColors.warning;
    } else {
      priorityColor = AppColors.success;
    }

    final isOverdue = task.isOverdue;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        onTap: () => context.push('/tasks/${task.id}'),
        padding: const EdgeInsets.all(16),
        borderRadius: 16,
        borderColor: isOverdue ? AppColors.error.withValues(alpha: 0.5) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isOverdue ? AppColors.error : AppColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: priorityColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    task.priorityDisplay,
                    style: TextStyle(color: priorityColor, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
            if (task.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                task.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
            const SizedBox(height: 12),
            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: task.progress,
                minHeight: 6,
                backgroundColor: AppColors.neutral200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  task.status == 'done' ? AppColors.success : AppColors.primaryBlue,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Assignee
                Expanded(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: AppColors.secondaryLavenderLight,
                        child: task.assignedToName.isNotEmpty
                            ? Text(
                                task.assignedToName.characters.first.toUpperCase(),
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              )
                            : Icon(Icons.person_outline, size: 14, color: AppColors.textPrimary),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          task.assignedToName.isNotEmpty ? task.assignedToName : 'Не назначен',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Deadline & Status
                Row(
                  children: [
                    if (task.deadline != null) ...[
                      Icon(
                        Icons.schedule,
                        size: 14,
                        color: isOverdue ? AppColors.error : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        Formatters.formatDate(task.deadline),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                          color: isOverdue ? AppColors.error : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        task.statusDisplay,
                        style: const TextStyle(color: AppColors.primaryBlue, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
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
            child: Text(message, textAlign: TextAlign.center, style: AppTextStyles.bodyMedium),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _load,
            child: const Text('Повторить'),
          ),
        ],
      ),
    );
  }
}
