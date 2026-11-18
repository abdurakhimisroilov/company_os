import 'package:flutter/material.dart';
import '../../../../core/di/injection.dart';
import '../../../inventory/presentation/widgets/search_picker_sheet.dart';
import '../../../suppliers/data/models/supplier_model.dart';
import '../../../suppliers/data/repositories/suppliers_repository.dart';

/// Lets the user pick an existing supplier from the server or type the name
/// of a new one (the server creates it together with the shipment).
Future<PickerResult<SupplierModel>?> showSupplierPicker(BuildContext context) {
  return showSearchPicker<SupplierModel>(
    context: context,
    title: 'Выберите поставщика',
    searchHint: 'Поиск по названию, телефону...',
    icon: Icons.local_shipping_outlined,
    loader: (search) => getIt<SuppliersRepository>().getSuppliers(search: search),
    titleOf: (s) => s.name,
    subtitleOf: (s) => s.phone,
    emptyText: 'Поставщики не найдены.\nВведите название, чтобы добавить нового',
    createLabel: (name) => 'Новый поставщик «$name»',
  );
}
