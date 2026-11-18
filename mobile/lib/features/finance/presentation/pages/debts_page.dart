import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../../data/company_currency.dart';
import '../../data/models/transaction_model.dart';
import '../../data/repositories/finance_repository.dart';
import '../widgets/attachment_picker_card.dart';
import '../widgets/finance_form_widgets.dart';

class DebtsPage extends StatefulWidget {
  const DebtsPage({super.key});

  @override
  State<DebtsPage> createState() => _DebtsPageState();
}

class _DebtsPageState extends State<DebtsPage> with SingleTickerProviderStateMixin {
  final _repository = getIt<FinanceRepository>();
  late TabController _tabController;
  List<DebtModel>? _customerDebts;
  List<DebtModel>? _supplierDebts;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
    CompanyCurrency.instance.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool get _hasData => _customerDebts != null && _supplierDebts != null;

  /// Keeps the loaded lists on screen while they are being re-read.
  Future<void> _load() async {
    if (!_hasData && _error != null) setState(() => _error = null);
    try {
      final results = await Future.wait([_repository.getCustomerDebts(), _repository.getSupplierDebts()]);
      if (!mounted) return;
      setState(() {
        _customerDebts = results[0];
        _supplierDebts = results[1];
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      final message = apiErrorMessage(e, fallback: 'Не удалось загрузить задолженности');
      if (_hasData) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: AppColors.error),
        );
      } else {
        setState(() => _error = message);
      }
    }
  }

  Future<void> _showPayDebtModal(DebtModel debt, {required bool isCustomer}) async {
    final paid = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _PayDebtSheet(debt: debt, isCustomer: isCustomer),
    );
    if (paid != true || !mounted) return;
    notifyFinanceChanged(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Оплата задолженности зарегистрирована'), backgroundColor: AppColors.success),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Задолженности'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryBlue,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primaryBlue,
          tabs: const [
            Tab(text: 'Нам должны (Дебиторка)'),
            Tab(text: 'Мы должны (Кредиторка)'),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (!_hasData) {
      if (_error == null) return const LoadingShimmer();
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Повторить'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return TabBarView(
      controller: _tabController,
      children: [
        _buildDebtList(_customerDebts!, isCustomer: true),
        _buildDebtList(_supplierDebts!, isCustomer: false),
      ],
    );
  }

  Widget _buildDebtList(List<DebtModel> debts, {required bool isCustomer}) {
    if (debts.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primaryBlue,
        child: LayoutBuilder(
          builder: (context, constraints) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: constraints.maxHeight,
                child: Center(
                  child: Text(
                    isCustomer ? 'Нет дебиторской задолженности' : 'Нет кредиторской задолженности',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    double total = 0;
    for (final d in debts) {
      total += d.remainingAmount;
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primaryBlue,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(16),
            borderRadius: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Итого задолженность:', style: AppTextStyles.titleMedium),
                Flexible(
                  child: Text(
                    money(total),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isCustomer ? AppColors.success : AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...debts.map((debt) {
            final title = _debtTitle(debt, isCustomer: isCustomer);

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () => _showPayDebtModal(debt, isCustomer: isCustomer),
                borderRadius: BorderRadius.circular(14),
                child: GlassCard(
                  padding: const EdgeInsets.all(16),
                  borderRadius: 14,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isCustomer ? AppColors.iconBgGreen.withOpacity(0.5) : AppColors.iconBgRed,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isCustomer ? Icons.arrow_downward : Icons.arrow_upward,
                          color: isCustomer ? AppColors.success : AppColors.error,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                            ),
                            if (debt.paidAmount > 0) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Уже оплачено: ${money(debt.paidAmount)}',
                                style: AppTextStyles.caption,
                              ),
                            ],
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.payment, size: 12, color: AppColors.primaryBlue),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    isCustomer ? 'Нажмите, чтобы принять оплату' : 'Нажмите, чтобы оплатить',
                                    style: const TextStyle(fontSize: 11, color: AppColors.primaryBlue, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            money(debt.remainingAmount),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isCustomer ? AppColors.success : AppColors.error,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text('остаток долга', style: AppTextStyles.caption.copyWith(fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

String _debtTitle(DebtModel debt, {required bool isCustomer}) {
  final name = isCustomer ? debt.customerName : debt.supplierName;
  if (name != null && name.trim().isNotEmpty) return name;
  return isCustomer ? 'Клиент без названия' : 'Поставщик без названия';
}

/// Registers a debt payment. The sheet stays open with a loading state until
/// the server answers, keeps the entered data on failure and pops `true` on success.
class _PayDebtSheet extends StatefulWidget {
  final DebtModel debt;
  final bool isCustomer;

  const _PayDebtSheet({required this.debt, required this.isCustomer});

  @override
  State<_PayDebtSheet> createState() => _PayDebtSheetState();
}

class _PayDebtSheetState extends State<_PayDebtSheet> {
  late final TextEditingController _amountController;
  final _noteController = TextEditingController();
  String _paymentMethod = 'cash';
  String? _docUrl;
  String? _docName;
  bool _isUploading = false;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final remaining = widget.debt.remainingAmount;
    _amountController = TextEditingController(
      text: remaining > 0 ? (remaining == remaining.roundToDouble() ? remaining.toStringAsFixed(0) : remaining.toStringAsFixed(2)) : '',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final debt = widget.debt;
    final isCustomer = widget.isCustomer;
    final amount = parseAmount(_amountController.text);
    if (amount <= 0) {
      setState(() => _error = 'Введите корректную сумму');
      return;
    }
    // Half a tiyin of tolerance so a rounded prefilled amount is not rejected.
    if (amount > debt.remainingAmount + 0.005) {
      setState(() => _error = 'Сумма больше остатка задолженности (${money(debt.remainingAmount)})');
      return;
    }
    if (_isUploading) {
      setState(() => _error = 'Дождитесь окончания загрузки документа');
      return;
    }
    final debtId = isCustomer ? (debt.customerId ?? debt.id) : (debt.supplierId ?? debt.id);
    final note = _noteController.text.trim();

    FocusScope.of(context).unfocus();
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await getIt<FinanceRepository>().payDebt({
        'debtId': debtId,
        'type': isCustomer ? 'receivable' : 'payable',
        'amount': amount,
        'paymentMethod': _paymentMethod,
        if (note.isNotEmpty) 'description': note,
        if (_docUrl != null) 'documentUrl': _docUrl,
        if (_docUrl != null && _docName != null) 'documentName': _docName,
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = apiErrorMessage(e, fallback: 'Не удалось зарегистрировать оплату');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final debt = widget.debt;
    final isCustomer = widget.isCustomer;
    final title = _debtTitle(debt, isCustomer: isCustomer);

    return PopScope(
      canPop: !_isSaving,
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          top: 20,
          left: 20,
          right: 20,
        ),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.neutral300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isCustomer ? 'Прием оплаты задолженности' : 'Оплата задолженности поставщику',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(fontSize: 14, color: isCustomer ? AppColors.primaryBlue : AppColors.error, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 14),

              // Инфо о текущем долге
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Остаток задолженности:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    Text(
                      money(debt.remainingAmount),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isCustomer ? AppColors.success : AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Сумма
              Text('Сумма оплаты${currencySuffix()}', style: AppTextStyles.labelMedium),
              const SizedBox(height: 6),
              TextFormField(
                controller: _amountController,
                enabled: !_isSaving,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.background.withOpacity(0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.cardBorder),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 14),

              // Способ оплаты
              Text('Способ оплаты', style: AppTextStyles.labelMedium),
              const SizedBox(height: 8),
              Row(
                children: const [
                  {'id': 'cash', 'label': 'Наличные'},
                  {'id': 'bank', 'label': 'Расчетный счет'},
                  {'id': 'card', 'label': 'Карта'},
                ].map((m) {
                  final sel = _paymentMethod == m['id'];
                  return Expanded(
                    child: GestureDetector(
                      onTap: _isSaving ? null : () => setState(() => _paymentMethod = m['id']!),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: sel ? AppColors.primaryBlue : AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: sel ? AppColors.primaryBlue : AppColors.cardBorder),
                        ),
                        child: Center(
                          child: Text(
                            m['label']!,
                            style: TextStyle(
                              color: sel ? Colors.white : AppColors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // Документ
              Text('Документ / Чек / Платежное поручение / Акт', style: AppTextStyles.labelMedium),
              const SizedBox(height: 6),
              AbsorbPointer(
                absorbing: _isSaving,
                child: AttachmentPickerCard(
                  onAttachmentChanged: (att) {
                    if (!mounted) return;
                    setState(() {
                      _docUrl = att?['url'];
                      _docName = att?['name'];
                    });
                  },
                  onUploadingChanged: (v) {
                    if (mounted) setState(() => _isUploading = v);
                  },
                ),
              ),
              const SizedBox(height: 14),

              // Примечание
              Text('Примечание к оплате', style: AppTextStyles.labelMedium),
              const SizedBox(height: 6),
              TextFormField(
                controller: _noteController,
                enabled: !_isSaving,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Номер платёжки, договора или комментарий...',
                  filled: true,
                  fillColor: AppColors.background.withOpacity(0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.cardBorder),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
              ],
              const SizedBox(height: 20),

              // Кнопка сохранения
              AppButton(
                label: isCustomer ? 'Принять оплату' : 'Подтвердить оплату',
                isLoading: _isSaving,
                onPressed: _submit,
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
