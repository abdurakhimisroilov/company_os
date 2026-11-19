import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../bloc/finance_bloc.dart';
import '../../data/company_currency.dart';
import '../../data/models/transaction_model.dart';
import '../widgets/finance_form_widgets.dart';
import '../widgets/transaction_detail_sheet.dart';
import '../widgets/transfer_sheet.dart';

class FinancePage extends StatefulWidget {
  const FinancePage({super.key});

  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = ['Все', 'Поступления', 'Расходы', 'Переводы'];
  final List<String> _tabTypes = ['all', 'income', 'expense', 'transfer'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        context.read<FinanceBloc>().add(
              FilterTransactionsByType(_tabTypes[_tabController.index]),
            );
      }
    });
    context.read<FinanceBloc>().add(const LoadFinanceData(resetFilters: true));
    CompanyCurrency.instance.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Resolves when the server has answered, so the pull-to-refresh indicator
  /// stays visible for the whole request.
  Future<void> _refresh() {
    final done = Completer<void>();
    context.read<FinanceBloc>().add(RefreshFinanceData(done: done));
    return done.future;
  }

  Future<void> _openTransfer() async {
    final done = await TransferSheet.show(context);
    if (done != true || !mounted) return;
    notifyFinanceChanged(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Перевод выполнен'), backgroundColor: AppColors.success),
    );
  }

  Future<void> _showTransactionDetails(TransactionModel tx) async {
    final deleted = await TransactionDetailSheet.show(context, tx);
    if (deleted != true || !mounted) return;
    notifyFinanceChanged(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Операция удалена'), backgroundColor: AppColors.success),
    );
  }

  Future<void> _pickDateRange(FinanceLoaded state) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initial = state.startDate != null && state.endDate != null
        ? DateTimeRange(start: state.startDate!, end: state.endDate!)
        : null;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: today,
      initialDateRange: initial,
      helpText: 'Период операций',
      saveText: 'Применить',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: AppColors.isDark
                ? Theme.of(context).colorScheme
                : const ColorScheme.light(primary: AppColors.primaryBlue),
          ),
          child: child!,
        );
      },
    );
    if (picked == null || !mounted) return;
    context.read<FinanceBloc>().add(SetTransactionDateRange(startDate: picked.start, endDate: picked.end));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: BlocConsumer<FinanceBloc, FinanceState>(
                  listenWhen: (previous, current) =>
                      current is FinanceLoaded &&
                      current.notice != null &&
                      (previous is! FinanceLoaded || previous.noticeId != current.noticeId),
                  listener: (context, state) {
                    if (state is FinanceLoaded && state.notice != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(state.notice!), backgroundColor: AppColors.error),
                      );
                    }
                  },
                  builder: (context, state) {
                    if (state is FinanceError) {
                      return _buildErrorState(state.message);
                    }
                    if (state is FinanceLoaded) {
                      return _buildContent(state);
                    }
                    return const LoadingShimmer();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTransactionDialog,
        backgroundColor: AppColors.primaryBlue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Операция',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
            onPressed: () => context.pop(),
          ),
          Expanded(
            child: Text(
              'Финансы',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.primaryBlue),
            tooltip: 'Счета',
            onPressed: () => context.push(AppRoutes.financeAccounts),
          ),
          IconButton(
            icon: const Icon(Icons.request_quote_outlined, color: AppColors.secondaryLavender),
            tooltip: 'Долги',
            onPressed: () => context.push(AppRoutes.financeDebts),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(FinanceLoaded state) {
    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.primaryBlue,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          // Balance Cards Row
          Row(
            children: [
              Expanded(
                child: GlassCard(
                  padding: const EdgeInsets.all(16),
                  borderRadius: 18,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.iconBgGreen,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.payments_outlined, color: AppColors.success, size: 20),
                          ),
                          const SizedBox(width: 8),
                          Text('Касса', style: AppTextStyles.caption),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        money(state.totalCash),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GlassCard(
                  padding: const EdgeInsets.all(16),
                  borderRadius: 18,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.iconBgBlue,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.account_balance_outlined, color: AppColors.primaryBlue, size: 20),
                          ),
                          const SizedBox(width: 8),
                          Text('Банк', style: AppTextStyles.caption),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        money(state.totalBank),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Tab Bar
          Container(
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.cardBackground.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelPadding: const EdgeInsets.symmetric(horizontal: 14),
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: AppColors.primaryBlue,
              ),
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Transactions List Header
          Row(
            children: [
              Expanded(
                child: Text(
                  'История операций',
                  style: AppTextStyles.titleMedium,
                ),
              ),
              if (!state.isListLoading)
                Text(
                  'Всего: ${state.total}',
                  style: AppTextStyles.caption,
                ),
              IconButton(
                icon: Icon(
                  Icons.date_range_outlined,
                  color: state.hasDateFilter ? AppColors.primaryBlue : AppColors.textSecondary,
                  size: 20,
                ),
                tooltip: 'Период',
                visualDensity: VisualDensity.compact,
                onPressed: () => _pickDateRange(state),
              ),
            ],
          ),
          if (state.hasDateFilter)
            Align(
              alignment: Alignment.centerLeft,
              child: InputChip(
                label: Text(
                  '${Formatters.formatDate(state.startDate)} — ${Formatters.formatDate(state.endDate)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.primaryBlue, fontWeight: FontWeight.w600),
                ),
                backgroundColor: AppColors.primaryBlue.withOpacity(0.08),
                side: BorderSide(color: AppColors.primaryBlue.withOpacity(0.3)),
                deleteIconColor: AppColors.primaryBlue,
                onDeleted: () => context.read<FinanceBloc>().add(const SetTransactionDateRange()),
                onPressed: () => _pickDateRange(state),
              ),
            ),
          const SizedBox(height: 8),

          if (state.isListLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator(color: AppColors.primaryBlue)),
            )
          else if (state.transactions.isEmpty)
            _buildEmptyList(state)
          else ...[
            ...state.transactions.map((tx) => _buildTransactionItem(tx)),
            if (state.isLoadingMore)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator(color: AppColors.primaryBlue)),
              )
            else if (state.hasMore)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: TextButton(
                  onPressed: () => context.read<FinanceBloc>().add(const LoadMoreTransactions()),
                  child: Text('Показать ещё (${state.total - state.transactions.length})'),
                ),
              ),
          ],

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildEmptyList(FinanceLoaded state) {
    final filtered = state.currentFilter != 'all' || state.hasDateFilter;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.account_balance_wallet_outlined, size: 56, color: AppColors.textTertiary),
            const SizedBox(height: 12),
            Text(
              filtered ? 'Операций не найдено' : 'Данных пока нет',
              style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              filtered ? 'Измените тип операции или период' : 'Зарегистрируйте первую финансовую операцию',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
            if (!filtered) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => context.push(AppRoutes.financeIncomeAdd),
                    icon: const Icon(Icons.arrow_downward, size: 16),
                    label: const Text('+ Доход'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => context.push(AppRoutes.financeExpenseAdd),
                    icon: const Icon(Icons.arrow_upward, size: 16),
                    label: const Text('+ Расход'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(TransactionModel tx) {
    final Color amountColor = transactionColor(tx);
    final String title = tx.description.isNotEmpty ? tx.description : tx.category;
    final bool hasDocument = tx.documentUrl != null && tx.documentUrl!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        onTap: () => _showTransactionDetails(tx),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        borderRadius: 14,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: transactionIconBg(tx), shape: BoxShape.circle),
              child: Icon(transactionIcon(tx), color: amountColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        Formatters.formatDate(tx.date),
                        style: AppTextStyles.caption,
                      ),
                      if (tx.accountName != null) ...[
                        Text(' • ', style: TextStyle(color: AppColors.textTertiary)),
                        Flexible(
                          child: Text(
                            tx.accountName!,
                            style: AppTextStyles.caption,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      if (hasDocument) ...[
                        Text(' • ', style: TextStyle(color: AppColors.textTertiary)),
                        const Icon(Icons.attach_file, size: 12, color: AppColors.primaryBlue),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              transactionAmountText(tx),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: amountColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => context.read<FinanceBloc>().add(const LoadFinanceData()),
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

  void _showAddTransactionDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.neutral300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Выберите тип операции',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.iconBgGreen, shape: BoxShape.circle),
                  child: const Icon(Icons.arrow_downward, color: AppColors.success),
                ),
                title: Text('Поступление средств', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                subtitle: Text('Оплата от клиента, прочий доход', style: TextStyle(color: AppColors.textSecondary)),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push(AppRoutes.financeIncomeAdd);
                },
              ),
              const Divider(),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.iconBgRed, shape: BoxShape.circle),
                  child: const Icon(Icons.arrow_upward, color: AppColors.error),
                ),
                title: Text('Расход средств', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                subtitle: Text('Оплата поставщику, аренда, зарплата', style: TextStyle(color: AppColors.textSecondary)),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push(AppRoutes.financeExpenseAdd);
                },
              ),
              const Divider(),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.infoLight, shape: BoxShape.circle),
                  child: const Icon(Icons.swap_horiz, color: AppColors.info),
                ),
                title: Text('Перевод между счетами', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                subtitle: Text('Из кассы в банк, с карты на счёт', style: TextStyle(color: AppColors.textSecondary)),
                onTap: () {
                  Navigator.pop(ctx);
                  _openTransfer();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
