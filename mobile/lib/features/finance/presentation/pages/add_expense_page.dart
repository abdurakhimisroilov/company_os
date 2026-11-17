import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/glass_card.dart';
import '../bloc/finance_bloc.dart';
import '../widgets/attachment_picker_card.dart';

class AddExpensePage extends StatefulWidget {
  const AddExpensePage({super.key});

  @override
  State<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends State<AddExpensePage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _employeeController = TextEditingController();

  String _selectedCategory = 'Аренда';
  String _paymentMethod = 'cash';
  DateTime _selectedDate = DateTime.now();
  String? _documentUrl;
  String? _documentName;

  final List<String> _categories = [
    'Аренда',
    'Зарплата',
    'Закупка товара',
    'Транспорт и логистика',
    'Маркетинг и реклама',
    'Офисные расходы',
    'Налоги и сборы',
    'Прочее',
  ];

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _employeeController.dispose();
    super.dispose();
  }

  void _saveExpense() {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text.replaceAll(' ', '')) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите корректную сумму'), backgroundColor: AppColors.error),
      );
      return;
    }

    final data = {
      'amount': amount,
      'type': 'expense',
      'category': _selectedCategory,
      'paymentMethod': _paymentMethod,
      'description': _descriptionController.text.trim(),
      'employeeName': _employeeController.text.trim(),
      'date': _selectedDate.toIso8601String(),
      'hasReceipt': _documentUrl != null,
      'documentUrl': _documentUrl,
      'documentName': _documentName,
    };

    context.read<FinanceBloc>().add(CreateExpenseEvent(data));
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Добавить расход'),
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
          padding: const EdgeInsets.all(16.0),
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
                      Text('Сумма расхода (UZS)', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.error,
                        ),
                        decoration: InputDecoration(
                          hintText: '0 сум',
                          hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 24),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: AppColors.cardBorder),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        validator: (val) => (val == null || val.isEmpty) ? 'Обязательное поле' : null,
                      ),
                      const SizedBox(height: 20),

                      Text('Категория расхода', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedCategory,
                            isExpanded: true,
                            items: _categories.map((cat) {
                              return DropdownMenuItem(value: cat, child: Text(cat));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedCategory = val);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      Text('Ответственный сотрудник', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _employeeController,
                        decoration: InputDecoration(
                          hintText: 'ФИО сотрудника',
                          prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.primaryBlue),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: AppColors.cardBorder),
                          ),
                        ),
                        validator: (val) => (val == null || val.isEmpty) ? 'Укажите сотрудника' : null,
                      ),
                      const SizedBox(height: 20),

                      Text('Описание / Назначение', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'За что произведена оплата...',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: AppColors.cardBorder),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      Text('Прикрепленный документ / чек / накладная', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 8),
                      AttachmentPickerCard(
                        initialDocumentUrl: _documentUrl,
                        initialDocumentName: _documentName,
                        onAttachmentChanged: (att) {
                          setState(() {
                            _documentUrl = att?['url'];
                            _documentName = att?['name'];
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                AppButton(
                  label: 'Сохранить расход',
                  onPressed: _saveExpense,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
