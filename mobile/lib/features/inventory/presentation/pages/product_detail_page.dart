import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../bloc/inventory_bloc.dart';
import '../../data/models/product_model.dart';

class ProductDetailPage extends StatefulWidget {
  final String productId;

  const ProductDetailPage({super.key, required this.productId});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  @override
  void initState() {
    super.initState();
    context.read<InventoryBloc>().add(LoadProductDetailEvent(widget.productId));
  }

  void _showEditDialog(ProductModel product) {
    final nameCtrl = TextEditingController(text: product.name);
    final sellingPriceCtrl = TextEditingController(text: product.sellingPrice.toStringAsFixed(0));
    final purchasePriceCtrl = TextEditingController(text: product.purchasePrice.toStringAsFixed(0));
    final unitCtrl = TextEditingController(text: product.unit);
    final minStockCtrl = TextEditingController(text: product.minStockLevel.toStringAsFixed(0));
    final barcodeCtrl = TextEditingController(text: product.barcode ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Редактировать товар'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Название товара')),
              TextField(controller: sellingPriceCtrl, decoration: const InputDecoration(labelText: 'Цена продажи (сум)'), keyboardType: TextInputType.number),
              TextField(controller: purchasePriceCtrl, decoration: const InputDecoration(labelText: 'Цена закупки (сум)'), keyboardType: TextInputType.number),
              TextField(controller: unitCtrl, decoration: const InputDecoration(labelText: 'Единица измерения (шт, кг...)')),
              TextField(controller: minStockCtrl, decoration: const InputDecoration(labelText: 'Мин. остаток'), keyboardType: TextInputType.number),
              TextField(controller: barcodeCtrl, decoration: const InputDecoration(labelText: 'Штрихкод')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<InventoryBloc>().add(
                    UpdateProductEvent(
                      productId: product.id,
                      data: {
                        'name': nameCtrl.text.trim(),
                        'sellingPrice': double.tryParse(sellingPriceCtrl.text.replaceAll(' ', '')) ?? product.sellingPrice,
                        'purchasePrice': double.tryParse(purchasePriceCtrl.text.replaceAll(' ', '')) ?? product.purchasePrice,
                        'unit': unitCtrl.text.trim(),
                        'minStockLevel': double.tryParse(minStockCtrl.text) ?? product.minStockLevel,
                        'barcode': barcodeCtrl.text.trim(),
                      },
                    ),
                  );
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(ProductModel product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить товар?'),
        content: Text('Вы уверены, что хотите удалить товар "${product.name}"? Это действие нельзя отменить.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<InventoryBloc>().add(DeleteProductEvent(product.id));
              context.pop();
            },
            child: const Text('Удалить'),
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
        title: const Text('Карточка товара'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          BlocBuilder<InventoryBloc, InventoryState>(
            builder: (context, state) {
              if (state is ProductDetailLoaded) {
                return Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: AppColors.primaryBlue),
                      tooltip: 'Редактировать',
                      onPressed: () => _showEditDialog(state.product),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.error),
                      tooltip: 'Удалить',
                      onPressed: () => _confirmDelete(state.product),
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: BlocConsumer<InventoryBloc, InventoryState>(
          listener: (context, state) {
            if (state is InventoryActionSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message), backgroundColor: AppColors.success),
              );
            }
          },
          builder: (context, state) {
            if (state is InventoryLoading) {
              return const LoadingShimmer();
            }
            if (state is ProductDetailLoaded) {
              return _buildContent(state.product, state.movements);
            }
            if (state is InventoryError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(state.message, style: AppTextStyles.bodyMedium),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => context.read<InventoryBloc>().add(LoadProductDetailEvent(widget.productId)),
                      child: const Text('Повторить'),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildContent(ProductModel product, List<StockMovementModel> movements) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Product Info Card
        GlassCard(
          padding: const EdgeInsets.all(16),
          borderRadius: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.inventory_2_outlined, color: AppColors.primaryBlue, size: 30),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(product.name, style: AppTextStyles.titleMedium),
                        const SizedBox(height: 4),
                        Text('Артикул: ${product.sku}', style: AppTextStyles.caption),
                        if (product.categoryName != null) ...[
                          const SizedBox(height: 2),
                          Text('Категория: ${product.categoryName}', style: AppTextStyles.caption),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Цена продажи', style: AppTextStyles.caption),
                      Text(Formatters.formatUzs(product.sellingPrice), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Цена закупки', style: AppTextStyles.caption),
                      Text(Formatters.formatUzs(product.purchasePrice), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Текущий остаток', style: AppTextStyles.caption),
                      Text(
                        '${product.currentStock.toStringAsFixed(0)} ${product.unit}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: product.isLowStock ? AppColors.error : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Мин. остаток', style: AppTextStyles.caption),
                      Text('${product.minStockLevel.toStringAsFixed(0)} ${product.unit}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Quick Action Button
        ElevatedButton.icon(
          onPressed: () => context.push('/inventory/adjust', extra: product),
          icon: const Icon(Icons.tune),
          label: const Text('Скорректировать остаток на складе'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        const SizedBox(height: 20),

        // Movements History
        Text('Движение товара на складе (${movements.length})', style: AppTextStyles.titleMedium),
        const SizedBox(height: 8),

        if (movements.isEmpty)
          GlassCard(
            padding: const EdgeInsets.all(24),
            borderRadius: 14,
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.history, color: AppColors.textTertiary, size: 36),
                  const SizedBox(height: 8),
                  Text('Движений по данному товару пока нет', style: AppTextStyles.caption),
                ],
              ),
            ),
          )
        else
          ...movements.map((m) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  padding: const EdgeInsets.all(12),
                  borderRadius: 14,
                  child: Row(
                    children: [
                      Icon(
                        m.type == 'in' ? Icons.add_circle_outline : Icons.remove_circle_outline,
                        color: m.type == 'in' ? AppColors.success : AppColors.error,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.type == 'in' ? 'Поступление' : 'Списание / Продажа',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            if (m.notes != null) Text(m.notes!, style: AppTextStyles.caption),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${m.type == 'in' ? '+' : '-'}${m.quantity.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: m.type == 'in' ? AppColors.success : AppColors.error,
                            ),
                          ),
                          Text(Formatters.formatDate(m.createdAt), style: AppTextStyles.caption),
                        ],
                      ),
                    ],
                  ),
                ),
              )),
      ],
    );
  }
}
