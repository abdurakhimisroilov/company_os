import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/glass_card.dart';
import '../bloc/inventory_bloc.dart';
import '../../data/models/product_model.dart';

class StockAdjustmentPage extends StatefulWidget {
  final String? initialProductId;

  const StockAdjustmentPage({super.key, this.initialProductId});

  @override
  State<StockAdjustmentPage> createState() => _StockAdjustmentPageState();
}

class _StockAdjustmentPageState extends State<StockAdjustmentPage> {
  final _formKey = GlobalKey<FormState>();
  final _qtyController = TextEditingController();
  final _reasonController = TextEditingController();

  String _adjustmentType = 'adjustment'; // 'in', 'out', 'adjustment'
  String? _selectedProductId;

  @override
  void initState() {
    super.initState();
    _selectedProductId = widget.initialProductId;
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _submitAdjustment() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProductId == null || _selectedProductId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите товар'), backgroundColor: AppColors.error),
      );
      return;
    }

    final qty = double.tryParse(_qtyController.text) ?? 0.0;
    final data = {
      'productId': _selectedProductId,
      'type': _adjustmentType,
      'quantity': qty,
      'notes': _reasonController.text.trim(),
    };

    context.read<InventoryBloc>().add(AdjustStockEvent(data));
    context.pop();
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
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
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
                      BlocBuilder<InventoryBloc, InventoryState>(
                        builder: (context, state) {
                          List<ProductModel> products = [];
                          if (state is InventoryLoaded) {
                            products = state.products;
                          }
                          if (products.isEmpty) {
                            return TextFormField(
                              initialValue: _selectedProductId,
                              decoration: InputDecoration(
                                hintText: 'ID или артикул товара',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onChanged: (v) => _selectedProductId = v,
                              validator: (v) => (v == null || v.isEmpty) ? 'Укажите товар' : null,
                            );
                          }
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.cardBorder),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedProductId ?? (products.isNotEmpty ? products.first.id : null),
                                isExpanded: true,
                                items: products.map((p) {
                                  return DropdownMenuItem(
                                    value: p.id,
                                    child: Text('${p.name} (Остаток: ${p.currentStock.toStringAsFixed(0)})'),
                                  );
                                }).toList(),
                                onChanged: (v) => setState(() => _selectedProductId = v),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),

                      Text('Тип операции', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildTypeRadio('in', 'Оприходование', AppColors.success),
                          const SizedBox(width: 8),
                          _buildTypeRadio('out', 'Списание', AppColors.error),
                          const SizedBox(width: 8),
                          _buildTypeRadio('adjustment', 'Коррекция', AppColors.primaryBlue),
                        ],
                      ),
                      const SizedBox(height: 20),

                      Text('Количество', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _qtyController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          hintText: '0',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? 'Укажите количество' : null,
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
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? 'Укажите причину' : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                AppButton(
                  label: 'Применить корректировку',
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
        onTap: () => setState(() => _adjustmentType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.15) : Colors.white,
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
