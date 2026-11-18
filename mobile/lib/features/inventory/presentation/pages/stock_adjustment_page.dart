import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/glass_card.dart';
import '../bloc/inventory_bloc.dart';
import '../../data/models/product_model.dart';
import '../../data/repositories/inventory_repository.dart';
import '../widgets/product_picker_sheet.dart';

/// Manual stock change. Opened for a fixed [product] from its card,
/// or without one from the list, where the user picks the product first.
class StockAdjustmentPage extends StatefulWidget {
  final ProductModel? product;

  const StockAdjustmentPage({super.key, this.product});

  @override
  State<StockAdjustmentPage> createState() => _StockAdjustmentPageState();
}

class _StockAdjustmentPageState extends State<StockAdjustmentPage> {
  final _formKey = GlobalKey<FormState>();
  final _qtyController = TextEditingController();
  final _reasonController = TextEditingController();

  String _adjustmentType = 'in'; // 'in', 'out', 'set'
  ProductModel? _product;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _product = widget.product;
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickProduct() async {
    final picked = await showProductPicker(context);
    if (picked != null && mounted) setState(() => _product = picked);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  String? _validateQuantity(String? v) {
    final qty = parseAmount(v ?? '');
    if (qty == null) return 'Укажите количество';
    if (qty < 0) return 'Не может быть меньше 0';
    if (_adjustmentType != 'set' && qty == 0) return 'Количество должно быть больше 0';
    return null;
  }

  Future<void> _submitAdjustment() async {
    if (_saving) return;
    final product = _product;
    if (product == null) {
      _showError('Выберите товар');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final updated = await getIt<InventoryRepository>().adjustStock(
        productId: product.id,
        type: _adjustmentType,
        quantity: parseAmount(_qtyController.text) ?? 0,
        notes: _reasonController.text,
      );
      if (!mounted) return;
      context.read<InventoryBloc>().add(const RefreshProductsEvent());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Остаток обновлён: ${formatQty(updated.currentStock)} ${updated.unit}'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showError(apiErrorMessage(e, fallback: 'Не удалось выполнить корректировку остатка'));
    }
  }

  Widget _buildProductField() {
    final product = _product;
    final fixed = widget.product != null;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: fixed || _saving ? null : _pickProduct,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: product == null
                  ? Text('Выберите товар', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textTertiary))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Арт: ${product.sku}  •  Остаток: ${formatQty(product.currentStock)} ${product.unit}',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
            ),
            if (!fixed) Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Корректировка остатков'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  borderRadius: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Товар для корректировки', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 8),
                      _buildProductField(),
                      const SizedBox(height: 20),

                      Text('Тип операции', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildTypeRadio('in', 'Оприходование', AppColors.success),
                          const SizedBox(width: 8),
                          _buildTypeRadio('out', 'Списание', AppColors.error),
                          const SizedBox(width: 8),
                          _buildTypeRadio('set', 'Коррекция', AppColors.primaryBlue),
                        ],
                      ),
                      const SizedBox(height: 20),

                      Text(
                        _adjustmentType == 'set' ? 'Фактический остаток на складе' : 'Количество',
                        style: AppTextStyles.labelMedium,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _qtyController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          hintText: '0',
                          filled: true,
                          fillColor: AppColors.cardBackground,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        validator: _validateQuantity,
                      ),
                      const SizedBox(height: 20),

                      Text('Причина / Основание', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _reasonController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Инвентаризация, брак, пересчёт...',
                          filled: true,
                          fillColor: AppColors.cardBackground,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Укажите причину' : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                AppButton(
                  label: 'Применить корректировку',
                  isLoading: _saving,
                  onPressed: _submitAdjustment,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeRadio(String type, String label, Color color) {
    final isSelected = _adjustmentType == type;
    return Expanded(
      child: GestureDetector(
        onTap: _saving ? null : () => setState(() => _adjustmentType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.15) : AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? color : AppColors.cardBorder, width: isSelected ? 2 : 1),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
