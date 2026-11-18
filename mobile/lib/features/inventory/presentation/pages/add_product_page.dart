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

/// Creates a product, or edits [product] when one is given.
class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key, this.product});

  final ProductModel? product;

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _minStockController = TextEditingController(text: '5');
  final _initialStockController = TextEditingController();
  final _newCategoryController = TextEditingController();
  final _descriptionController = TextEditingController();

  static const String _noCategory = '';
  static const String _newCategory = '__new__';

  final InventoryRepository _repository = getIt<InventoryRepository>();
  final List<String> _units = ['шт', 'кг', 'м', 'л', 'упак'];
  String _unit = 'шт';

  List<ProductCategoryModel> _categories = [];
  bool _categoriesLoading = true;
  String? _categoriesError;
  String _selectedCategory = _noCategory;
  bool _saving = false;

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    if (p != null) {
      _nameController.text = p.name;
      _skuController.text = p.sku;
      _barcodeController.text = p.barcode ?? '';
      _sellingPriceController.text = formatQty(p.sellingPrice);
      _purchasePriceController.text = formatQty(p.purchasePrice);
      _minStockController.text = formatQty(p.minStockLevel);
      _descriptionController.text = p.description ?? '';
      _unit = p.unit;
      if (!_units.contains(p.unit)) _units.add(p.unit);
      _selectedCategory = p.categoryId ?? _noCategory;
    }
    _loadCategories();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    _sellingPriceController.dispose();
    _purchasePriceController.dispose();
    _minStockController.dispose();
    _initialStockController.dispose();
    _newCategoryController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _categoriesLoading = true;
      _categoriesError = null;
    });
    try {
      final categories = await _repository.getCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _categoriesLoading = false;
        // The product's category may have been removed meanwhile.
        if (_selectedCategory != _noCategory &&
            _selectedCategory != _newCategory &&
            !categories.any((c) => c.id == _selectedCategory)) {
          _selectedCategory = _noCategory;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _categoriesLoading = false;
        _categoriesError = apiErrorMessage(e, fallback: 'Не удалось загрузить категории');
      });
    }
  }

  String? _validateNumber(String? v, {bool required = false}) {
    final text = (v ?? '').trim();
    if (text.isEmpty) return required ? 'Обязательное поле' : null;
    final value = parseAmount(text);
    if (value == null) return 'Введите число';
    if (value < 0) return 'Не может быть меньше 0';
    return null;
  }

  Future<void> _saveProduct() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    if (_categoriesLoading) {
      _showError('Категории ещё загружаются, подождите');
      return;
    }

    final data = <String, dynamic>{
      'name': _nameController.text.trim(),
      'unit': _unit,
      'sellingPrice': parseAmount(_sellingPriceController.text) ?? 0,
      'purchasePrice': parseAmount(_purchasePriceController.text) ?? 0,
      'minStockLevel': parseAmount(_minStockController.text) ?? 0,
      'description': _descriptionController.text.trim(),
    };
    final sku = _skuController.text.trim();
    if (sku.isNotEmpty) data['sku'] = sku;
    final barcode = _barcodeController.text.trim();
    if (_isEdit || barcode.isNotEmpty) data['barcode'] = barcode;

    if (_selectedCategory == _newCategory) {
      data['categoryName'] = _newCategoryController.text.trim();
    } else if (_selectedCategory != _noCategory) {
      data['categoryId'] = _selectedCategory;
    } else if (_isEdit && widget.product!.categoryId != null && _categoriesError == null) {
      // The category was deliberately cleared.
      data['categoryId'] = null;
    }

    if (!_isEdit) {
      final initialStock = parseAmount(_initialStockController.text) ?? 0;
      if (initialStock > 0) data['initialStock'] = initialStock;
    }

    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await _repository.updateProduct(widget.product!.id, data);
      } else {
        await _repository.createProduct(data);
      }
      if (!mounted) return;
      context.read<InventoryBloc>().add(const RefreshProductsEvent());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEdit ? 'Товар обновлён' : 'Товар добавлен'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showError(apiErrorMessage(e, fallback: 'Не удалось сохранить товар'));
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  Widget _buildCategoryField() {
    if (_categoriesLoading) {
      return Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 12),
            Text('Загрузка категорий...', style: AppTextStyles.caption),
          ],
        ),
      );
    }
    if (_categoriesError != null) {
      return Row(
        children: [
          Expanded(
            child: Text(_categoriesError!, style: AppTextStyles.caption.copyWith(color: AppColors.error)),
          ),
          TextButton(onPressed: _loadCategories, child: const Text('Повторить')),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCategory,
              isExpanded: true,
              items: [
                const DropdownMenuItem(value: _noCategory, child: Text('Без категории')),
                ..._categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis))),
                const DropdownMenuItem(value: _newCategory, child: Text('+ Новая категория')),
              ],
              onChanged: _saving ? null : (v) => setState(() => _selectedCategory = v ?? _noCategory),
            ),
          ),
        ),
        if (_selectedCategory == _newCategory) ...[
          const SizedBox(height: 8),
          TextFormField(
            controller: _newCategoryController,
            textCapitalization: TextCapitalization.sentences,
            decoration: _inputDecoration('Название новой категории'),
            validator: (v) => (_selectedCategory == _newCategory && (v == null || v.trim().isEmpty))
                ? 'Введите название категории'
                : null,
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEdit ? 'Редактировать товар' : 'Новый товар'),
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
                      Text('Название товара *', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameController,
                        decoration: _inputDecoration('Например, Смартфон Galaxy S24'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Введите название' : null,
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Артикул (SKU)', style: AppTextStyles.labelMedium),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _skuController,
                                  decoration: _inputDecoration(_isEdit ? 'SKU-1001' : 'Авто'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Штрихкод', style: AppTextStyles.labelMedium),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _barcodeController,
                                  decoration: _inputDecoration('478000...'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Text('Категория', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 8),
                      _buildCategoryField(),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Единица изм.', style: AppTextStyles.labelMedium),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  decoration: BoxDecoration(
                                    color: AppColors.cardBackground,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: AppColors.cardBorder),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _unit,
                                      isExpanded: true,
                                      items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                                      onChanged: _saving ? null : (v) => setState(() => _unit = v ?? _unit),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Мин. остаток', style: AppTextStyles.labelMedium),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _minStockController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: _inputDecoration('5'),
                                  validator: _validateNumber,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Закупочная цена', style: AppTextStyles.labelMedium),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _purchasePriceController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: _inputDecoration('0 сум'),
                                  validator: _validateNumber,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Цена продажи *', style: AppTextStyles.labelMedium),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _sellingPriceController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: _inputDecoration('0 сум'),
                                  validator: (v) => _validateNumber(v, required: true),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      if (!_isEdit) ...[
                        Text('Начальный остаток на складе', style: AppTextStyles.labelMedium),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _initialStockController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: _inputDecoration('0'),
                          validator: _validateNumber,
                        ),
                        const SizedBox(height: 16),
                      ],

                      Text('Описание', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: _inputDecoration('Краткие характеристики товара...'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                AppButton(
                  label: _isEdit ? 'Сохранить' : 'Добавить товар',
                  isLoading: _saving,
                  onPressed: _saveProduct,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: AppColors.cardBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.cardBorder),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}
