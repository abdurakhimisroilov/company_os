import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/glass_card.dart';
import '../bloc/deals_bloc.dart';
import '../../data/models/deal_model.dart';
import '../../data/repositories/deals_repository.dart';
import '../../../customers/presentation/bloc/customers_bloc.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_error.dart';
import '../widgets/deal_customer_picker.dart';

/// Create form; with [deal] it edits that deal instead.
class AddDealPage extends StatefulWidget {
  const AddDealPage({super.key, this.deal});

  final DealModel? deal;

  @override
  State<AddDealPage> createState() => _AddDealPageState();
}

class _AddDealPageState extends State<AddDealPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  DealCustomerChoice? _customer;
  bool _customerMissing = false;
  DateTime? _expectedCloseDate;
  String _selectedStatus = 'lead';
  bool _saving = false;

  bool get _isEdit => widget.deal != null;

  @override
  void initState() {
    super.initState();
    final deal = widget.deal;
    if (deal != null) {
      _titleController.text = deal.title;
      _amountController.text = deal.amount == deal.amount.roundToDouble()
          ? deal.amount.toStringAsFixed(0)
          : deal.amount.toString();
      _descriptionController.text = deal.description ?? '';
      _expectedCloseDate = deal.expectedCloseDate;
      _selectedStatus = deal.status;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  double? _parseAmount(String? raw) {
    final clean = (raw ?? '').replaceAll(RegExp(r'\s'), '').replaceAll(',', '.');
    if (clean.isEmpty) return null;
    return double.tryParse(clean);
  }

  String? _dateForServer(DateTime? d) {
    if (d == null) return null;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  Future<void> _pickCustomer() async {
    final choice = await showDealCustomerPicker(context);
    if (choice == null || !mounted) return;
    setState(() {
      _customer = choice;
      _customerMissing = false;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initial = _expectedCloseDate ?? today;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: initial.isBefore(today) ? initial : today,
      lastDate: DateTime(today.year + 10),
    );
    if (picked != null && mounted) setState(() => _expectedCloseDate = picked);
  }

  Future<void> _saveDeal() async {
    if (_saving) return;
    final formOk = _formKey.currentState!.validate();
    final customerOk = _isEdit || _customer != null;
    if (!customerOk) setState(() => _customerMissing = true);
    if (!formOk || !customerOk) return;

    final data = <String, dynamic>{
      'title': _titleController.text.trim(),
      'amount': _parseAmount(_amountController.text) ?? 0,
      'status': _selectedStatus,
      'expectedCloseDate': _dateForServer(_expectedCloseDate),
      'description': _descriptionController.text.trim(),
    };
    if (!_isEdit) {
      final customer = _customer!;
      if (customer.isNew) {
        data['customerName'] = customer.name;
      } else {
        data['customerId'] = customer.id;
      }
    }

    setState(() => _saving = true);
    try {
      final repo = getIt<DealsRepository>();
      final saved = _isEdit ? await repo.updateDeal(widget.deal!.id, data) : await repo.createDeal(data);
      if (!mounted) return;
      context.read<DealsBloc>().add(const LoadDealsEvent());
      if (!_isEdit && _customer!.isNew) {
        // A new customer was created together with the deal.
        context.read<CustomersBloc>().add(const LoadCustomersEvent());
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEdit ? 'Сделка обновлена' : 'Сделка успешно создана'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(apiErrorMessage(e, fallback: 'Не удалось сохранить сделку')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEdit ? 'Изменить сделку' : 'Новая сделка'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
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
                      Text('Название сделки *', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _titleController,
                        decoration: _inputDeco('Поставка партии серверов'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Укажите название сделки' : null,
                      ),
                      const SizedBox(height: 16),

                      Text(_isEdit ? 'Клиент / Компания' : 'Клиент / Компания *', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 8),
                      if (_isEdit)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.shimmerBase,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: Text(
                            widget.deal!.customerName.isNotEmpty ? widget.deal!.customerName : 'Не указан',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                      else ...[
                        InkWell(
                          onTap: _saving ? null : _pickCustomer,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.cardBackground,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _customerMissing ? AppColors.error : AppColors.cardBorder),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _customer == null
                                        ? 'Выберите клиента'
                                        : (_customer!.isNew ? '${_customer!.name} (новый)' : _customer!.name),
                                    style: TextStyle(
                                      color: _customer == null ? AppColors.textTertiary : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                const Icon(Icons.person_search_outlined, size: 20, color: AppColors.primaryBlue),
                              ],
                            ),
                          ),
                        ),
                        if (_customerMissing)
                          Padding(
                            padding: const EdgeInsets.only(top: 6, left: 14),
                            child: Text('Укажите клиента', style: AppTextStyles.caption.copyWith(color: AppColors.error)),
                          ),
                      ],
                      const SizedBox(height: 16),

                      Text('Ожидаемая сумма сделки (UZS) *', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                        decoration: _inputDeco('0 сум'),
                        validator: (v) {
                          final amount = _parseAmount(v);
                          if (amount == null) return 'Укажите сумму';
                          if (amount < 0) return 'Сумма не может быть отрицательной';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      Text(_isEdit ? 'Статус' : 'Начальный статус', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
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
                            onChanged: _saving ? null : (v) => setState(() => _selectedStatus = v ?? _selectedStatus),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text('Планируемая дата закрытия', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _saving ? null : _pickDate,
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
                                  _expectedCloseDate == null ? 'Не указана' : Formatters.formatDate(_expectedCloseDate),
                                  style: TextStyle(
                                    color: _expectedCloseDate == null ? AppColors.textTertiary : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              if (_expectedCloseDate != null)
                                GestureDetector(
                                  onTap: _saving ? null : () => setState(() => _expectedCloseDate = null),
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
                  label: _isEdit ? 'Сохранить изменения' : 'Создать сделку',
                  isLoading: _saving,
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
      fillColor: AppColors.cardBackground,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.cardBorder)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}
