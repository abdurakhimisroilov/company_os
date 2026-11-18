import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../inventory/data/models/product_model.dart';
import '../../../inventory/presentation/bloc/inventory_bloc.dart';
import '../../../inventory/presentation/widgets/product_picker_sheet.dart';
import '../../../suppliers/presentation/bloc/suppliers_bloc.dart';
import '../../data/repositories/shipments_repository.dart';
import '../bloc/shipments_bloc.dart';
import '../widgets/supplier_picker_sheet.dart';

class _ShipmentLine {
  final ProductModel product;
  final double quantity;
  final double unitPrice;

  const _ShipmentLine({required this.product, required this.quantity, required this.unitPrice});

  double get total => (quantity * unitPrice * 100).round() / 100;
}

class AddShipmentPage extends StatefulWidget {
  const AddShipmentPage({super.key});

  @override
  State<AddShipmentPage> createState() => _AddShipmentPageState();
}

class _AddShipmentPageState extends State<AddShipmentPage> {
  int _currentStep = 0;
  bool _saving = false;

  // Step 1: Info. Supplier is an existing record (id) or the name of a new one.
  String? _supplierId;
  String? _supplierName;
  final _invoiceController = TextEditingController();
  DateTime _expectedDate = DateTime.now().add(const Duration(days: 3));

  /// True: the goods are already here and go to stock on save.
  /// False: the shipment is saved as expected and received later from its card.
  bool _receiveNow = false;

  // Step 2: Items
  final List<_ShipmentLine> _items = [];
  ProductModel? _selectedProduct;
  final _qtyController = TextEditingController();
  final _priceController = TextEditingController();

  // Step 3: Costs
  final _transportCostController = TextEditingController();
  final _customsCostController = TextEditingController();

  @override
  void dispose() {
    _invoiceController.dispose();
    _qtyController.dispose();
    _priceController.dispose();
    _transportCostController.dispose();
    _customsCostController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  Future<void> _pickSupplier() async {
    final result = await showSupplierPicker(context);
    if (result == null || !mounted) return;
    setState(() {
      _supplierId = result.item?.id;
      _supplierName = result.item?.name ?? result.newName;
    });
  }

  Future<void> _pickProduct() async {
    final product = await showProductPicker(context, showSellingPrice: false);
    if (product == null || !mounted) return;
    setState(() {
      _selectedProduct = product;
      _priceController.text = formatQty(product.purchasePrice);
    });
  }

  void _addItem() {
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
      _showError('Укажите цену за единицу');
      return;
    }

    setState(() {
      final sameIndex = _items.indexWhere((it) => it.product.id == product.id && it.unitPrice == price);
      if (sameIndex >= 0) {
        final existing = _items[sameIndex];
        _items[sameIndex] = _ShipmentLine(product: product, quantity: existing.quantity + qty, unitPrice: price);
      } else {
        _items.add(_ShipmentLine(product: product, quantity: qty, unitPrice: price));
      }
      _selectedProduct = null;
      _qtyController.clear();
      _priceController.clear();
    });
  }

  double get _itemsTotal => _items.fold(0.0, (sum, it) => sum + it.total);
  double get _transportCost => parseAmount(_transportCostController.text) ?? 0.0;
  double get _customsCost => parseAmount(_customsCostController.text) ?? 0.0;
  double get _grandTotal => _itemsTotal + _transportCost + _customsCost;

  bool _costIsValid(TextEditingController controller) {
    final text = controller.text.trim();
    if (text.isEmpty) return true;
    final value = parseAmount(text);
    return value != null && value >= 0;
  }

  /// Checks the step the user is leaving; false keeps them on it.
  bool _validateStep(int step) {
    if (step == 0 && _supplierName == null) {
      _showError('Выберите поставщика');
      return false;
    }
    if (step == 1 && _items.isEmpty) {
      _showError('Добавьте хотя бы один товар');
      return false;
    }
    if (step == 2 && (!_costIsValid(_transportCostController) || !_costIsValid(_customsCostController))) {
      _showError('Укажите корректную сумму расходов');
      return false;
    }
    return true;
  }

  Future<void> _finishShipment() async {
    if (_saving) return;
    for (var step = 0; step < 3; step++) {
      if (!_validateStep(step)) {
        setState(() => _currentStep = step);
        return;
      }
    }

    final invoice = _invoiceController.text.trim();
    final additionalCosts = _transportCost + _customsCost;
    final data = <String, dynamic>{
      if (_supplierId != null) 'supplierId': _supplierId else 'supplierName': _supplierName,
      if (invoice.isNotEmpty) 'invoiceNumber': invoice,
      'items': _items
          .map((it) => {'productId': it.product.id, 'quantity': it.quantity, 'unitPrice': it.unitPrice})
          .toList(),
      if (additionalCosts > 0) 'additionalCosts': additionalCosts,
      if (!_receiveNow) ...{
        'status': 'pending',
        'expectedDate': DateFormat('yyyy-MM-dd').format(_expectedDate),
      },
    };

    setState(() => _saving = true);
    try {
      await getIt<ShipmentsRepository>().createShipment(data);
      if (!mounted) return;
      context.read<ShipmentsBloc>().add(const RefreshShipmentsEvent());
      // A new supplier may have been created; received goods change stock and the supplier's balance.
      context.read<SuppliersBloc>().add(const LoadSuppliersEvent());
      if (_receiveNow) context.read<InventoryBloc>().add(const RefreshProductsEvent());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_receiveNow ? 'Поставка принята на склад' : 'Поставка успешно создана'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showError(apiErrorMessage(e, fallback: 'Не удалось создать поставку'));
    }
  }

  Widget _pickerField({
    required String placeholder,
    required VoidCallback onTap,
    String? title,
    String? subtitle,
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
            Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
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
        title: const Text('Новая поставка'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Theme(
          data: Theme.of(context).copyWith(
            colorScheme: AppColors.isDark
                ? Theme.of(context).colorScheme.copyWith(primary: AppColors.primaryBlue)
                : const ColorScheme.light(primary: AppColors.primaryBlue),
          ),
          child: Stepper(
            currentStep: _currentStep,
            type: StepperType.horizontal,
            onStepTapped: _saving
                ? null
                : (step) {
                    // Going forward must not skip the checks of the steps in between.
                    for (var i = _currentStep; i < step; i++) {
                      if (!_validateStep(i)) return;
                    }
                    setState(() => _currentStep = step);
                  },
            onStepContinue: () {
              if (_saving) return;
              if (_currentStep < 3) {
                if (!_validateStep(_currentStep)) return;
                setState(() => _currentStep += 1);
              } else {
                _finishShipment();
              }
            },
            onStepCancel: () {
              if (_saving) return;
              if (_currentStep > 0) {
                setState(() => _currentStep -= 1);
              } else {
                Navigator.of(context).pop();
              }
            },
            controlsBuilder: (context, details) {
              return Padding(
                padding: const EdgeInsets.only(top: 20.0),
                child: Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: _currentStep == 3 ? 'Подтвердить поставку' : 'Далее',
                        isLoading: _saving,
                        onPressed: details.onStepContinue,
                      ),
                    ),
                    if (_currentStep > 0) ...[
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: _saving ? null : details.onStepCancel,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Назад'),
                      ),
                    ],
                  ],
                ),
              );
            },
            steps: [
              Step(
                title: const Text('Поставщик'),
                isActive: _currentStep >= 0,
                content: _buildStep1(),
              ),
              Step(
                title: const Text('Товары'),
                isActive: _currentStep >= 1,
                content: _buildStep2(),
              ),
              Step(
                title: const Text('Расходы'),
                isActive: _currentStep >= 2,
                content: _buildStep3(),
              ),
              Step(
                title: const Text('Итог'),
                isActive: _currentStep >= 3,
                content: _buildStep4(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Поставщик *', style: AppTextStyles.labelMedium),
          const SizedBox(height: 6),
          _pickerField(
            placeholder: 'Выберите или введите поставщика',
            title: _supplierName,
            subtitle: _supplierName != null && _supplierId == null ? 'Новый поставщик' : null,
            onTap: _pickSupplier,
          ),
          const SizedBox(height: 14),
          Text('Номер накладной / инвойса', style: AppTextStyles.labelMedium),
          const SizedBox(height: 6),
          TextField(
            controller: _invoiceController,
            decoration: _inputDeco('Если не указать, номер присвоится автоматически'),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Товар уже получен', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: Text(
              _receiveNow
                  ? 'Товары сразу будут оприходованы на склад'
                  : 'Поставка сохранится как ожидаемая, приёмка — из её карточки',
              style: AppTextStyles.caption,
            ),
            value: _receiveNow,
            contentPadding: EdgeInsets.zero,
            activeThumbColor: AppColors.primaryBlue,
            onChanged: _saving ? null : (v) => setState(() => _receiveNow = v),
          ),
          if (!_receiveNow) ...[
          const SizedBox(height: 8),
          Text('Ожидаемая дата прибытия', style: AppTextStyles.labelMedium),
          const SizedBox(height: 6),
          InkWell(
            onTap: _saving
                ? null
                : () async {
              final today = DateTime.now();
              final d = await showDatePicker(
                context: context,
                initialDate: _expectedDate,
                firstDate: DateTime(today.year, today.month, today.day),
                lastDate: DateTime(today.year + 5, 12, 31),
              );
              if (d != null && mounted) setState(() => _expectedDate = d);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(Formatters.formatDate(_expectedDate)),
                  const Icon(Icons.calendar_today, size: 18, color: AppColors.primaryBlue),
                ],
              ),
            ),
          ),
          ],
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return Column(
      children: [
        GlassCard(
          padding: const EdgeInsets.all(16),
          borderRadius: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Добавить товар в накладную', style: AppTextStyles.titleMedium),
              const SizedBox(height: 10),
              _pickerField(
                placeholder: 'Выберите товар',
                title: _selectedProduct?.name,
                subtitle: _selectedProduct == null
                    ? null
                    : 'Арт: ${_selectedProduct!.sku}  •  Остаток: ${formatQty(_selectedProduct!.currentStock)} ${_selectedProduct!.unit}',
                onTap: _pickProduct,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _qtyController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: _inputDeco('Кол-во'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: _inputDeco('Цена за ед.'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _saving ? null : _addItem,
                icon: const Icon(Icons.add),
                label: const Text('Добавить позицию'),
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
        const SizedBox(height: 14),
        ..._items.map((it) => Container(
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
                          Text('${formatQty(it.quantity)} ${it.product.unit} × ${Formatters.formatUzs(it.unitPrice)}', style: AppTextStyles.caption),
                        ],
                      ),
                    ),
                    Text(Formatters.formatUzs(it.total), style: const TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                      onPressed: _saving ? null : () => setState(() => _items.remove(it)),
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildStep3() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Дополнительные накладные расходы', style: AppTextStyles.titleMedium),
          const SizedBox(height: 14),
          Text('Транспортные расходы / Доставка', style: AppTextStyles.labelMedium),
          const SizedBox(height: 6),
          TextField(
            controller: _transportCostController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _inputDeco('0 сум'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          Text('Таможенные пошлины и сборы', style: AppTextStyles.labelMedium),
          const SizedBox(height: 6),
          TextField(
            controller: _customsCostController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _inputDeco('0 сум'),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  Widget _buildStep4() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Сводка поставки', style: AppTextStyles.titleMedium),
          const Divider(height: 20),
          _summaryRow('Поставщик:', _supplierName ?? 'Не указан'),
          _summaryRow('Инвойс:', _invoiceController.text.trim().isNotEmpty ? _invoiceController.text.trim() : 'Автоматически'),
          if (_receiveNow)
            _summaryRow('Приёмка:', 'Сразу на склад')
          else
            _summaryRow('Дата прибытия:', Formatters.formatDate(_expectedDate)),
          _summaryRow('Позиций:', '${_items.length}'),
          _summaryRow('Сумма товаров:', Formatters.formatUzs(_itemsTotal)),
          _summaryRow('Доп. расходы:', Formatters.formatUzs(_transportCost + _customsCost)),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('ИТОГО:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(
                Formatters.formatUzs(_grandTotal),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primaryBlue),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(width: 12),
          Flexible(
            child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: AppColors.cardBackground,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.cardBorder)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}
