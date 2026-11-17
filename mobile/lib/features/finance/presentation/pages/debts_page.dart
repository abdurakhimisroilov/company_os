import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../bloc/finance_bloc.dart';
import '../../data/models/transaction_model.dart';
import '../widgets/attachment_picker_card.dart';

class DebtsPage extends StatefulWidget {
  const DebtsPage({super.key});

  @override
  State<DebtsPage> createState() => _DebtsPageState();
}

class _DebtsPageState extends State<DebtsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    context.read<FinanceBloc>().add(LoadDebtsEvent());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showPayDebtModal(DebtModel debt, {required bool isCustomer}) {
    final amountController = TextEditingController(
      text: debt.remainingAmount > 0 ? debt.remainingAmount.toStringAsFixed(0) : '0',
    );
    final noteController = TextEditingController();
    String paymentMethod = 'cash';
    String? docUrl;
    String? docName;
    bool isSaving = false;

    final title = isCustomer
        ? (debt.customerName ?? 'Клиент #${debt.customerId}')
        : (debt.supplierName ?? 'Поставщик #${debt.supplierId}');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              top: 20,
              left: 20,
              right: 20,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isCustomer ? 'Прием оплаты задолженности' : 'Оплата задолженности поставщику',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
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
                        const Text('Остаток задолженности:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        Text(
                          Formatters.formatUzs(debt.remainingAmount),
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
                  Text('Сумма оплаты (UZS)', style: AppTextStyles.labelMedium),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
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
                    children: [
                      {'id': 'cash', 'label': 'Наличные'},
                      {'id': 'bank', 'label': 'Расчетный счет'},
                      {'id': 'card', 'label': 'Карта'},
                    ].map((m) {
                      final sel = paymentMethod == m['id'];
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => paymentMethod = m['id']!),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: sel ? AppColors.primaryBlue : Colors.white,
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
                  AttachmentPickerCard(
                    initialDocumentUrl: docUrl,
                    initialDocumentName: docName,
                    onAttachmentChanged: (att) {
                      setModalState(() {
                        docUrl = att?['url'];
                        docName = att?['name'];
                      });
                    },
                  ),
                  const SizedBox(height: 14),

                  // Примечание
                  Text('Примечание к оплате', style: AppTextStyles.labelMedium),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: noteController,
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
                  const SizedBox(height: 20),

                  // Кнопка сохранения
                  AppButton(
                    label: isCustomer ? 'Принять оплату' : 'Подтвердить оплату',
                    isLoading: isSaving,
                    onPressed: () {
                      final amt = double.tryParse(amountController.text.replaceAll(' ', '')) ?? 0.0;
                      if (amt <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Введите корректную сумму'), backgroundColor: AppColors.error),
                        );
                        return;
                      }

                      setModalState(() => isSaving = true);
                      Navigator.pop(bottomSheetCtx);

                      final data = {
                        'debtId': isCustomer ? debt.customerId : debt.supplierId,
                        'type': isCustomer ? 'receivable' : 'payable',
                        'amount': amt,
                        'paymentMethod': paymentMethod,
                        'documentUrl': docUrl,
                        'documentName': docName,
                        'description': noteController.text.trim().isNotEmpty
                            ? noteController.text.trim()
                            : (isCustomer ? 'Оплата задолженности: $title' : 'Погашение долга поставщику: $title'),
                      };

                      context.read<FinanceBloc>().add(PayDebtEvent(data));
                    },
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          );
        },
      ),
    );
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
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
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
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: BlocConsumer<FinanceBloc, FinanceState>(
          listener: (context, state) {
            if (state is FinanceActionSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message), backgroundColor: AppColors.success),
              );
            }
          },
          builder: (context, state) {
            if (state is FinanceLoading) {
              return const LoadingShimmer();
            }
            if (state is FinanceDebtsLoaded) {
              return TabBarView(
                controller: _tabController,
                children: [
                  _buildDebtList(state.customerDebts, isCustomer: true),
                  _buildDebtList(state.supplierDebts, isCustomer: false),
                ],
              );
            }
            if (state is FinanceError) {
              return Center(child: Text(state.message));
            }
            return Center(
              child: ElevatedButton(
                onPressed: () => context.read<FinanceBloc>().add(LoadDebtsEvent()),
                child: const Text('Загрузить'),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDebtList(List<DebtModel> debts, {required bool isCustomer}) {
    if (debts.isEmpty) {
      return Center(
        child: Text(
          isCustomer ? 'Нет дебиторской задолженности' : 'Нет кредиторской задолженности',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
        ),
      );
    }

    double total = 0;
    for (final d in debts) {
      total += d.remainingAmount;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GlassCard(
          padding: const EdgeInsets.all(16),
          borderRadius: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Итого задолженность:', style: AppTextStyles.titleMedium),
              Text(
                Formatters.formatUzs(total),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isCustomer ? AppColors.success : AppColors.error,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...debts.map((debt) {
          final title = isCustomer
              ? (debt.customerName ?? 'Клиент #${debt.customerId}')
              : (debt.supplierName ?? 'Поставщик #${debt.supplierId}');

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
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Срок: ${Formatters.formatDate(debt.dueDate)}',
                            style: AppTextStyles.caption,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.payment, size: 12, color: AppColors.primaryBlue),
                              const SizedBox(width: 4),
                              Text(
                                isCustomer ? 'Нажмите, чтобы принять оплату' : 'Нажмите, чтобы оплатить',
                                style: const TextStyle(fontSize: 11, color: AppColors.primaryBlue, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          Formatters.formatUzs(debt.remainingAmount),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isCustomer ? AppColors.success : AppColors.error,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: debt.status == 'overdue' ? AppColors.errorLight : AppColors.warningLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            debt.status == 'overdue' ? 'Просрочено' : 'Ожидается',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: debt.status == 'overdue' ? AppColors.error : AppColors.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
