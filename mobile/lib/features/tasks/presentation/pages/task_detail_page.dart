import 'dart:io';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/attachment_opener.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../../data/models/task_model.dart';
import '../../data/repositories/tasks_repository.dart';
import '../bloc/task_detail_cubit.dart';
import '../bloc/tasks_bloc.dart';
import 'add_task_page.dart';

class TaskDetailPage extends StatefulWidget {
  final String taskId;

  const TaskDetailPage({super.key, required this.taskId});

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {
  final _commentController = TextEditingController();
  late final TaskDetailCubit _cubit;

  bool _busy = false; // status change / delete in flight
  bool _sendingComment = false;
  String? _uploadingName;
  double _uploadProgress = 0;
  CancelToken? _uploadCancel;

  @override
  void initState() {
    super.initState();
    _cubit = TaskDetailCubit(repository: getIt<TasksRepository>(), taskId: widget.taskId)..load();
  }

  @override
  void dispose() {
    _uploadCancel?.cancel();
    _commentController.dispose();
    _cubit.close();
    super.dispose();
  }

  void _showMessage(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: error ? AppColors.error : AppColors.success),
    );
  }

  void _refreshList() => context.read<TasksBloc>().add(const RefreshTasksEvent());

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _sendingComment) return;
    setState(() => _sendingComment = true);
    try {
      await _cubit.addComment(text);
      if (!mounted) return;
      _commentController.clear();
    } catch (e) {
      // The typed text stays in the field so it can be sent again.
      _showMessage(apiErrorMessage(e, fallback: 'Не удалось отправить комментарий'), error: true);
    } finally {
      if (mounted) setState(() => _sendingComment = false);
    }
  }

  Future<void> _updateStatus(String status, {int? progress, String? successText}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _cubit.changeStatus(status, progress: progress);
      if (!mounted) return;
      _refreshList();
      _showMessage(successText ?? 'Статус задачи изменен');
    } catch (e) {
      _showMessage(apiErrorMessage(e, fallback: 'Не удалось обновить статус задачи'), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editProgress(TaskModel task) async {
    var value = task.progressPercent.toDouble();
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Прогресс выполнения', style: AppTextStyles.titleMedium),
                    Text('${value.round()}%', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  ],
                ),
                Slider(
                  value: value,
                  min: 0,
                  max: 100,
                  divisions: 20,
                  activeColor: AppColors.primaryBlue,
                  onChanged: (v) => setSheet(() => value = v),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, value.round()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Сохранить'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (picked == null || !mounted || picked == task.progressPercent) return;
    await _updateStatus(task.status, progress: picked, successText: 'Прогресс обновлен');
  }

  Future<void> _pickAndUploadAttachments() async {
    if (_uploadingName != null) return;
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(allowMultiple: true);
    } catch (_) {
      _showMessage('Не удалось выбрать файл', error: true);
      return;
    }
    if (result == null || !mounted) return;

    var uploaded = 0;
    for (final picked in result.files) {
      final path = picked.path;
      if (path == null) continue;
      final size = picked.size > 0 ? picked.size : await File(path).length();
      if (!mounted) return;
      if (size > TasksRepository.maxFileBytes) {
        _showMessage('Файл «${picked.name}» слишком большой (максимум 25 МБ)', error: true);
        continue;
      }
      final cancel = CancelToken();
      setState(() {
        _uploadingName = picked.name;
        _uploadProgress = 0;
        _uploadCancel = cancel;
      });
      try {
        await _cubit.uploadAttachment(
          path,
          fileName: picked.name,
          cancelToken: cancel,
          onProgress: (p) {
            if (mounted) setState(() => _uploadProgress = p);
          },
        );
        uploaded++;
      } catch (e) {
        if (!mounted) return;
        if (e is DioException && e.type == DioExceptionType.cancel) {
          _showMessage('Загрузка отменена', error: true);
        } else {
          _showMessage('Файл «${picked.name}» не загружен: ${apiErrorMessage(e, fallback: 'ошибка загрузки')}', error: true);
        }
        break;
      }
    }

    if (!mounted) return;
    setState(() {
      _uploadingName = null;
      _uploadCancel = null;
    });
    if (uploaded > 0) {
      _showMessage(uploaded == 1 ? 'Файл прикреплен' : 'Прикреплено файлов: $uploaded');
      try {
        await _cubit.reload();
      } catch (e) {
        _showMessage(apiErrorMessage(e, fallback: 'Не удалось обновить задачу'), error: true);
      }
    }
  }

  Future<bool> _confirm(String title, String text, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text(title, style: TextStyle(color: AppColors.textPrimary)),
        content: Text(text, style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action, style: const TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _deleteAttachment(TaskAttachmentModel file) async {
    if (_busy) return;
    if (!await _confirm('Удалить файл?', 'Файл «${file.name}» будет удалён из задачи.', 'Удалить')) return;
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await _cubit.deleteAttachment(file.id);
      _showMessage('Файл удалён');
    } catch (e) {
      _showMessage(apiErrorMessage(e, fallback: 'Не удалось удалить файл'), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editTask(TaskModel task) async {
    final updated = await Navigator.of(context).push<Object?>(
      MaterialPageRoute(builder: (_) => AddTaskPage(task: task)),
    );
    if (updated is TaskModel && mounted) {
      _cubit.setTask(updated);
      _showMessage('Задание сохранено');
    }
  }

  Future<void> _deleteTask(TaskModel task) async {
    if (_busy) return;
    if (!await _confirm('Удалить задание?', 'Задание «${task.title}» будет удалено вместе с файлами и комментариями.', 'Удалить')) return;
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await _cubit.deleteTask();
      if (!mounted) return;
      _refreshList();
      _showMessage('Задание удалено');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      _showMessage(apiErrorMessage(e, fallback: 'Не удалось удалить задание'), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TaskDetailCubit, TaskDetailState>(
      bloc: _cubit,
      builder: (context, state) {
        final task = state.task;
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Карточка задания'),
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              if (task != null)
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: AppColors.textPrimary),
                  color: AppColors.cardBackground,
                  enabled: !_busy,
                  onSelected: (v) => v == 'edit' ? _editTask(task) : _deleteTask(task),
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'edit', child: Text('Редактировать', style: TextStyle(color: AppColors.textPrimary))),
                    const PopupMenuItem(value: 'delete', child: Text('Удалить', style: TextStyle(color: AppColors.error))),
                  ],
                ),
            ],
          ),
          body: Container(
            decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
            child: task != null
                ? _buildContent(task)
                : state.error != null
                    ? _buildError(state.error!)
                    : const LoadingShimmer(),
          ),
        );
      },
    );
  }

  Widget _buildError(String message) {
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
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _cubit.load, child: const Text('Повторить')),
        ],
      ),
    );
  }

  Widget _buildContent(TaskModel task) {
    final uploading = _uploadingName != null;
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              try {
                await _cubit.reload();
              } catch (e) {
                _showMessage(apiErrorMessage(e, fallback: 'Не удалось обновить задачу'), error: true);
              }
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
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
                          InkWell(
                            onTap: _busy || task.status == 'done' ? null : () => _editProgress(task),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('${task.progressPercent}%', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                  if (task.status != 'done') ...[
                                    const SizedBox(width: 4),
                                    const Icon(Icons.edit_outlined, size: 14, color: AppColors.primaryBlue),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: task.progress,
                          minHeight: 8,
                          backgroundColor: AppColors.neutral200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            task.status == 'done' ? AppColors.success : AppColors.primaryBlue,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _metaRow('Исполнитель:', task.assignedToName.isNotEmpty ? task.assignedToName : 'Не назначен', Icons.person_outline),
                      if (task.createdByName.isNotEmpty) _metaRow('Постановщик:', task.createdByName, Icons.badge_outlined),
                      _metaRow('Приоритет:', task.priorityDisplay, Icons.flag_outlined),
                      _metaRow(
                        'Дедлайн:',
                        task.deadline != null
                            ? Formatters.formatDate(task.deadline) + (task.isOverdue ? ' (Просрочено!)' : '')
                            : 'Без срока',
                        Icons.schedule,
                        isOverdue: task.isOverdue,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Attached files
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text('Прикрепленные файлы (${task.attachments.length})', style: AppTextStyles.titleMedium),
                    ),
                    TextButton.icon(
                      onPressed: uploading ? null : _pickAndUploadAttachments,
                      icon: const Icon(Icons.upload_file, size: 18),
                      label: const Text('Прикрепить'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                if (uploading) _buildUploadProgress(),

                if (task.attachments.isEmpty && !uploading)
                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    borderRadius: 14,
                    child: Center(
                      child: Text('Файлы еще не прикреплены', style: AppTextStyles.caption),
                    ),
                  )
                else
                  ...task.attachments.map(_buildAttachmentRow),
                const SizedBox(height: 16),

                Text('Действия по заданию', style: AppTextStyles.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (task.status == 'todo')
                      ElevatedButton.icon(
                        onPressed: _busy ? null : () => _updateStatus('in_progress'),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Принять в работу'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white),
                      ),
                    if (task.status == 'in_progress') ...[
                      ElevatedButton.icon(
                        onPressed: _busy ? null : () => _updateStatus('review'),
                        icon: const Icon(Icons.send),
                        label: const Text('Сдать на проверку'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondaryLavender, foregroundColor: Colors.white),
                      ),
                      ElevatedButton.icon(
                        onPressed: _busy ? null : () => _updateStatus('done'),
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Завершить'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
                      ),
                    ],
                    if (task.status == 'review') ...[
                      ElevatedButton.icon(
                        onPressed: _busy ? null : () => _updateStatus('done'),
                        icon: const Icon(Icons.thumb_up),
                        label: const Text('Утвердить результат'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : () => _updateStatus('in_progress'),
                        icon: const Icon(Icons.replay),
                        label: const Text('Вернуть на доработку'),
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                      ),
                    ],
                    if (task.status == 'done')
                      OutlinedButton.icon(
                        onPressed: _busy ? null : () => _updateStatus('in_progress'),
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
                                children: [
                                  Expanded(
                                    child: Text(
                                      c.authorName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryBlue),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(Formatters.formatDateTime(c.createdAt), style: AppTextStyles.caption),
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
        ),

        // Add Comment Bar with Attachment Button
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2)),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.attach_file, color: AppColors.textSecondary),
                  tooltip: 'Прикрепить документ',
                  onPressed: uploading ? null : _pickAndUploadAttachments,
                ),
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
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
                  icon: _sendingComment
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send, color: AppColors.primaryBlue),
                  onPressed: _sendingComment ? null : _sendComment,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadProgress() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        borderRadius: 12,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Загрузка «$_uploadingName»… ${(_uploadProgress * 100).round()}%',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                  ),
                ),
                GestureDetector(
                  onTap: () => _uploadCancel?.cancel(),
                  child: Icon(Icons.close, size: 20, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _uploadProgress,
                minHeight: 4,
                backgroundColor: AppColors.neutral200,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentRow(TaskAttachmentModel file) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        onTap: () => openServerFile(context, file.url, fileName: file.name),
        padding: const EdgeInsets.only(left: 14, top: 4, bottom: 4),
        borderRadius: 12,
        child: Row(
          children: [
            const Icon(Icons.description, color: AppColors.primaryBlue, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.name,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (file.sizeBytes > 0) Text(formatFileSize(file.sizeBytes), style: AppTextStyles.caption),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
              tooltip: 'Удалить файл',
              onPressed: _busy ? null : () => _deleteAttachment(file),
            ),
          ],
        ),
      ),
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
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: isOverdue ? AppColors.error : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
