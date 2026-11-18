import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../data/models/task_model.dart';
import '../../data/repositories/tasks_repository.dart';
import '../bloc/tasks_bloc.dart';

class _PickedFile {
  final String path;
  final String name;
  final int size;
  bool uploaded = false;

  _PickedFile({required this.path, required this.name, required this.size});
}

/// Creates a task, or edits [task] when it is given (pops with the updated task).
class AddTaskPage extends StatefulWidget {
  final TaskModel? task;

  const AddTaskPage({super.key, this.task});

  @override
  State<AddTaskPage> createState() => _AddTaskPageState();
}

class _AddTaskPageState extends State<AddTaskPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _repository = getIt<TasksRepository>();

  String _priority = 'medium';
  DateTime? _deadline;

  List<TaskAssignee>? _employees;
  bool _employeesLoading = true;
  String? _employeesError;
  String? _assigneeId;
  String _assigneeName = '';
  bool _assigneeMissing = false;

  final List<_PickedFile> _files = [];
  bool _saving = false;
  // Set once the task exists on the server, so a failed file upload can be
  // retried without creating the task twice.
  String? _createdTaskId;
  int _uploadingIndex = -1;
  double _uploadProgress = 0;

  bool get _isEdit => widget.task != null;

  List<Map<String, String>> get _priorities => [
        {'id': 'low', 'label': 'Низкий'},
        {'id': 'medium', 'label': 'Средний'},
        {'id': 'high', 'label': 'Высокий'},
        if (_priority == 'urgent') {'id': 'urgent', 'label': 'Срочный'},
      ];

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    if (task != null) {
      _titleController.text = task.title;
      _descriptionController.text = task.description;
      _priority = task.priority;
      _deadline = task.deadline;
      _assigneeId = task.assignedToId.isNotEmpty ? task.assignedToId : null;
      _assigneeName = task.assignedToName;
    }
    _loadEmployees();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    setState(() {
      _employeesLoading = true;
      _employeesError = null;
    });
    try {
      final employees = await _repository.getAssignees();
      if (!mounted) return;
      setState(() {
        _employees = employees;
        _employeesLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _employeesLoading = false;
        _employeesError = apiErrorMessage(e, fallback: 'Не удалось загрузить список сотрудников');
      });
    }
  }

  void _showMessage(String text, {bool error = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: error ? AppColors.error : AppColors.success),
    );
  }

  Future<void> _pickAssignee() async {
    if (_saving) return;
    if (_employeesLoading) return;
    if (_employees == null) {
      await _loadEmployees();
      if (!mounted || _employees == null) return;
    }
    final employees = _employees!;
    final picked = await showModalBottomSheet<TaskAssignee>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
        padding: const EdgeInsets.only(top: 20),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text('Исполнитель', style: AppTextStyles.titleMedium),
              ),
              const SizedBox(height: 8),
              if (employees.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'В организации пока нет сотрудников',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: employees.length,
                    itemBuilder: (_, i) {
                      final e = employees[i];
                      final selected = e.id == _assigneeId;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.iconBgBlue,
                          child: Text(
                            e.fullName.isNotEmpty ? e.fullName.characters.first.toUpperCase() : '?',
                            style: const TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(e.fullName, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                        subtitle: e.position.isNotEmpty ? Text(e.position, style: AppTextStyles.caption) : null,
                        trailing: selected ? const Icon(Icons.check_circle, color: AppColors.primaryBlue) : null,
                        onTap: () => Navigator.pop(ctx, e),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _assigneeId = picked.id;
        _assigneeName = picked.fullName;
        _assigneeMissing = false;
      });
    }
  }

  Future<void> _pickFiles() async {
    if (_saving) return;
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: true);
      if (result == null || !mounted) return;
      final tooBig = <String>[];
      final added = <_PickedFile>[];
      for (final f in result.files) {
        final path = f.path;
        if (path == null) continue;
        final size = f.size > 0 ? f.size : await File(path).length();
        if (size > TasksRepository.maxFileBytes) {
          tooBig.add(f.name);
        } else if (!_files.any((x) => x.path == path)) {
          added.add(_PickedFile(path: path, name: f.name, size: size));
        }
      }
      if (!mounted) return;
      setState(() => _files.addAll(added));
      if (tooBig.isNotEmpty) {
        _showMessage('Файл слишком большой (максимум 25 МБ): ${tooBig.join(', ')}');
      }
    } catch (e) {
      if (mounted) _showMessage('Не удалось выбрать файл');
    }
  }

  Future<void> _pickDeadline() async {
    if (_saving) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initial = _deadline != null && _deadline!.isAfter(today) ? _deadline! : today;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today,
      lastDate: DateTime(now.year + 5, 12, 31),
    );
    // The task is due by the end of the chosen day.
    if (picked != null && mounted) {
      setState(() => _deadline = DateTime(picked.year, picked.month, picked.day, 23, 59, 59));
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final valid = _formKey.currentState!.validate();
    setState(() => _assigneeMissing = _assigneeId == null);
    if (!valid || _assigneeId == null) return;
    FocusScope.of(context).unfocus();

    final tasksBloc = context.read<TasksBloc>();
    final data = <String, dynamic>{
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'assignedToId': _assigneeId,
      'priority': _priority,
    };

    setState(() => _saving = true);
    try {
      if (_isEdit) {
        data['deadline'] = _deadline?.toUtc().toIso8601String();
        final updated = await _repository.updateTask(widget.task!.id, data);
        tasksBloc.add(const RefreshTasksEvent());
        if (!mounted) return;
        Navigator.of(context).pop(updated);
        return;
      }

      if (_createdTaskId == null) {
        if (_deadline != null) data['deadline'] = _deadline!.toUtc().toIso8601String();
        final created = await _repository.createTask(data);
        _createdTaskId = created.id;
        tasksBloc.add(const RefreshTasksEvent());
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage(apiErrorMessage(e, fallback: _isEdit ? 'Не удалось сохранить задачу' : 'Не удалось создать задачу'));
      return;
    }

    // The task exists; attach the chosen files one by one.
    for (var i = 0; i < _files.length; i++) {
      final file = _files[i];
      if (file.uploaded) continue;
      if (mounted) {
        setState(() {
          _uploadingIndex = i;
          _uploadProgress = 0;
        });
      }
      try {
        await _repository.uploadTaskAttachment(
          _createdTaskId!,
          file.path,
          fileName: file.name,
          onProgress: (p) {
            if (mounted) setState(() => _uploadProgress = p);
          },
        );
        file.uploaded = true;
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _saving = false;
          _uploadingIndex = -1;
        });
        _showMessage('Задание создано, но файл «${file.name}» не загружен: ${apiErrorMessage(e, fallback: 'ошибка загрузки')}');
        return;
      }
    }

    if (!mounted) return;
    _showMessage('Задание создано', error: false);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final created = _createdTaskId != null;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEdit ? 'Редактирование задания' : 'Новое задание'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
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
                      Text('Название задания *', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _titleController,
                        enabled: !_saving && !created,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: _inputDeco('Подготовить отчёт по продажам'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Введите название задания' : null,
                      ),
                      const SizedBox(height: 16),

                      Text('Исполнитель *', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 8),
                      _buildAssigneeField(created),
                      const SizedBox(height: 16),

                      Text('Приоритет', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 8),
                      Row(
                        children: _priorities.map((p) {
                          final isSelected = _priority == p['id'];
                          Color color = AppColors.primaryBlue;
                          if (p['id'] == 'high' || p['id'] == 'urgent') color = AppColors.error;
                          if (p['id'] == 'medium') color = AppColors.warning;
                          if (p['id'] == 'low') color = AppColors.success;

                          return Expanded(
                            child: GestureDetector(
                              onTap: _saving || created ? null : () => setState(() => _priority = p['id']!),
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected ? color.withValues(alpha: 0.15) : AppColors.cardBackground,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: isSelected ? color : AppColors.cardBorder, width: isSelected ? 2 : 1),
                                ),
                                child: Center(
                                  child: Text(
                                    p['label']!,
                                    style: TextStyle(
                                      color: isSelected ? color : AppColors.textPrimary,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      Text('Срок сдачи (Дедлайн)', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: created ? null : _pickDeadline,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.cardBackground,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _deadline != null ? Formatters.formatDate(_deadline) : 'Без срока',
                                  style: TextStyle(color: _deadline != null ? AppColors.textPrimary : AppColors.textTertiary),
                                ),
                              ),
                              if (_deadline != null && !_saving && !created)
                                GestureDetector(
                                  onTap: () => setState(() => _deadline = null),
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 10),
                                    child: Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                                  ),
                                ),
                              const Icon(Icons.calendar_today, size: 18, color: AppColors.primaryBlue),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text('Описание задания', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descriptionController,
                        enabled: !_saving && !created,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: _inputDeco('Подробные требования и ожидаемый результат...'),
                      ),

                      // Files are attached to an existing task from its card.
                      if (!_isEdit) ...[
                        const SizedBox(height: 16),
                        ..._buildFiles(),
                        InkWell(
                          onTap: _saving ? null : _pickFiles,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: AppColors.iconBgBlue,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.3)),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.attach_file, color: AppColors.primaryBlue, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Прикрепить файл к задаче',
                                  style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                AppButton(
                  label: _isEdit
                      ? 'Сохранить'
                      : created
                          ? 'Повторить загрузку файлов'
                          : 'Создать задание',
                  isLoading: _saving,
                  onPressed: _save,
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAssigneeField(bool created) {
    final hasError = _assigneeMissing || _employeesError != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: created ? null : _pickAssignee,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: hasError ? AppColors.error : AppColors.cardBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _assigneeName.isNotEmpty ? _assigneeName : 'Выберите сотрудника',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _assigneeName.isNotEmpty ? AppColors.textPrimary : AppColors.textTertiary),
                  ),
                ),
                if (_employeesLoading)
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                else
                  const Icon(Icons.person_search_outlined, size: 20, color: AppColors.primaryBlue),
              ],
            ),
          ),
        ),
        if (_employeesError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text('${_employeesError!}. Нажмите, чтобы повторить', style: const TextStyle(color: AppColors.error, fontSize: 12)),
          )
        else if (_assigneeMissing)
          const Padding(
            padding: EdgeInsets.only(top: 6, left: 4),
            child: Text('Укажите исполнителя', style: TextStyle(color: AppColors.error, fontSize: 12)),
          ),
      ],
    );
  }

  List<Widget> _buildFiles() {
    return [
      for (var i = 0; i < _files.length; i++)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.description, color: AppColors.primaryBlue, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _files[i].name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                        ),
                        Text(
                          _uploadingIndex == i && !_files[i].uploaded
                              ? 'Загрузка… ${(_uploadProgress * 100).round()}%'
                              : formatFileSize(_files[i].size),
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                  if (_files[i].uploaded)
                    const Icon(Icons.check_circle, color: AppColors.success, size: 20)
                  else if (!_saving)
                    GestureDetector(
                      onTap: () => setState(() => _files.removeAt(i)),
                      child: Icon(Icons.close, size: 20, color: AppColors.textSecondary),
                    ),
                ],
              ),
              if (_uploadingIndex == i && !_files[i].uploaded) ...[
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
            ],
          ),
        ),
    ];
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
