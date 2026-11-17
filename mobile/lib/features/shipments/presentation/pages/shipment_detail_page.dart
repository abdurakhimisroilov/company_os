import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../bloc/shipments_bloc.dart';
import '../../data/models/shipment_model.dart';

class ShipmentDetailPage extends StatefulWidget {
  final String shipmentId;

  const ShipmentDetailPage({super.key, required this.shipmentId});

  @override
  State<ShipmentDetailPage> createState() => _ShipmentDetailPageState();
}

class _ShipmentDetailPageState extends State<ShipmentDetailPage> {
  @override
  void initState() {
    super.initState();
    context.read<ShipmentsBloc>().add(LoadShipmentDetailEvent(widget.shipmentId));
  }

  void _confirmReceipt() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Подтвердить приёмку?'),
        content: const Text('Все позиции поставки будут оприходованы на склад и остатки обновятся автоматически.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<ShipmentsBloc>().add(ConfirmShipmentEvent(widget.shipmentId));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
            child: const Text('Принять'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Детали поставки'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: BlocConsumer<ShipmentsBloc, ShipmentsState>(
          listener: (context, state) {
            if (state is ShipmentsActionSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message), backgroundColor: AppColors.success),
              );
            }
          },
          builder: (context, state) {
            if (state is ShipmentsLoading) {
              return const LoadingShimmer();
            }
            if (state is ShipmentDetailLoaded) {
              return _buildContent(state.shipment);
            }
            if (state is ShipmentsError) {
              return Center(child: Text(state.message));
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildContent(ShipmentModel shipment) {
    final bool isReceived = shipment.status == 'received';

    return ListView(
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
                  Text('Накладная: ${shipment.invoiceNumber}', style: AppTextStyles.titleMedium),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isReceived ? AppColors.iconBgGreen : AppColors.iconBgBlue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isReceived ? 'Принято на склад' : 'Ожидается поставка',
                      style: TextStyle(
                        color: isReceived ? AppColors.success : AppColors.primaryBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              _infoRow('Поставщик:', shipment.supplierName),
              _infoRow('Ожидаемая дата:', Formatters.formatDate(shipment.expectedDate)),
              if (shipment.receivedDate != null)
                _infoRow('Дата приёмки:', Formatters.formatDate(shipment.receivedDate!)),
              if (shipment.responsibleEmployee != null)
                _infoRow('Ответственный:', shipment.responsibleEmployee!),
              _infoRow('Доп. расходы:', Formatters.formatUzs(shipment.additionalCosts)),
              _infoRow('Сумма поставки:', Formatters.formatUzs(shipment.totalCost), isBold: true),
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
                            Text('${item.quantity.toStringAsFixed(0)} шт × ${Formatters.formatUzs(item.unitPrice)}', style: AppTextStyles.caption),
                          ],
                        ),
                      ),
                      Text(Formatters.formatUzs(item.totalPrice), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                ),
              )),

        const SizedBox(height: 24),

        if (!isReceived)
          AppButton(
            label: 'Подтвердить приёмку товаров',
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
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              fontSize: isBold ? 15 : 13,
              color: isBold ? AppColors.primaryBlue : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
