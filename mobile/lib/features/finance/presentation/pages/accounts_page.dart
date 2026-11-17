import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../bloc/finance_bloc.dart';
import '../../data/models/transaction_model.dart';

class AccountsPage extends StatelessWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Счета компании'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: BlocBuilder<FinanceBloc, FinanceState>(
          builder: (context, state) {
            if (state is FinanceLoading) {
              return const LoadingShimmer();
            }
            if (state is FinanceLoaded) {
              final accounts = state.accounts;
              double total = 0.0;
              for (final a in accounts) {
                total += a.balance;
              }

              return ListView(
                padding: const EdgeInsets.all(16),
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
                          Formatters.formatUzs(total),
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
                        child: Text('Нет открытых счетов', style: AppTextStyles.bodyMedium),
                      ),
                    )
                  else
                    ...accounts.map((acc) => _buildAccountCard(acc)),
                ],
              );
            }
            return Center(
              child: ElevatedButton(
                onPressed: () => context.read<FinanceBloc>().add(const LoadFinanceData()),
                child: const Text('Загрузить'),
              ),
            );
          },
        ),
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
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    account.type == 'cash'
                        ? 'Наличная касса'
                        : (account.type == 'card' ? 'Корпоративная карта' : 'Расчётный счёт'),
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  Formatters.formatUzs(account.balance),
                  style: const TextStyle(
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
