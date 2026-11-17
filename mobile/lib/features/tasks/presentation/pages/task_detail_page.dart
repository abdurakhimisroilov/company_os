import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../bloc/tasks_bloc.dart';
import '../../data/models/task_model.dart';
import '../../data/repositories/tasks_repository.dart';
import '../../../../core/di/injection.dart';

class TaskDetailPage extends StatefulWidget {
  final String taskId;

  const TaskDetailPage({super.key, required this.taskId});

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {
  final _commentController = TextEditingController();
  bool _isUploadingFile = false;

  @override
  void initState() {
    super.initState();
    context.read<TasksBloc>().add(LoadTaskDetailEvent(widget.taskId));
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _sendComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    context.read<TasksBloc>().add(AddTaskCommentEvent(taskId: widget.taskId, comment: text));
    _commentController.clear();
  }

  void _updateStatus(String status) {
    context.read<TasksBloc>().add(UpdateTaskStatusEvent(taskId: widget.taskId, status: status));
  }

  Future<void> _pickAndUploadAttachment() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx', 'doc', 'xlsx', 'xls', 'png', 'jpg'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() => _isUploadingFile = true);
        final file = File(result.files.single.path!);
        final repo = getIt<TasksRepository>();
        await repo.uploadTaskAttachment(widget.taskId, file);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Файл прикреплен: ${result.files.single.name}'), backgroundColor: AppColors.success),
          );
          // Refresh details
          context.read<TasksBloc>().add(LoadTaskDetailEvent(widget.taskId));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingFile = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Карточка задания'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: BlocConsumer<TasksBloc, TasksState>(
          listener: (context, state) {
            if (state is TasksActionSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message), backgroundColor: AppColors.success),
              );
            }
          },
          builder: (context, state) {
            if (state is TasksLoading) {
              return const LoadingShimmer();
            }
            if (state is TaskDetailLoaded) {
              return _buildContent(state.task);
            }
            if (state is TasksError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(state.message, style: AppTextStyles.bodyMedium),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => context.read<TasksBloc>().add(LoadTaskDetailEvent(widget.taskId)),
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

  Widget _buildContent(TaskModel task) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Main Task Info Card
              GlassCard(
                padding: const EdgeInsets.all(18),
                borderRadius: 20,
                borderColor: task.isOverdue ? AppColors.error.withValues(alpha: 0.5) : null,
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
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: task.isOverdue ? AppColors.error : AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            task.statusDisplay,
                            style: const TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(task.description.isNotEmpty ? task.description : 'Без описания', style: AppTextStyles.bodyMedium),
                    const Divider(height: 24),
                    // Progress bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Прогресс выполнения', style: AppTextStyles.caption),
                        Text('${(task.progress * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: task.progress,
                        minHeight: 8,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          task.status == 'done' ? AppColors.success : AppColors.primaryBlue,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _metaRow('Исполнитель:', task.assignedToName, Icons.person_outline),
                    _metaRow('Постановщик:', task.createdByName, Icons.badge_outlined),
                    _metaRow('Приоритет:', task.priorityDisplay, Icons.flag_outlined),
                    _metaRow(
                      'Дедлайн:',
                      Formatters.formatDate(task.deadline) + (task.isOverdue ? ' (Просрочено!)' : ''),
                      Icons.schedule,
                      isOverdue: task.isOverdue,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Attached Files (DOCX, PDF, etc.)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Прикрепленные файлы (${task.attachments.length})', style: AppTextStyles.titleMedium),
                  TextButton.icon(
                    onPressed: _isUploadingFile ? null : _pickAndUploadAttachment,
                    icon: _isUploadingFile
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.upload_file, size: 18),
                    label: const Text('Прикрепить DOCX/PDF'),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              if (task.attachments.isEmpty)
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  borderRadius: 14,
                  child: Center(
                    child: Text('Файлы еще не прикреплены', style: AppTextStyles.caption),
                  ),
                )
              else
                ...task.attachments.map((fileUrl) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: GlassCard(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        borderRadius: 12,
                        child: Row(
                          children: [
                            const Icon(Icons.description, color: AppColors.primaryBlue, size: 24),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                fileUrl.split('/').last,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.check_circle, color: AppColors.success, size: 18),
                          ],
                        ),
                      ),
                    )),
              const SizedBox(height: 16),

              // Action buttons depending on status (10-step lifecycle)
              Text('Действия по заданию', style: AppTextStyles.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (task.status == 'todo')
                    ElevatedButton.icon(
                      onPressed: () => _updateStatus('in_progress'),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Принять в работу'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white),
                    ),
                  if (task.status == 'in_progress') ...[
                    ElevatedButton.icon(
                      onPressed: () => _updateStatus('review'),
                      icon: const Icon(Icons.send),
                      label: const Text('Сдать на проверку'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondaryLavender, foregroundColor: Colors.white),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _updateStatus('done'),
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Завершить'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
                    ),
                  ],
                  if (task.status == 'review') ...[
                    ElevatedButton.icon(
                      onPressed: () => _updateStatus('done'),
                      icon: const Icon(Icons.thumb_up),
                      label: const Text('Утвердить результат'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _updateStatus('in_progress'),
                      icon: const Icon(Icons.replay),
                      label: const Text('Вернуть на доработку'),
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                    ),
                  ],
                  if (task.status == 'done')
                    OutlinedButton.icon(
                      onPressed: () => _updateStatus('in_progress'),
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('Открыть повторно'),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Discussion / Comments
              Text('Обсуждение (${task.comments.length})', style: AppTextStyles.titleMedium),
              const SizedBox(height: 8),

              if (task.comments.isEmpty)
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  borderRadius: 14,
                  child: Center(child: Text('Комментариев пока нет', style: AppTextStyles.caption)),
                )
              else
                ...task.comments.map((c) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: GlassCard(
                        padding: const EdgeInsets.all(12),
                        borderRadius: 14,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(c.authorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryBlue)),
                                Text(Formatters.formatDate(c.createdAt), style: AppTextStyles.caption),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(c.content, style: AppTextStyles.bodyMedium),
                          ],
                        ),
                      ),
                    )),
              const SizedBox(height: 20),
            ],
          ),
        ),

        // Add Comment Bar with Attachment Button
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2)),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file, color: AppColors.textSecondary),
                  tooltip: 'Прикрепить документ',
                  onPressed: _pickAndUploadAttachment,
                ),
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Написать комментарий...',
                      hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 14),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: AppColors.primaryBlue),
                  onPressed: _sendComment,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _metaRow(String label, String value, IconData icon, {bool isOverdue = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: isOverdue ? AppColors.error : AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(label, style: AppTextStyles.caption),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: isOverdue ? AppColors.error : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
