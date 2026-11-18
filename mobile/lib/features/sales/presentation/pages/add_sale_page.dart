import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../customers/presentation/bloc/customers_bloc.dart';
import '../../../inventory/data/models/product_model.dart';
import '../../../inventory/presentation/bloc/inventory_bloc.dart';
import '../../../inventory/presentation/widgets/product_picker_sheet.dart';
import '../../data/repositories/sales_repository.dart';
import '../bloc/sales_bloc.dart';
import '../widgets/customer_picker_sheet.dart';

class _CartItem {
  final ProductModel product;
  final double quantity;
  final double price;

  const _CartItem({required this.product, required this.quantity, required this.price});

  double get total => (quantity * price * 100).round() / 100;
}

class AddSalePage extends StatefulWidget {
  const AddSalePage({super.key});

  @override
  State<AddSalePage> createState() => _AddSalePageState();
}

class _AddSalePageState extends State<AddSalePage> {
  // Customer: an existing record (id) or the name of a new one.
  String? _customerId;
  String? _customerName;

  final List<_CartItem> _cartItems = [];

  // New item inputs
  ProductModel? _selectedProduct;
  final _qtyController = TextEditingController(text: '1');
  final _priceController = TextEditingController();

  final _discountController = TextEditingController();
  String _paymentMethod = 'cash';
  bool _isPartialPayment = false;
  final _paidAmountController = TextEditingController();
  bool _saving = false;

  final List<String> _methods = ['cash', 'bank', 'card'];
  final List<String> _methodLabels = ['Наличные', 'Банк', 'Карта'];

  @override
  void dispose() {
    _qtyController.dispose();
    _priceController.dispose();
    _discountController.dispose();
    _paidAmountController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  Future<void> _pickCustomer() async {
    final result = await showCustomerPicker(context);
    if (result == null || !mounted) return;
    setState(() {
      _customerId = result.item?.id;
      _customerName = result.item?.name ?? result.newName;
    });
  }

  Future<void> _pickProduct() async {
    final product = await showProductPicker(context);
    if (product == null || !mounted) return;
    setState(() {
      _selectedProduct = product;
      _qtyController.text = '1';
      _priceController.text = formatQty(product.sellingPrice);
    });
  }

  double _inCart(String productId) {
    return _cartItems.where((it) => it.product.id == productId).fold(0.0, (sum, it) => sum + it.quantity);
  }

  void _addItemToCart() {
    final product = _selectedProduct;
    if (product == null) {
      _showError('Выберите товар');
      return;
    }
    final qty = parseAmount(_qtyController.text);
    final price = parseAmount(_priceController.text);
    if (qty == null || qty <= 0) {
      _showError('Укажите количество больше 0');
      return;
    }
    if (price == null || price < 0) {
      _showError('Укажите цену товара');
      return;
    }
    final alreadyInCart = _inCart(product.id);
    if (qty + alreadyInCart > product.currentStock) {
      final left = product.currentStock - alreadyInCart;
      _showError(
        'Недостаточно товара «${product.name}» на складе: доступно ${formatQty(left > 0 ? left : 0)} ${product.unit}',
      );
      return;
    }

    setState(() {
      final sameIndex = _cartItems.indexWhere((it) => it.product.id == product.id && it.price == price);
      if (sameIndex >= 0) {
        final existing = _cartItems[sameIndex];
        _cartItems[sameIndex] = _CartItem(product: product, quantity: existing.quantity + qty, price: price);
      } else {
        _cartItems.add(_CartItem(product: product, quantity: qty, price: price));
      }
      _selectedProduct = null;
      _qtyController.text = '1';
      _priceController.clear();
    });
  }

  double get _subtotal => _cartItems.fold(0.0, (sum, it) => sum + it.total);

  double get _discount {
    final value = parseAmount(_discountController.text) ?? 0;
    if (value <= 0) return 0;
    return value > _subtotal ? _subtotal : value;
  }

  double get _cartTotal => ((_subtotal - _discount) * 100).round() / 100;

  Future<void> _saveSale() async {
    if (_saving) return;
    if (_cartItems.isEmpty) {
      _showError('Добавьте товары в чек');
      return;
    }
    final discountText = _discountController.text.trim();
    final typedDiscount = parseAmount(discountText);
    if (discountText.isNotEmpty && (typedDiscount == null || typedDiscount < 0)) {
      _showError('Укажите корректную скидку');
      return;
    }
    if ((typedDiscount ?? 0) > _subtotal) {
      _showError('Скидка больше суммы товаров');
      return;
    }

    final total = _cartTotal;
    double paid = total;
    if (_isPartialPayment) {
      final typedPaid = parseAmount(_paidAmountController.text);
      if (_paidAmountController.text.trim().isNotEmpty && (typedPaid == null || typedPaid < 0)) {
        _showError('Укажите корректную внесённую сумму');
        return;
      }
      paid = typedPaid ?? 0;
      if (paid > total) {
        _showError('Оплаченная сумма больше суммы продажи');
        return;
      }
    }
    if (paid < total && _customerName == null) {
      _showError('Для продажи в долг укажите клиента');
      return;
    }

    final data = <String, dynamic>{
      if (_customerId != null) 'customerId': _customerId else if (_customerName != null) 'customerName': _customerName,
      'items': _cartItems
          .map((it) => {'productId': it.product.id, 'quantity': it.quantity, 'price': it.price})
          .toList(),
      'paidAmount': paid,
      'paymentMethod': _paymentMethod,
      if (_discount > 0) 'discount': _discount,
    };

    setState(() => _saving = true);
    try {
      await getIt<SalesRepository>().createSale(data);
      if (!mounted) return;
      context.read<SalesBloc>().add(const RefreshSalesEvent());
      // The sale took goods from the warehouse: the product list must not keep old quantities.
      context.read<InventoryBloc>().add(const RefreshProductsEvent());
      // A new customer may have been created and a debt recorded.
      context.read<CustomersBloc>().add(const LoadCustomersEvent());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Продажа успешно оформлена'), backgroundColor: AppColors.success),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showError(apiErrorMessage(e, fallback: 'Не удалось сохранить продажу'));
    }
  }

  InputDecoration _fieldDecoration({String? label, String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: AppColors.cardBackground,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _pickerField({
    required IconData icon,
    required String placeholder,
    required VoidCallback onTap,
    String? title,
    String? subtitle,
    VoidCallback? onClear,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _saving ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primaryBlue),
            const SizedBox(width: 12),
            Expanded(
              child: title == null
                  ? Text(placeholder, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textTertiary))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(subtitle, style: AppTextStyles.caption),
                        ],
                      ],
                    ),
            ),
            if (title != null && onClear != null)
              GestureDetector(
                onTap: _saving ? null : onClear,
                child: Icon(Icons.close, size: 18, color: AppColors.textSecondary),
              )
            else
              Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = _selectedProduct;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Новая продажа'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
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
                  Text('Клиент', style: AppTextStyles.labelMedium),
                  const SizedBox(height: 8),
                  _pickerField(
                    icon: Icons.person,
                    placeholder: 'Выберите или введите клиента',
                    title: _customerName,
                    subtitle: _customerName != null && _customerId == null ? 'Новый клиент' : null,
                    onTap: _pickCustomer,
                    onClear: () => setState(() {
                      _customerId = null;
                      _customerName = null;
                    }),
                  ),
                  const SizedBox(height: 6),
                  Text('Обязателен для продажи в долг', style: AppTextStyles.caption),
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
                  _pickerField(
                    icon: Icons.search,
                    placeholder: 'Выберите товар со склада',
                    title: product?.name,
                    subtitle: product == null
                        ? null
                        : 'Доступно: ${formatQty(product.currentStock - _inCart(product.id))} ${product.unit}  •  ${Formatters.formatUzs(product.sellingPrice)}',
                    onTap: _pickProduct,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _qtyController,
                          enabled: !_saving,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: _fieldDecoration(label: 'Кол-во'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _priceController,
                          enabled: !_saving,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: _fieldDecoration(label: 'Цена'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _saving ? null : _addItemToCart,
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
                                Text(it.product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                Text(
                                  '${formatQty(it.quantity)} ${it.product.unit} × ${Formatters.formatUzs(it.price)}',
                                  style: AppTextStyles.caption,
                                ),
                              ],
                            ),
                          ),
                          Text(Formatters.formatUzs(it.total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                            onPressed: _saving ? null : () => setState(() => _cartItems.remove(it)),
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
                          onTap: _saving ? null : () => setState(() => _paymentMethod = _methods[idx]),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primaryBlue : AppColors.cardBackground,
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
                  TextField(
                    controller: _discountController,
                    enabled: !_saving,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: _fieldDecoration(label: 'Скидка на чек'),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Частичная оплата / Долг', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    value: _isPartialPayment,
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.primaryBlue,
                    onChanged: _saving ? null : (v) => setState(() => _isPartialPayment = v),
                  ),
                  if (_isPartialPayment) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _paidAmountController,
                      enabled: !_saving,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: _fieldDecoration(label: 'Внесённая сумма', hint: '0'),
                    ),
                  ],
                  const Divider(height: 24),
                  if (_discount > 0) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Сумма товаров:', style: AppTextStyles.caption),
                        Text(Formatters.formatUzs(_subtotal), style: AppTextStyles.caption),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Скидка:', style: AppTextStyles.caption),
                        Text('-${Formatters.formatUzs(_discount)}', style: AppTextStyles.caption),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
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
              isLoading: _saving,
              onPressed: _saveSale,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
