import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/glass_card.dart';
import '../bloc/tasks_bloc.dart';

class AddTaskPage extends StatefulWidget {
  const AddTaskPage({super.key});

  @override
  State<AddTaskPage> createState() => _AddTaskPageState();
}

class _AddTaskPageState extends State<AddTaskPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _assigneeController = TextEditingController();

  String _priority = 'medium'; // 'high', 'medium', 'low'
  DateTime _deadline = DateTime.now().add(const Duration(days: 3));
  String? _attachedFile;

  final List<Map<String, String>> _priorities = [
    {'id': 'low', 'label': 'Низкий'},
    {'id': 'medium', 'label': 'Средний'},
    {'id': 'high', 'label': 'Высокий'},
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _assigneeController.dispose();
    super.dispose();
  }

  void _saveTask() {
    if (!_formKey.currentState!.validate()) return;

    final data = {
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'assignedToName': _assigneeController.text.trim(),
      'priority': _priority,
      'deadline': _deadline.toIso8601String(),
      'status': 'todo',
      'progress': 0.0,
      'attachments': _attachedFile != null ? [_attachedFile!] : [],
    };

    context.read<TasksBloc>().add(CreateTaskEvent(data));
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Новое задание'),
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
                      Text('Название задания *', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _titleController,
                        decoration: _inputDeco('Подготовить отчёт по продажам'),
                        validator: (v) => (v == null || v.isEmpty) ? 'Введите название задания' : null,
                      ),
                      const SizedBox(height: 16),

                      Text('Исполнитель *', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _assigneeController,
                        decoration: _inputDeco('ФИО сотрудника или отдел'),
                        validator: (v) => (v == null || v.isEmpty) ? 'Укажите исполнителя' : null,
                      ),
                      const SizedBox(height: 16),

                      Text('Приоритет', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 8),
                      Row(
                        children: _priorities.map((p) {
                          final isSelected = _priority == p['id'];
                          Color color = AppColors.primaryBlue;
                          if (p['id'] == 'high') color = AppColors.error;
                          if (p['id'] == 'medium') color = AppColors.warning;
                          if (p['id'] == 'low') color = AppColors.success;

                          return Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _priority = p['id']!),
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected ? color.withOpacity(0.15) : Colors.white,
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
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _deadline,
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) setState(() => _deadline = picked);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(Formatters.formatDate(_deadline)),
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
                        maxLines: 4,
                        decoration: _inputDeco('Подробные требования и ожидаемый результат...'),
                      ),
                      const SizedBox(height: 16),

                      // Attach file button
                      InkWell(
                        onTap: () {
                          setState(() {
                            _attachedFile = 'ТЗ_к_задаче_${DateTime.now().millisecondsSinceEpoch}.pdf';
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: AppColors.iconBgBlue,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.attach_file, color: AppColors.primaryBlue, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                _attachedFile ?? 'Прикрепить файл к задаче',
                                style: const TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                AppButton(
                  label: 'Создать задание',
                  onPressed: _saveTask,
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
