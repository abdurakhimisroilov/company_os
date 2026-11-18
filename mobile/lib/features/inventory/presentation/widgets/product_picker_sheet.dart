import 'package:flutter/material.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/models/product_model.dart';
import '../../data/repositories/inventory_repository.dart';
import 'search_picker_sheet.dart';

/// Lets the user pick a real product from the server (search by name / SKU / barcode).
/// [showSellingPrice] switches the price shown on the right between selling and purchase price.
Future<ProductModel?> showProductPicker(
  BuildContext context, {
  bool showSellingPrice = true,
}) async {
  final result = await showSearchPicker<ProductModel>(
    context: context,
    title: 'Выберите товар',
    searchHint: 'Поиск по названию, артикулу...',
    loader: (search) => getIt<InventoryRepository>().getProducts(search: search),
    titleOf: (p) => p.name,
    subtitleOf: (p) => 'Арт: ${p.sku}  •  Остаток: ${formatQty(p.currentStock)} ${p.unit}',
    trailingOf: (p) => Formatters.formatUzs(showSellingPrice ? p.sellingPrice : p.purchasePrice),
    emptyText: 'Товары не найдены.\nДобавьте товар в разделе «Склад и товары»',
  );
  return result?.item;
}
