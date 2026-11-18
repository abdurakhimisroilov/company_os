import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../dashboard/presentation/bloc/dashboard_bloc.dart';
import '../../data/company_currency.dart';
import '../../data/models/transaction_model.dart';
import '../bloc/finance_bloc.dart';

/// Money moved on the server: the finance list and the dashboard figures are
/// re-read so both show the new totals without a manual refresh.
void notifyFinanceChanged(BuildContext context) {
  context.read<FinanceBloc>().add(const RefreshFinanceData());
  context.read<DashboardBloc>().add(const RefreshDashboardStats());
}

/// Parses "1 500 000" / "1500000,50"; returns 0 for anything that is not a number.
double parseAmount(String text) {
  final clean = text.replaceAll(RegExp(r'\s'), '').replaceAll(',', '.');
  return double.tryParse(clean) ?? 0.0;
}

/// "(UZS)" suffix for amount labels, empty until the currency is known.
String currencySuffix() {
  final code = CompanyCurrency.instance.value;
  return code.isEmpty ? '' : ' ($code)';
}

const List<Map<String, String>> paymentMethods = [
  {'id': 'cash', 'label': 'Наличные'},
  {'id': 'bank', 'label': 'Банк'},
  {'id': 'card', 'label': 'Карта'},
];

class PaymentMethodSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const PaymentMethodSelector({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: paymentMethods.map((m) {
        final isSelected = value == m['id'];
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(m['id']!),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryBlue : AppColors.cardBackground,
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
    );
  }
}

/// Dropdown of the organization's real accounts. With [autoLabel] the first
/// entry (value null) lets the server choose the account by payment method.
class AccountDropdown extends StatelessWidget {
  final List<AccountModel>? accounts;
  final String? error;
  final VoidCallback onRetry;
  final String? value;
  final ValueChanged<String?> onChanged;
  final String? autoLabel;
  final String hint;
  final String? excludeId;

  const AccountDropdown({
    super.key,
    required this.accounts,
    required this.error,
    required this.onRetry,
    required this.value,
    required this.onChanged,
    this.autoLabel,
    this.hint = 'Выберите счёт',
    this.excludeId,
  });

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.cardBorder),
    );

    if (error != null) {
      return Container(
        padding: const EdgeInsets.only(left: 16, right: 4),
        decoration: decoration,
        child: Row(
          children: [
            Expanded(child: Text(error!, style: AppTextStyles.caption.copyWith(color: AppColors.error))),
            TextButton(onPressed: onRetry, child: const Text('Повторить')),
          ],
        ),
      );
    }
    final list = accounts;
    if (list == null) {
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
            Text('Загрузка счетов…', style: AppTextStyles.caption),
          ],
        ),
      );
    }

    final shown = list.where((a) => a.id != excludeId).toList();
    final current = shown.any((a) => a.id == value) ? value : null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: decoration,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: current,
          isExpanded: true,
          dropdownColor: AppColors.cardBackground,
          style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
          hint: Text(autoLabel ?? hint, style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
          items: [
            if (autoLabel != null) DropdownMenuItem<String?>(value: null, child: Text(autoLabel!)),
            ...shown.map(
              (a) => DropdownMenuItem<String?>(
                value: a.id,
                child: Text('${a.name} • ${money(a.balance)}', overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}
