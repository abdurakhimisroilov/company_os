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
import '../widgets/finance_form_widgets.dart';

class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key});

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  final _repository = getIt<FinanceRepository>();
  List<AccountModel>? _accounts;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    CompanyCurrency.instance.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
  }

  /// Keeps the loaded list on screen while it is being re-read.
  Future<void> _load() async {
    if (_accounts == null && _error != null) setState(() => _error = null);
    try {
      final accounts = await _repository.getAccounts();
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      final message = apiErrorMessage(e, fallback: 'Не удалось загрузить счета');
      if (_accounts == null) {
        setState(() => _error = message);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _showCreateAccountSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CreateAccountSheet(),
    );
    if (created != true || !mounted) return;
    notifyFinanceChanged(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Счёт создан'), backgroundColor: AppColors.success),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Счета компании'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: AppColors.primaryBlue),
            tooltip: 'Новый счёт',
            onPressed: _showCreateAccountSheet,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final accounts = _accounts;
    if (accounts == null) {
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

    double total = 0.0;
    for (final a in accounts) {
      total += a.balance;
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primaryBlue,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          // Total summary card
          GlassCard(
            padding: const EdgeInsets.all(20),
            borderRadius: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Общий баланс всех счетов', style: AppTextStyles.labelMedium),
                const SizedBox(height: 8),
                Text(
                  money(total),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Список счетов', style: AppTextStyles.titleMedium),
          const SizedBox(height: 12),
          if (accounts.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    Text('Нет открытых счетов', style: AppTextStyles.bodyMedium),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _showCreateAccountSheet,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Создать счёт'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...accounts.map((acc) => _buildAccountCard(acc)),
        ],
      ),
    );
  }

  Widget _buildAccountCard(AccountModel account) {
    IconData icon;
    Color iconColor;
    Color iconBg;

    if (account.type == 'cash') {
      icon = Icons.payments_outlined;
      iconColor = AppColors.success;
      iconBg = AppColors.iconBgGreen;
    } else if (account.type == 'card') {
      icon = Icons.credit_card;
      iconColor = AppColors.secondaryLavender;
      iconBg = AppColors.iconBgPurple;
    } else {
      icon = Icons.account_balance_outlined;
      iconColor = AppColors.primaryBlue;
      iconBg = AppColors.iconBgBlue;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        borderRadius: 16,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    account.accountNumber == null ? account.typeLabel : '${account.typeLabel} • ${account.accountNumber}',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  money(account.balance),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(account.currency, style: AppTextStyles.caption),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Creates an account; stays open with a loading state until the server answers.
class _CreateAccountSheet extends StatefulWidget {
  const _CreateAccountSheet();

  @override
  State<_CreateAccountSheet> createState() => _CreateAccountSheetState();
}

class _CreateAccountSheetState extends State<_CreateAccountSheet> {
  final _nameController = TextEditingController();
  final _numberController = TextEditingController();
  String _type = 'cash';
  bool _isSaving = false;
  String? _error;

  static const _types = [
    {'id': 'cash', 'label': 'Касса'},
    {'id': 'bank', 'label': 'Банк'},
    {'id': 'card', 'label': 'Карта'},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Укажите название счёта');
      return;
    }
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await getIt<FinanceRepository>().createAccount(
        name: name,
        type: _type,
        accountNumber: _numberController.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = apiErrorMessage(e, fallback: 'Не удалось создать счёт');
      });
    }
  }

  InputDecoration _decoration(String hint) {
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
                'Новый счёт',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 16),
              Text('Название', style: AppTextStyles.labelMedium),
              const SizedBox(height: 6),
              TextField(
                controller: _nameController,
                enabled: !_isSaving,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: _decoration('Например: Касса магазина'),
              ),
              const SizedBox(height: 14),
              Text('Тип счёта', style: AppTextStyles.labelMedium),
              const SizedBox(height: 8),
              Row(
                children: _types.map((t) {
                  final sel = _type == t['id'];
                  return Expanded(
                    child: GestureDetector(
                      onTap: _isSaving ? null : () => setState(() => _type = t['id']!),
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
                            t['label']!,
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
              Text('Номер счёта / карты (необязательно)', style: AppTextStyles.labelMedium),
              const SizedBox(height: 6),
              TextField(
                controller: _numberController,
                enabled: !_isSaving,
                keyboardType: TextInputType.number,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: _decoration('Номер счёта или карты'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
              ],
              const SizedBox(height: 20),
              AppButton(label: 'Создать счёт', isLoading: _isSaving, onPressed: _save),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
