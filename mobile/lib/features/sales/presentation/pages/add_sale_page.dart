import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/glass_card.dart';
import '../bloc/sales_bloc.dart';
import '../../data/models/sale_model.dart';

class AddSalePage extends StatefulWidget {
  const AddSalePage({super.key});

  @override
  State<AddSalePage> createState() => _AddSalePageState();
}

class _AddSalePageState extends State<AddSalePage> {
  final _customerController = TextEditingController();
  final List<SaleItemModel> _cartItems = [];

  // New item inputs
  final _productNameController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  final _priceController = TextEditingController();
  final _discountController = TextEditingController(text: '0');

  String _paymentMethod = 'cash';
  bool _isPartialPayment = false;
  final _paidAmountController = TextEditingController();

  final List<String> _methods = ['cash', 'bank', 'card'];
  final List<String> _methodLabels = ['Наличные', 'Банк', 'Карта'];

  @override
  void dispose() {
    _customerController.dispose();
    _productNameController.dispose();
    _qtyController.dispose();
    _priceController.dispose();
    _discountController.dispose();
    _paidAmountController.dispose();
    super.dispose();
  }

  void _addItemToCart() {
    final name = _productNameController.text.trim();
    final qty = double.tryParse(_qtyController.text) ?? 1;
    final price = double.tryParse(_priceController.text.replaceAll(' ', '')) ?? 0;
    final discount = double.tryParse(_discountController.text.replaceAll(' ', '')) ?? 0;

    if (name.isEmpty || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите название и цену товара'), backgroundColor: AppColors.error),
      );
      return;
    }

    final total = (qty * price) - discount;

    setState(() {
      _cartItems.add(SaleItemModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        productId: 'prod_${_cartItems.length + 1}',
        productName: name,
        quantity: qty,
        price: price,
        discount: discount,
        total: total > 0 ? total : 0,
      ));
      _productNameController.clear();
      _qtyController.text = '1';
      _priceController.clear();
      _discountController.text = '0';
    });
  }

  double get _cartTotal => _cartItems.fold(0.0, (sum, it) => sum + it.total);

  void _saveSale() {
    if (_customerController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите клиента'), backgroundColor: AppColors.error),
      );
      return;
    }
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Добавьте товары в чек'), backgroundColor: AppColors.error),
      );
      return;
    }

    final total = _cartTotal;
    double paid = total;
    if (_isPartialPayment) {
      paid = double.tryParse(_paidAmountController.text.replaceAll(' ', '')) ?? 0;
    }

    String status = 'paid';
    if (paid <= 0) {
      status = 'unpaid';
    } else if (paid < total) {
      status = 'partial';
    }

    final data = {
      'customerName': _customerController.text.trim(),
      'date': DateTime.now().toIso8601String(),
      'items': _cartItems.map((it) => it.toJson()).toList(),
      'totalAmount': total,
      'paidAmount': paid,
      'paymentStatus': status,
      'paymentMethod': _paymentMethod,
    };

    context.read<SalesBloc>().add(CreateSaleEvent(data));
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Новая продажа'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Customer Section
            GlassCard(
              padding: const EdgeInsets.all(16),
              borderRadius: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Клиент *', style: AppTextStyles.labelMedium),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _customerController,
                    decoration: InputDecoration(
                      hintText: 'Выберите или введите клиента',
                      prefixIcon: const Icon(Icons.person, color: AppColors.primaryBlue),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.cardBorder)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Add Product to Cart Section
            GlassCard(
              padding: const EdgeInsets.all(16),
              borderRadius: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Добавить товар в чек', style: AppTextStyles.titleMedium),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _productNameController,
                    decoration: InputDecoration(
                      hintText: 'Название товара...',
                      prefixIcon: const Icon(Icons.search, color: AppColors.primaryBlue),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.cardBorder)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _qtyController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Кол-во',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _priceController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Цена',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _discountController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Скидка',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _addItemToCart,
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('Добавить в корзину'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Cart Items List
            if (_cartItems.isNotEmpty) ...[
              Text('Товары в чеке (${_cartItems.length})', style: AppTextStyles.titleMedium),
              const SizedBox(height: 8),
              ..._cartItems.map((it) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: GlassCard(
                      padding: const EdgeInsets.all(12),
                      borderRadius: 12,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(it.productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                Text(
                                  '${it.quantity.toStringAsFixed(0)} × ${Formatters.formatUzs(it.price)} ${it.discount > 0 ? "(-${Formatters.formatUzs(it.discount)})" : ""}',
                                  style: AppTextStyles.caption,
                                ),
                              ],
                            ),
                          ),
                          Text(Formatters.formatUzs(it.total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                            onPressed: () => setState(() => _cartItems.remove(it)),
                          ),
                        ],
                      ),
                    ),
                  )),
              const SizedBox(height: 16),
            ],

            // Payment Options
            GlassCard(
              padding: const EdgeInsets.all(16),
              borderRadius: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Способ оплаты', style: AppTextStyles.labelMedium),
                  const SizedBox(height: 10),
                  Row(
                    children: List.generate(_methods.length, (idx) {
                      final isSelected = _paymentMethod == _methods[idx];
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _paymentMethod = _methods[idx]),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primaryBlue : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isSelected ? AppColors.primaryBlue : AppColors.cardBorder),
                            ),
                            child: Center(
                              child: Text(
                                _methodLabels[idx],
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
                    }),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Частичная оплата / Долг', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    value: _isPartialPayment,
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.primaryBlue,
                    onChanged: (v) => setState(() => _isPartialPayment = v),
                  ),
                  if (_isPartialPayment) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _paidAmountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Внесённая сумма (UZS)',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Итого к оплате:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(
                        Formatters.formatUzs(_cartTotal),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.primaryBlue),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            AppButton(
              label: 'Оформить продажу',
              onPressed: _saveSale,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
