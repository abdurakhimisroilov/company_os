import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../../../customers/presentation/bloc/customers_bloc.dart';
import '../../../inventory/data/models/product_model.dart';
import '../bloc/sales_bloc.dart';
import '../../data/models/sale_model.dart';
import '../../data/repositories/sales_repository.dart';

class SaleDetailPage extends StatefulWidget {
  final String saleId;

  const SaleDetailPage({super.key, required this.saleId});

  @override
  State<SaleDetailPage> createState() => _SaleDetailPageState();
}

class _SaleDetailPageState extends State<SaleDetailPage> {
  final SalesRepository _repository = getIt<SalesRepository>();

  SaleModel? _sale;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// With [silent] the content already on screen stays visible; returns an error text or null.
  Future<String?> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final sale = await _repository.getSaleById(widget.saleId);
      if (!mounted) return null;
      setState(() {
        _sale = sale;
        _loading = false;
        _error = null;
      });
      return null;
    } catch (e) {
      final message = apiErrorMessage(e, fallback: 'Не удалось загрузить данные продажи');
      if (!mounted) return message;
      setState(() {
        _loading = false;
        if (_sale == null) _error = message;
      });
      return message;
    }
  }

  Future<void> _refresh() async {
    final error = await _load(silent: true);
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _showAddPaymentDialog(SaleModel sale) async {
    final updated = await showModalBottomSheet<SaleModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PaymentSheet(sale: sale, repository: _repository),
    );
    if (updated == null || !mounted) return;
    setState(() => _sale = updated);
    context.read<SalesBloc>().add(const RefreshSalesEvent());
    // The payment reduced the customer's debt.
    context.read<CustomersBloc>().add(const LoadCustomersEvent());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Оплата успешно принята'), backgroundColor: AppColors.success),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sale = _sale;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Детали продажи'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
        child: _buildBody(sale),
      ),
    );
  }

  Widget _buildBody(SaleModel? sale) {
    if (sale != null) {
      return RefreshIndicator(onRefresh: _refresh, child: _buildContent(sale));
    }
    if (_loading) return const LoadingShimmer();
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              _error ?? 'Не удалось загрузить данные продажи',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _load, child: const Text('Повторить')),
        ],
      ),
    );
  }

  Widget _buildContent(SaleModel sale) {
    final bool isPaid = sale.paymentStatus == 'paid';

    final bool isPartial = sale.paymentStatus == 'partial';

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
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
                  Expanded(
                    child: Text(sale.customerLabel, style: AppTextStyles.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isPaid ? AppColors.iconBgGreen : (isPartial ? AppColors.warningLight : AppColors.iconBgRed),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isPaid ? 'Оплачено' : (isPartial ? 'Частично' : 'Долг'),
                      style: TextStyle(
                        color: isPaid ? AppColors.success : (isPartial ? AppColors.warning : AppColors.error),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              if (sale.saleNumber.isNotEmpty) _row('Номер:', sale.saleNumber),
              if (sale.date != null) _row('Дата продажи:', Formatters.formatDateTime(sale.date!.toLocal())),
              if (sale.managerName != null) _row('Менеджер:', sale.managerName!),
              _row('Способ оплаты:', paymentMethodLabel(sale.paymentMethod)),
              if (sale.discount > 0) ...[
                _row('Сумма товаров:', Formatters.formatUzs(sale.subtotal)),
                _row('Скидка:', '-${Formatters.formatUzs(sale.discount)}'),
              ],
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
                            Text('${formatQty(it.quantity)} × ${Formatters.formatUzs(it.price)}', style: AppTextStyles.caption),
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
                          Text(
                            p.date != null ? Formatters.formatDateTime(p.date!.toLocal()) : 'Платёж',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Text(paymentMethodLabel(p.method), style: AppTextStyles.caption),
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

/// Takes a payment for a sale. Stays open until the server answers and
/// closes with the updated sale; a refusal is shown inside the sheet.
class _PaymentSheet extends StatefulWidget {
  const _PaymentSheet({required this.sale, required this.repository});

  final SaleModel sale;
  final SalesRepository repository;

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  late final TextEditingController _amountController;
  String _method = 'cash';
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: formatQty(widget.sale.debtAmount));
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    final amount = parseAmount(_amountController.text);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Укажите сумму платежа больше 0');
      return;
    }
    if (amount > widget.sale.debtAmount) {
      setState(() => _error = 'Сумма оплаты больше остатка: ${Formatters.formatUzs(widget.sale.debtAmount)}');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await widget.repository.addPayment(widget.sale.id, amount, _method);
      if (!mounted) return;
      Navigator.pop(context, updated);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = apiErrorMessage(e, fallback: 'Не удалось провести платёж');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Принять оплату по долгу', style: AppTextStyles.titleMedium),
          const SizedBox(height: 4),
          Text('Остаток долга: ${Formatters.formatUzs(widget.sale.debtAmount)}', style: AppTextStyles.caption),
          const SizedBox(height: 14),
          TextField(
            controller: _amountController,
            enabled: !_saving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Сумма платежа',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _methodChip('cash'),
              const SizedBox(width: 8),
              _methodChip('bank'),
              const SizedBox(width: 8),
              _methodChip('card'),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: AppTextStyles.caption.copyWith(color: AppColors.error)),
          ],
          const SizedBox(height: 20),
          AppButton(
            label: 'Провести платёж',
            isLoading: _saving,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }

  Widget _methodChip(String id) {
    final isSelected = id == _method;
    return Expanded(
      child: GestureDetector(
        onTap: _saving ? null : () => setState(() => _method = id),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryBlue : AppColors.neutral100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              paymentMethodLabel(id),
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
}
