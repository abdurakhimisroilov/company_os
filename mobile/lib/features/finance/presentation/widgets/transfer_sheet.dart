import 'package:flutter/material.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../data/company_currency.dart';
import '../../data/models/transaction_model.dart';
import '../../data/repositories/finance_repository.dart';
import 'finance_form_widgets.dart';

/// Moves money between two of the organization's accounts. Returns `true`
/// through [Navigator.pop] once the server has recorded the transfer.
class TransferSheet extends StatefulWidget {
  const TransferSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => const TransferSheet(),
    );
  }

  @override
  State<TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends State<TransferSheet> {
  final _repository = getIt<FinanceRepository>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  List<AccountModel>? _accounts;
  String? _accountsError;
  String? _fromId;
  String? _toId;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
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

  AccountModel? _account(String? id) {
    for (final a in _accounts ?? const <AccountModel>[]) {
      if (a.id == id) return a;
    }
    return null;
  }

  Future<void> _submit() async {
    final from = _account(_fromId);
    final to = _account(_toId);
    final amount = parseAmount(_amountController.text);
    String? problem;
    if (from == null || to == null) {
      problem = 'Выберите счёт списания и счёт зачисления';
    } else if (from.id == to.id) {
      problem = 'Счета списания и зачисления должны различаться';
    } else if (amount <= 0) {
      problem = 'Введите сумму перевода';
    } else if (amount > from.balance) {
      problem = 'Недостаточно средств на счёте списания (${money(from.balance)})';
    }
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await _repository.createTransfer(
        fromAccountId: from!.id,
        toAccountId: to!.id,
        amount: amount,
        description: _noteController.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = apiErrorMessage(e, fallback: 'Не удалось выполнить перевод');
      });
    }
  }

  InputDecoration _decoration(String? hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: AppColors.background.withOpacity(0.3),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.cardBorder),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accounts = _accounts;
    final notEnoughAccounts = accounts != null && accounts.length < 2;

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
                  decoration: BoxDecoration(color: AppColors.neutral300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Перевод между счетами',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 16),
              if (notEnoughAccounts) ...[
                Text(
                  'Для перевода нужно минимум два счёта. Создайте второй счёт в разделе «Счета».',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
                AppButton(
                  label: 'Закрыть',
                  variant: AppButtonVariant.secondary,
                  onPressed: () => Navigator.pop(context),
                ),
              ] else ...[
                Text('Со счёта', style: AppTextStyles.labelMedium),
                const SizedBox(height: 6),
                AbsorbPointer(
                  absorbing: _isSaving,
                  child: AccountDropdown(
                    accounts: accounts,
                    error: _accountsError,
                    onRetry: _loadAccounts,
                    value: _fromId,
                    hint: 'Счёт списания',
                    onChanged: (id) => setState(() {
                      _fromId = id;
                      if (_toId == id) _toId = null;
                    }),
                  ),
                ),
                const SizedBox(height: 14),
                Text('На счёт', style: AppTextStyles.labelMedium),
                const SizedBox(height: 6),
                AbsorbPointer(
                  absorbing: _isSaving,
                  child: AccountDropdown(
                    accounts: accounts,
                    error: _accountsError,
                    onRetry: _loadAccounts,
                    value: _toId,
                    excludeId: _fromId,
                    hint: 'Счёт зачисления',
                    onChanged: (id) => setState(() => _toId = id),
                  ),
                ),
                const SizedBox(height: 14),
                Text('Сумма перевода${currencySuffix()}', style: AppTextStyles.labelMedium),
                const SizedBox(height: 6),
                TextField(
                  controller: _amountController,
                  enabled: !_isSaving,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  decoration: _decoration('0'),
                ),
                const SizedBox(height: 14),
                Text('Комментарий (необязательно)', style: AppTextStyles.labelMedium),
                const SizedBox(height: 6),
                TextField(
                  controller: _noteController,
                  enabled: !_isSaving,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: _decoration('Назначение перевода'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                ],
                const SizedBox(height: 20),
                AppButton(
                  label: 'Перевести',
                  isLoading: _isSaving,
                  onPressed: accounts == null ? null : _submit,
                ),
              ],
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
