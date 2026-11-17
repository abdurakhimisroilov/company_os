import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/glass_card.dart';
import '../bloc/deals_bloc.dart';
import '../../data/models/deal_model.dart';

class AddDealPage extends StatefulWidget {
  const AddDealPage({super.key});

  @override
  State<AddDealPage> createState() => _AddDealPageState();
}

class _AddDealPageState extends State<AddDealPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _customerController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _employeeController = TextEditingController();

  DateTime _expectedCloseDate = DateTime.now().add(const Duration(days: 14));
  String _selectedStatus = 'lead';

  @override
  void dispose() {
    _titleController.dispose();
    _customerController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _employeeController.dispose();
    super.dispose();
  }

  void _saveDeal() {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text.replaceAll(' ', '')) ?? 0.0;

    final data = {
      'title': _titleController.text.trim(),
      'customerName': _customerController.text.trim(),
      'amount': amount,
      'status': _selectedStatus,
      'expectedCloseDate': _expectedCloseDate.toIso8601String(),
      'description': _descriptionController.text.trim(),
      'assignedEmployeeName': _employeeController.text.trim(),
    };

    context.read<DealsBloc>().add(CreateDealEvent(data));
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Новая сделка'),
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
                      Text('Название сделки *', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _titleController,
                        decoration: _inputDeco('Поставка партии серверов'),
                        validator: (v) => (v == null || v.isEmpty) ? 'Укажите название сделки' : null,
                      ),
                      const SizedBox(height: 16),

                      Text('Клиент / Компания *', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _customerController,
                        decoration: _inputDeco('ООО "ТехноПарк"'),
                        validator: (v) => (v == null || v.isEmpty) ? 'Укажите клиента' : null,
                      ),
                      const SizedBox(height: 16),

                      Text('Ожидаемая сумма сделки (UZS) *', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                        decoration: _inputDeco('0 сум'),
                        validator: (v) => (v == null || v.isEmpty) ? 'Укажите сумму' : null,
                      ),
                      const SizedBox(height: 16),

                      Text('Начальный статус', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedStatus,
                            isExpanded: true,
                            items: DealModel.statusKeys.map((s) {
                              return DropdownMenuItem(value: s, child: Text(DealModel.statusNames[s] ?? s));
                            }).toList(),
                            onChanged: (v) => setState(() => _selectedStatus = v!),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text('Планируемая дата закрытия', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _expectedCloseDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) setState(() => _expectedCloseDate = picked);
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
                              Text(Formatters.formatDate(_expectedCloseDate)),
                              const Icon(Icons.calendar_today, size: 18, color: AppColors.primaryBlue),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text('Ответственный сотрудник', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _employeeController,
                        decoration: _inputDeco('ФИО ответственного'),
                      ),
                      const SizedBox(height: 16),

                      Text('Описание и примечания', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: _inputDeco('Ключевые договоренности, условия...'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                AppButton(
                  label: 'Создать сделку',
                  onPressed: _saveDeal,
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
