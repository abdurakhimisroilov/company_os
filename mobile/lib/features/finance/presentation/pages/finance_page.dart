import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../bloc/finance_bloc.dart';
import '../../data/models/transaction_model.dart';

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
    context.read<FinanceBloc>().add(const LoadFinanceData());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: BlocConsumer<FinanceBloc, FinanceState>(
                  listener: (context, state) {
                    if (state is FinanceActionSuccess) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(state.message),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  },
                  builder: (context, state) {
                    if (state is FinanceLoading) {
                      return const LoadingShimmer();
                    }
                    if (state is FinanceError) {
                      return _buildErrorState(state.message);
                    }
                    if (state is FinanceLoaded) {
                      return _buildContent(state);
                    }
                    return const SizedBox.shrink();
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
            icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
            onPressed: () => context.pop(),
          ),
          const Expanded(
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
            onPressed: () => context.push('/finance/accounts'),
          ),
          IconButton(
            icon: const Icon(Icons.request_quote_outlined, color: AppColors.secondaryLavender),
            tooltip: 'Долги',
            onPressed: () => context.push('/finance/debts'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(FinanceLoaded state) {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<FinanceBloc>().add(const LoadFinanceData());
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                        Formatters.formatUzs(state.totalCash),
                        style: const TextStyle(
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
                        Formatters.formatUzs(state.totalBank),
                        style: const TextStyle(
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
              color: Colors.white.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'История операций',
                style: AppTextStyles.titleMedium,
              ),
              Text(
                '${state.transactions.length} записей',
                style: AppTextStyles.caption,
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (state.transactions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.account_balance_wallet_outlined, size: 56, color: AppColors.textTertiary),
                    const SizedBox(height: 12),
                    Text(
                      'Данных пока нет',
                      style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Зарегистрируйте первую финансовую операцию',
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => context.push('/finance/income/add'),
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
                          onPressed: () => context.push('/finance/expense/add'),
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
                ),
              ),
            )
          else
            ...state.transactions.map((tx) => _buildTransactionItem(tx)),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(TransactionModel tx) {
    final bool isIncome = tx.type == 'income';
    final bool isTransfer = tx.type == 'transfer';
    final Color amountColor = isIncome
        ? AppColors.success
        : (isTransfer ? AppColors.info : AppColors.error);
    final String amountPrefix = isIncome ? '+' : (isTransfer ? '' : '-');

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
              decoration: BoxDecoration(
                color: isIncome
                    ? AppColors.iconBgGreen
                    : (isTransfer ? AppColors.infoLight : AppColors.iconBgRed),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isIncome
                    ? Icons.arrow_downward
                    : (isTransfer ? Icons.swap_horiz : Icons.arrow_upward),
                color: amountColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.description.isNotEmpty ? tx.description : tx.category,
                    style: const TextStyle(
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
                        const Text(' • ', style: TextStyle(color: AppColors.textTertiary)),
                        Flexible(
                          child: Text(
                            tx.accountName!,
                            style: AppTextStyles.caption,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      if (tx.documentUrl != null && tx.documentUrl!.isNotEmpty) ...[
                        const Text(' • ', style: TextStyle(color: AppColors.textTertiary)),
                        const Icon(Icons.attach_file, size: 12, color: AppColors.primaryBlue),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            tx.documentName ?? 'Документ',
                            style: const TextStyle(fontSize: 11, color: AppColors.primaryBlue, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$amountPrefix${Formatters.formatUzs(tx.amount)}',
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

  void _showTransactionDetails(TransactionModel tx) {
    final bool isIncome = tx.type == 'income';
    final bool isTransfer = tx.type == 'transfer';
    final Color amountColor = isIncome
        ? AppColors.success
        : (isTransfer ? AppColors.info : AppColors.error);
    final String amountPrefix = isIncome ? '+' : (isTransfer ? '' : '-');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isIncome
                          ? AppColors.iconBgGreen
                          : (isTransfer ? AppColors.infoLight : AppColors.iconBgRed),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isIncome
                          ? Icons.arrow_downward
                          : (isTransfer ? Icons.swap_horiz : Icons.arrow_upward),
                      color: amountColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isIncome ? 'Поступление средств' : (isTransfer ? 'Внутренний перевод' : 'Расход средств'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          Formatters.formatDate(tx.date),
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '$amountPrefix${Formatters.formatUzs(tx.amount)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: amountColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),

              _buildDetailRow('Категория', tx.category),
              if (tx.accountName != null)
                _buildDetailRow('Счет / Касса', tx.accountName!),
              if (tx.description.isNotEmpty)
                _buildDetailRow('Описание', tx.description),
              if (tx.employeeName != null)
                _buildDetailRow('Сотрудник', tx.employeeName!),

              if (tx.documentUrl != null && tx.documentUrl!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Прикрепленный документ:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.primaryBlue.withOpacity(0.25)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.description, color: AppColors.primaryBlue, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tx.documentName ?? 'Документ транзакции',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            const Text('Прикреплен к операции', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => _downloadAndOpenDocument(tx.documentUrl!, tx.documentName),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Скачать', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.background,
                  foregroundColor: AppColors.textPrimary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Закрыть', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadAndOpenDocument(String docUrl, String? docName) async {
    try {
      final fullUrl = docUrl.startsWith('http') ? docUrl : 'http://45.158.199.215:3000$docUrl';
      final tempDir = await getTemporaryDirectory();
      final fileName = docName ?? 'document_${DateTime.now().millisecondsSinceEpoch}';
      final savePath = '${tempDir.path}/$fileName';

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Загрузка документа с сервера...'),
          duration: Duration(seconds: 1),
        ),
      );

      final apiClient = getIt<ApiClient>();
      await apiClient.dio.download(fullUrl, savePath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Документ успешно загружен: $fileName'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Ошибка скачивания: $e'),
          ),
        );
      }
    }
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
        decoration: const BoxDecoration(
          color: Colors.white,
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
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
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
                title: const Text('Поступление средств', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Оплата от клиента, прочий доход'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/finance/income/add');
                },
              ),
              const Divider(),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.iconBgRed, shape: BoxShape.circle),
                  child: const Icon(Icons.arrow_upward, color: AppColors.error),
                ),
                title: const Text('Расход средств', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Оплата поставщику, аренда, зарплата'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/finance/expense/add');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
