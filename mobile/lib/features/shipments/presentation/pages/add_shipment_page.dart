import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/glass_card.dart';
import '../bloc/shipments_bloc.dart';
import '../../data/models/shipment_model.dart';

class AddShipmentPage extends StatefulWidget {
  const AddShipmentPage({super.key});

  @override
  State<AddShipmentPage> createState() => _AddShipmentPageState();
}

class _AddShipmentPageState extends State<AddShipmentPage> {
  int _currentStep = 0;

  // Step 1: Info
  final _supplierController = TextEditingController();
  final _invoiceController = TextEditingController();
  final _employeeController = TextEditingController();
  DateTime _expectedDate = DateTime.now().add(const Duration(days: 3));

  // Step 2: Items
  final List<ShipmentItemModel> _items = [];
  final _productNameController = TextEditingController();
  final _qtyController = TextEditingController();
  final _priceController = TextEditingController();

  // Step 3: Costs
  final _transportCostController = TextEditingController(text: '0');
  final _customsCostController = TextEditingController(text: '0');

  @override
  void dispose() {
    _supplierController.dispose();
    _invoiceController.dispose();
    _employeeController.dispose();
    _productNameController.dispose();
    _qtyController.dispose();
    _priceController.dispose();
    _transportCostController.dispose();
    _customsCostController.dispose();
    super.dispose();
  }

  void _addItem() {
    final name = _productNameController.text.trim();
    final qty = double.tryParse(_qtyController.text) ?? 0;
    final price = double.tryParse(_priceController.text.replaceAll(' ', '')) ?? 0;

    if (name.isEmpty || qty <= 0 || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните название, количество и цену'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() {
      _items.add(ShipmentItemModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        productId: 'prod_${_items.length + 1}',
        productName: name,
        quantity: qty,
        unitPrice: price,
        totalPrice: qty * price,
      ));
      _productNameController.clear();
      _qtyController.clear();
      _priceController.clear();
    });
  }

  double get _itemsTotal => _items.fold(0.0, (sum, it) => sum + it.totalPrice);
  double get _transportCost => double.tryParse(_transportCostController.text.replaceAll(' ', '')) ?? 0.0;
  double get _customsCost => double.tryParse(_customsCostController.text.replaceAll(' ', '')) ?? 0.0;
  double get _grandTotal => _itemsTotal + _transportCost + _customsCost;

  void _finishShipment() {
    if (_supplierController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите поставщика в шаге 1'), backgroundColor: AppColors.error),
      );
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Добавьте хотя бы один товар в шаге 2'), backgroundColor: AppColors.error),
      );
      return;
    }

    final data = {
      'supplierName': _supplierController.text.trim(),
      'invoiceNumber': _invoiceController.text.trim(),
      'responsibleEmployee': _employeeController.text.trim(),
      'expectedDate': _expectedDate.toIso8601String(),
      'items': _items.map((it) => it.toJson()).toList(),
      'additionalCosts': _transportCost + _customsCost,
      'totalCost': _grandTotal,
      'status': 'pending',
    };

    context.read<ShipmentsBloc>().add(CreateShipmentEvent(data));
    context.pop();
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
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.primaryBlue),
          ),
          child: Stepper(
            currentStep: _currentStep,
            type: StepperType.horizontal,
            onStepContinue: () {
              if (_currentStep < 3) {
                setState(() => _currentStep += 1);
              } else {
                _finishShipment();
              }
            },
            onStepCancel: () {
              if (_currentStep > 0) {
                setState(() => _currentStep -= 1);
              } else {
                context.pop();
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
                        onPressed: details.onStepContinue,
                      ),
                    ),
                    if (_currentStep > 0) ...[
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: details.onStepCancel,
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
          TextField(
            controller: _supplierController,
            decoration: _inputDeco('ООО "ТоргСнаб"'),
          ),
          const SizedBox(height: 14),
          Text('Номер накладной / инвойса', style: AppTextStyles.labelMedium),
          const SizedBox(height: 6),
          TextField(
            controller: _invoiceController,
            decoration: _inputDeco('INV-2026-091'),
          ),
          const SizedBox(height: 14),
          Text('Ответственный сотрудник', style: AppTextStyles.labelMedium),
          const SizedBox(height: 6),
          TextField(
            controller: _employeeController,
            decoration: _inputDeco('ФИО кладовщика / менеджера'),
          ),
          const SizedBox(height: 14),
          Text('Ожидаемая дата прибытия', style: AppTextStyles.labelMedium),
          const SizedBox(height: 6),
          InkWell(
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _expectedDate,
                firstDate: DateTime.now(),
                lastDate: DateTime(2030),
              );
              if (d != null) setState(() => _expectedDate = d);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
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
              TextField(
                controller: _productNameController,
                decoration: _inputDeco('Название товара или артикул'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _qtyController,
                      keyboardType: TextInputType.number,
                      decoration: _inputDeco('Кол-во'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: _inputDeco('Цена за ед.'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _addItem,
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
                          Text(it.productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('${it.quantity.toStringAsFixed(0)} шт × ${Formatters.formatUzs(it.unitPrice)}', style: AppTextStyles.caption),
                        ],
                      ),
                    ),
                    Text(Formatters.formatUzs(it.totalPrice), style: const TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                      onPressed: () => setState(() => _items.remove(it)),
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
          Text('Транспортные расходы / Доставка (UZS)', style: AppTextStyles.labelMedium),
          const SizedBox(height: 6),
          TextField(
            controller: _transportCostController,
            keyboardType: TextInputType.number,
            decoration: _inputDeco('0 сум'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          Text('Таможенные пошлины и сборы (UZS)', style: AppTextStyles.labelMedium),
          const SizedBox(height: 6),
          TextField(
            controller: _customsCostController,
            keyboardType: TextInputType.number,
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
          _summaryRow('Поставщик:', _supplierController.text.isNotEmpty ? _supplierController.text : 'Не указан'),
          _summaryRow('Инвойс:', _invoiceController.text.isNotEmpty ? _invoiceController.text : 'б/н'),
          _summaryRow('Дата прибытия:', Formatters.formatDate(_expectedDate)),
          _summaryRow('Позиций:', '${_items.length} шт (${_items.fold(0, (s, i) => s + i.quantity.toInt())} ед.)'),
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
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.cardBorder)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}
