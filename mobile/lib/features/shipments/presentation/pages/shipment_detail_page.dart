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
import '../../../inventory/data/models/product_model.dart';
import '../../../inventory/presentation/bloc/inventory_bloc.dart';
import '../../../suppliers/presentation/bloc/suppliers_bloc.dart';
import '../bloc/shipments_bloc.dart';
import '../../data/models/shipment_model.dart';
import '../../data/repositories/shipments_repository.dart';

class ShipmentDetailPage extends StatefulWidget {
  final String shipmentId;

  const ShipmentDetailPage({super.key, required this.shipmentId});

  @override
  State<ShipmentDetailPage> createState() => _ShipmentDetailPageState();
}

class _ShipmentDetailPageState extends State<ShipmentDetailPage> {
  final ShipmentsRepository _repository = getIt<ShipmentsRepository>();

  ShipmentModel? _shipment;
  bool _loading = true;
  bool _confirming = false;
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
      final shipment = await _repository.getShipmentById(widget.shipmentId);
      if (!mounted) return null;
      setState(() {
        _shipment = shipment;
        _loading = false;
        _error = null;
      });
      return null;
    } catch (e) {
      final message = apiErrorMessage(e, fallback: 'Не удалось загрузить данные поставки');
      if (!mounted) return message;
      setState(() {
        _loading = false;
        if (_shipment == null) _error = message;
      });
      return message;
    }
  }

  void _showMessage(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: isError ? AppColors.error : AppColors.success),
    );
  }

  Future<void> _refresh() async {
    final error = await _load(silent: true);
    if (error != null && mounted) _showMessage(error, isError: true);
  }

  Future<void> _confirmReceipt() async {
    if (_confirming) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Подтвердить приёмку?'),
        content: const Text('Все позиции поставки будут оприходованы на склад и остатки обновятся автоматически.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
            child: const Text('Принять'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _confirming = true);
    try {
      final updated = await _repository.confirmShipment(widget.shipmentId);
      if (!mounted) return;
      setState(() {
        _shipment = updated;
        _confirming = false;
      });
      context.read<ShipmentsBloc>().add(const RefreshShipmentsEvent());
      // The goods are on stock now and the supplier is owed for them.
      context.read<InventoryBloc>().add(const RefreshProductsEvent());
      context.read<SuppliersBloc>().add(const LoadSuppliersEvent());
      _showMessage('Приёмка товара подтверждена');
    } catch (e) {
      if (!mounted) return;
      setState(() => _confirming = false);
      _showMessage(apiErrorMessage(e, fallback: 'Не удалось подтвердить приёмку'), isError: true);
      // Somebody else may have received or cancelled it meanwhile.
      _load(silent: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shipment = _shipment;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Детали поставки'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
        child: _buildBody(shipment),
      ),
    );
  }

  Widget _buildBody(ShipmentModel? shipment) {
    if (shipment != null) {
      return RefreshIndicator(onRefresh: _refresh, child: _buildContent(shipment));
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
              _error ?? 'Не удалось загрузить данные поставки',
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

  Widget _buildContent(ShipmentModel shipment) {
    final bool isReceived = shipment.isReceived;
    final bool isCancelled = shipment.status == 'cancelled';
    final Color statusColor = isReceived ? AppColors.success : (isCancelled ? AppColors.error : AppColors.primaryBlue);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        // Status header card
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
                    child: Text(
                      'Накладная: ${shipment.invoiceNumber}',
                      style: AppTextStyles.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isReceived ? AppColors.iconBgGreen : (isCancelled ? AppColors.iconBgRed : AppColors.iconBgBlue),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isReceived ? 'Принято на склад' : (isCancelled ? 'Отменена' : 'Ожидается поставка'),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              _infoRow('Поставщик:', shipment.supplierLabel),
              if (shipment.expectedDate != null)
                _infoRow('Ожидаемая дата:', Formatters.formatDate(shipment.expectedDate!.toLocal())),
              if (shipment.receivedDate != null)
                _infoRow('Дата приёмки:', Formatters.formatDate(shipment.receivedDate!.toLocal())),
              if (shipment.responsibleEmployee != null)
                _infoRow('Ответственный:', shipment.responsibleEmployee!),
              _infoRow('Сумма товаров:', Formatters.formatUzs(shipment.totalCost)),
              _infoRow('Доп. расходы:', Formatters.formatUzs(shipment.additionalCosts)),
              _infoRow('Сумма поставки:', Formatters.formatUzs(shipment.grandTotal), isBold: true),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Text('Товары в поставке (${shipment.items.length})', style: AppTextStyles.titleMedium),
        const SizedBox(height: 10),

        if (shipment.items.isEmpty)
          GlassCard(
            padding: const EdgeInsets.all(20),
            borderRadius: 16,
            child: Center(child: Text('Список товаров пуст', style: AppTextStyles.caption)),
          )
        else
          ...shipment.items.map((item) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  padding: const EdgeInsets.all(14),
                  borderRadius: 14,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.iconBgBlue, shape: BoxShape.circle),
                        child: const Icon(Icons.inventory_2, color: AppColors.primaryBlue, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text('${formatQty(item.quantity)} × ${Formatters.formatUzs(item.unitPrice)}', style: AppTextStyles.caption),
                          ],
                        ),
                      ),
                      Text(Formatters.formatUzs(item.totalPrice), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                ),
              )),

        const SizedBox(height: 24),

        if (shipment.isPending)
          AppButton(
            label: 'Подтвердить приёмку товаров',
            isLoading: _confirming,
            onPressed: _confirmReceipt,
          ),

        const SizedBox(height: 40),
      ],
    );
  }

  Widget _infoRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                fontSize: isBold ? 15 : 13,
                color: isBold ? AppColors.primaryBlue : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
