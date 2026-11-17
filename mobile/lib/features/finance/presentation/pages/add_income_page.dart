import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/glass_card.dart';
import '../bloc/finance_bloc.dart';
import '../widgets/attachment_picker_card.dart';

class AddIncomePage extends StatefulWidget {
  const AddIncomePage({super.key});

  @override
  State<AddIncomePage> createState() => _AddIncomePageState();
}

class _AddIncomePageState extends State<AddIncomePage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _customerController = TextEditingController();

  String _paymentMethod = 'cash'; // 'cash', 'bank', 'card'
  DateTime _selectedDate = DateTime.now();
  String? _documentUrl;
  String? _documentName;
  bool _isLoading = false;

  final List<Map<String, String>> _methods = [
    {'id': 'cash', 'label': 'Наличные', 'icon': 'payments'},
    {'id': 'bank', 'label': 'Банк', 'icon': 'account_balance'},
    {'id': 'card', 'label': 'Карта', 'icon': 'credit_card'},
  ];

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _customerController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryBlue,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _saveIncome() {
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
      'type': 'income',
      'paymentMethod': _paymentMethod,
      'description': _descriptionController.text.trim(),
      'customerName': _customerController.text.trim(),
      'date': _selectedDate.toIso8601String(),
      'category': 'Поступление от клиента',
      'hasAttachment': _documentUrl != null,
      'documentUrl': _documentUrl,
      'documentName': _documentName,
    };

    context.read<FinanceBloc>().add(CreateIncomeEvent(data));
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Добавить поступление'),
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
                      Text('Сумма поступления (UZS)', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
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

                      Text('Способ оплаты', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 10),
                      Row(
                        children: _methods.map((m) {
                          final isSelected = _paymentMethod == m['id'];
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _paymentMethod = m['id']!),
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.primaryBlue : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? AppColors.primaryBlue : AppColors.cardBorder,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    m['label']!,
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),

                      Text('Клиент / Источник', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _customerController,
                        decoration: InputDecoration(
                          hintText: 'Выберите или введите клиента',
                          prefixIcon: const Icon(Icons.person_outline, color: AppColors.primaryBlue),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: AppColors.cardBorder),
                          ),
                        ),
                        validator: (val) => (val == null || val.isEmpty) ? 'Укажите клиента' : null,
                      ),
                      const SizedBox(height: 20),

                      Text('Дата поступления', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _selectDate,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                Formatters.formatDate(_selectedDate),
                                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                              ),
                              const Icon(Icons.calendar_today, color: AppColors.primaryBlue, size: 20),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      Text('Примечание / Описание', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Комментарий к платежу...',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: AppColors.cardBorder),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      Text('Прикрепленный документ / отчет', style: AppTextStyles.labelMedium),
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
                  label: 'Сохранить поступление',
                  onPressed: _saveIncome,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
