import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../data/company_currency.dart';
import '../../data/models/transaction_model.dart';
import '../../data/repositories/finance_repository.dart';
import '../widgets/attachment_picker_card.dart';
import '../widgets/finance_form_widgets.dart';
import '../widgets/party_picker_field.dart';

class AddExpensePage extends StatefulWidget {
  const AddExpensePage({super.key});

  @override
  State<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends State<AddExpensePage> {
  final _repository = getIt<FinanceRepository>();
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _recipientController = TextEditingController();

  List<String>? _categories;
  String? _categoriesError;
  String? _selectedCategory;
  String _paymentMethod = 'cash';
  DateTime _selectedDate = DateTime.now();
  PartyRef? _supplier;
  List<AccountModel>? _accounts;
  String? _accountsError;
  String? _accountId;
  String? _documentUrl;
  String? _documentName;
  bool _isLoading = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadAccounts();
    CompanyCurrency.instance.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _recipientController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _categories = null;
      _categoriesError = null;
    });
    try {
      final categories = await _repository.getExpenseCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        if (!categories.contains(_selectedCategory)) {
          _selectedCategory = categories.isNotEmpty ? categories.first : null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _categoriesError = apiErrorMessage(e, fallback: 'Не удалось загрузить категории'));
    }
  }

  Future<void> _loadAccounts() async {
    setState(() {
      _accounts = null;
      _accountsError = null;
    });
    try {
      final accounts = await _repository.getAccounts();
      if (!mounted) return;
      setState(() => _accounts = accounts);
    } catch (e) {
      if (!mounted) return;
      setState(() => _accountsError = apiErrorMessage(e, fallback: 'Не удалось загрузить счета'));
    }
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month, now.day),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: AppColors.isDark
                ? Theme.of(context).colorScheme
                : const ColorScheme.light(
                    primary: AppColors.primaryBlue,
                  ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _saveExpense() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);

    final amount = parseAmount(_amountController.text);
    if (amount <= 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Введите корректную сумму'), backgroundColor: AppColors.error),
      );
      return;
    }

    if (_selectedCategory == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Выберите категорию расхода'), backgroundColor: AppColors.error),
      );
      return;
    }

    if (_isUploading) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Дождитесь окончания загрузки документа')),
      );
      return;
    }

    final recipient = _recipientController.text.trim();
    final data = <String, dynamic>{
      'amount': amount,
      'category': _selectedCategory,
      'paymentMethod': _paymentMethod,
      'description': _descriptionController.text.trim(),
      'date': FinanceRepository.dayParam(_selectedDate),
      if (_supplier != null) 'supplierId': _supplier!.id,
      if (_supplier != null) 'supplierName': _supplier!.name,
      if (_supplier == null && recipient.isNotEmpty) 'employeeName': recipient,
      if (_accountId != null) 'accountId': _accountId,
      if (_documentUrl != null) 'documentUrl': _documentUrl,
      if (_documentUrl != null && _documentName != null) 'documentName': _documentName,
    };

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    try {
      await _repository.createExpense(data);
      if (!mounted) return;
      notifyFinanceChanged(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('Расход добавлен'), backgroundColor: AppColors.success),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(apiErrorMessage(e, fallback: 'Не удалось сохранить расход')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Widget _buildCategoryField() {
    final decoration = BoxDecoration(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.cardBorder),
    );
    if (_categoriesError != null) {
      return Container(
        padding: const EdgeInsets.only(left: 16, right: 4),
        decoration: decoration,
        child: Row(
          children: [
            Expanded(child: Text(_categoriesError!, style: AppTextStyles.caption.copyWith(color: AppColors.error))),
            TextButton(onPressed: _loadCategories, child: const Text('Повторить')),
          ],
        ),
      );
    }
    final categories = _categories;
    if (categories == null) {
      return Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: decoration,
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBlue),
            ),
            const SizedBox(width: 12),
            Text('Загрузка категорий…', style: AppTextStyles.caption),
          ],
        ),
      );
    }
    if (categories.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: decoration,
        child: Text('На сервере нет категорий расходов', style: AppTextStyles.caption),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: decoration,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCategory,
          isExpanded: true,
          dropdownColor: AppColors.cardBackground,
          style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
          items: categories.map((cat) {
            return DropdownMenuItem(value: cat, child: Text(cat));
          }).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _selectedCategory = val);
          },
        ),
      ),
    );
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
          icon: Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
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
                      Text('Сумма расхода${currencySuffix()}', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.error,
                        ),
                        decoration: InputDecoration(
                          hintText: '0',
                          hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 24),
                          filled: true,
                          fillColor: AppColors.cardBackground,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: AppColors.cardBorder),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Обязательное поле';
                          return parseAmount(val) > 0 ? null : 'Введите сумму больше нуля';
                        },
                      ),
                      const SizedBox(height: 20),

                      Text('Категория расхода', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 8),
                      _buildCategoryField(),
                      const SizedBox(height: 20),

                      Text('Способ оплаты', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 10),
                      PaymentMethodSelector(
                        value: _paymentMethod,
                        onChanged: (v) => setState(() => _paymentMethod = v),
                      ),
                      const SizedBox(height: 20),

                      Text('Счёт списания', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 8),
                      AccountDropdown(
                        accounts: _accounts,
                        error: _accountsError,
                        onRetry: _loadAccounts,
                        value: _accountId,
                        autoLabel: 'Автоматически, по способу оплаты',
                        onChanged: (id) => setState(() => _accountId = id),
                      ),
                      const SizedBox(height: 20),

                      Text('Получатель платежа', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 8),
                      PartyPickerField(
                        controller: _recipientController,
                        selected: _supplier,
                        onChanged: (party) => setState(() => _supplier = party),
                        loader: _repository.getSuppliers,
                        icon: Icons.badge_outlined,
                        hint: 'Поставщик, сотрудник или организация',
                        sheetTitle: 'Выбрать поставщика',
                        emptyText: 'В базе пока нет поставщиков.\nВведите получателя вручную.',
                        linkedHelper: 'Поставщик из базы: оплата уменьшит наш долг перед ним',
                        freeHelper: 'Необязательно. Выберите поставщика из базы или введите получателя',
                      ),
                      const SizedBox(height: 20),

                      Text('Дата расхода', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _selectDate,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.cardBackground,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                Formatters.formatDate(_selectedDate),
                                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15, color: AppColors.textPrimary),
                              ),
                              const Icon(Icons.calendar_today, color: AppColors.primaryBlue, size: 20),
                            ],
                          ),
                        ),
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
                          fillColor: AppColors.cardBackground,
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
                        onUploadingChanged: (v) => setState(() => _isUploading = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                AppButton(
                  label: 'Сохранить расход',
                  onPressed: _saveExpense,
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
