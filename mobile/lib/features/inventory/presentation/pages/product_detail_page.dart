import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../bloc/inventory_bloc.dart';
import '../../data/models/product_model.dart';
import '../../data/repositories/inventory_repository.dart';
import 'add_product_page.dart';
import 'stock_adjustment_page.dart';

class ProductDetailPage extends StatefulWidget {
  final String productId;

  const ProductDetailPage({super.key, required this.productId});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  final InventoryRepository _repository = getIt<InventoryRepository>();

  ProductModel? _product;
  List<StockMovementModel> _movements = const [];
  bool _loading = true;
  bool _deleting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Loads the product and its movement history. With [silent] the content
  /// already on screen stays visible; returns an error text or null.
  Future<String?> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final productFuture = _repository.getProductById(widget.productId);
      final movementsFuture = _repository.getStockMovements(widget.productId);
      final product = await productFuture;
      final movements = await movementsFuture;
      if (!mounted) return null;
      setState(() {
        _product = product;
        _movements = movements;
        _loading = false;
        _error = null;
      });
      return null;
    } catch (e) {
      final message = apiErrorMessage(e, fallback: 'Не удалось загрузить данные товара');
      if (!mounted) return message;
      setState(() {
        _loading = false;
        if (_product == null) _error = message;
      });
      return message;
    }
  }

  Future<void> _refresh() async {
    final error = await _load(silent: true);
    if (error != null && mounted) _showMessage(error, isError: true);
  }

  void _showMessage(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: isError ? AppColors.error : AppColors.success),
    );
  }

  Future<void> _openEdit(ProductModel product) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AddProductPage(product: product)),
    );
    if (saved == true && mounted) await _refresh();
  }

  Future<void> _openAdjust(ProductModel product) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => StockAdjustmentPage(product: product)),
    );
    if (saved == true && mounted) await _refresh();
  }

  Future<void> _confirmDelete(ProductModel product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить товар?'),
        content: Text('Вы уверены, что хотите удалить товар "${product.name}"? Это действие нельзя отменить.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await _repository.deleteProduct(product.id);
      if (!mounted) return;
      context.read<InventoryBloc>().add(const RefreshProductsEvent());
      _showMessage('Товар удалён');
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      _showMessage(apiErrorMessage(e, fallback: 'Не удалось удалить товар'), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = _product;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Карточка товара'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (product != null && _deleting)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            )
          else if (product != null) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: AppColors.primaryBlue),
              tooltip: 'Редактировать',
              onPressed: () => _openEdit(product),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              tooltip: 'Удалить',
              onPressed: () => _confirmDelete(product),
            ),
          ],
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
        child: _buildBody(product),
      ),
    );
  }

  Widget _buildBody(ProductModel? product) {
    if (product != null) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: _buildContent(product, _movements),
      );
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
              _error ?? 'Не удалось загрузить данные товара',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _load,
            child: const Text('Повторить'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ProductModel product, List<StockMovementModel> movements) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
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
                        if (product.barcode != null) ...[
                          const SizedBox(height: 2),
                          Text('Штрихкод: ${product.barcode}', style: AppTextStyles.caption),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (product.description != null) ...[
                const SizedBox(height: 12),
                Text(product.description!, style: AppTextStyles.bodyMedium),
              ],
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
                        '${formatQty(product.currentStock)} ${product.unit}',
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
                      Text('${formatQty(product.minStockLevel)} ${product.unit}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
          onPressed: _deleting ? null : () => _openAdjust(product),
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
          ...movements.map((m) => _buildMovementRow(m, product.unit)),
      ],
    );
  }

  Widget _buildMovementRow(StockMovementModel m, String unit) {
    final String label;
    if (m.isIncoming) {
      label = 'Поступление';
    } else if (m.isOutgoing) {
      label = 'Списание / Продажа';
    } else {
      label = 'Инвентаризация';
    }

    final delta = m.delta;
    final Color color;
    final IconData icon;
    final String amount;
    if (delta == null) {
      color = AppColors.primaryBlue;
      icon = Icons.sync_alt;
      amount = formatQty(m.quantity);
    } else if (delta >= 0) {
      color = AppColors.success;
      icon = Icons.add_circle_outline;
      amount = '+${formatQty(delta)}';
    } else {
      color = AppColors.error;
      icon = Icons.remove_circle_outline;
      amount = '-${formatQty(delta.abs())}';
    }

    final meta = [
      if (m.createdAt != null) Formatters.formatDateTime(m.createdAt!.toLocal()),
      if (m.createdByName != null) m.createdByName!,
    ].join('  •  ');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        borderRadius: 14,
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (m.reason != null) Text(m.reason!, style: AppTextStyles.caption),
                  if (meta.isNotEmpty) Text(meta, style: AppTextStyles.caption),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(amount, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                Text('Остаток: ${formatQty(m.balanceAfter)} $unit', style: AppTextStyles.caption),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
