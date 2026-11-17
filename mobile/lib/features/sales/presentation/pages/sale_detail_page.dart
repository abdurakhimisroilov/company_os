import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../bloc/sales_bloc.dart';
import '../../data/models/sale_model.dart';

class SaleDetailPage extends StatefulWidget {
  final String saleId;

  const SaleDetailPage({super.key, required this.saleId});

  @override
  State<SaleDetailPage> createState() => _SaleDetailPageState();
}

class _SaleDetailPageState extends State<SaleDetailPage> {
  @override
  void initState() {
    super.initState();
    context.read<SalesBloc>().add(LoadSaleDetailEvent(widget.saleId));
  }

  void _showAddPaymentDialog(SaleModel sale) {
    final amountController = TextEditingController(text: sale.debtAmount.toStringAsFixed(0));
    String method = 'cash';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Принять оплату по долгу', style: AppTextStyles.titleMedium),
              const SizedBox(height: 14),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Сумма платежа (UZS)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _methodChip('cash', 'Наличные', method, (m) => setModalState(() => method = m)),
                  const SizedBox(width: 8),
                  _methodChip('bank', 'Банк', method, (m) => setModalState(() => method = m)),
                  const SizedBox(width: 8),
                  _methodChip('card', 'Карта', method, (m) => setModalState(() => method = m)),
                ],
              ),
              const SizedBox(height: 20),
              AppButton(
                label: 'Провести платёж',
                onPressed: () {
                  final amt = double.tryParse(amountController.text.replaceAll(' ', '')) ?? 0;
                  if (amt > 0) {
                    Navigator.pop(ctx);
                    context.read<SalesBloc>().add(AddSalePaymentEvent(
                          saleId: widget.saleId,
                          amount: amt,
                          method: method,
                        ));
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _methodChip(String id, String label, String selected, ValueChanged<String> onSelect) {
    final isSelected = id == selected;
    return Expanded(
      child: GestureDetector(
        onTap: () => onSelect(id),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryBlue : Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Детали продажи'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: BlocConsumer<SalesBloc, SalesState>(
          listener: (context, state) {
            if (state is SalesActionSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message), backgroundColor: AppColors.success),
              );
            }
          },
          builder: (context, state) {
            if (state is SalesLoading) {
              return const LoadingShimmer();
            }
            if (state is SaleDetailLoaded) {
              return _buildContent(state.sale);
            }
            if (state is SalesError) {
              return Center(child: Text(state.message));
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildContent(SaleModel sale) {
    final bool isPaid = sale.paymentStatus == 'paid';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header info
        GlassCard(
          padding: const EdgeInsets.all(18),
          borderRadius: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(sale.customerName, style: AppTextStyles.titleMedium),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isPaid ? AppColors.iconBgGreen : AppColors.iconBgRed,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isPaid ? 'Оплачено' : (sale.paymentStatus == 'partial' ? 'Частично' : 'Долг'),
                      style: TextStyle(
                        color: isPaid ? AppColors.success : AppColors.error,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              _row('Дата продажи:', Formatters.formatDate(sale.date)),
              if (sale.managerName != null) _row('Менеджер:', sale.managerName!),
              _row('Сумма продажи:', Formatters.formatUzs(sale.totalAmount), isBold: true),
              _row('Оплачено:', Formatters.formatUzs(sale.paidAmount)),
              if (!isPaid)
                _row('Остаток долга:', Formatters.formatUzs(sale.debtAmount), isRed: true),
            ],
          ),
        ),
        const SizedBox(height: 18),

        Text('Товары в заказе (${sale.items.length})', style: AppTextStyles.titleMedium),
        const SizedBox(height: 8),

        if (sale.items.isEmpty)
          GlassCard(
            padding: const EdgeInsets.all(20),
            borderRadius: 14,
            child: Center(child: Text('Товары не указаны', style: AppTextStyles.caption)),
          )
        else
          ...sale.items.map((it) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  padding: const EdgeInsets.all(12),
                  borderRadius: 14,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppColors.iconBgBlue, shape: BoxShape.circle),
                        child: const Icon(Icons.shopping_bag_outlined, color: AppColors.primaryBlue, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(it.productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text('${it.quantity.toStringAsFixed(0)} × ${Formatters.formatUzs(it.price)}', style: AppTextStyles.caption),
                          ],
                        ),
                      ),
                      Text(Formatters.formatUzs(it.total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                ),
              )),

        const SizedBox(height: 18),

        // Payment history
        Text('История платежей', style: AppTextStyles.titleMedium),
        const SizedBox(height: 8),

        if (sale.payments.isEmpty)
          GlassCard(
            padding: const EdgeInsets.all(16),
            borderRadius: 14,
            child: Center(child: Text('Платежей пока не зарегистрировано', style: AppTextStyles.caption)),
          )
        else
          ...sale.payments.map((p) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  padding: const EdgeInsets.all(12),
                  borderRadius: 12,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(Formatters.formatDate(p.date), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text(p.method == 'cash' ? 'Наличные' : (p.method == 'card' ? 'Карта' : 'Банк'), style: AppTextStyles.caption),
                        ],
                      ),
                      Text(
                        '+${Formatters.formatUzs(p.amount)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              )),

        const SizedBox(height: 24),

        if (!isPaid)
          AppButton(
            label: 'Принять платёж по долгу',
            onPressed: () => _showAddPaymentDialog(sale),
          ),

        const SizedBox(height: 40),
      ],
    );
  }

  Widget _row(String label, String value, {bool isBold = false, bool isRed = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.caption),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              fontSize: isBold ? 15 : 13,
              color: isRed ? AppColors.error : (isBold ? AppColors.primaryBlue : AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
