import 'package:flutter/material.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/formatters.dart';
import '../../../customers/data/models/customer_model.dart';
import '../../../customers/data/repositories/customers_repository.dart';
import '../../../inventory/presentation/widgets/search_picker_sheet.dart';

/// Lets the user pick an existing customer from the server or type the name
/// of a new one (the server creates it together with the sale).
Future<PickerResult<CustomerModel>?> showCustomerPicker(BuildContext context) {
  return showSearchPicker<CustomerModel>(
    context: context,
    title: 'Выберите клиента',
    searchHint: 'Поиск по имени, телефону...',
    icon: Icons.person_outline,
    loader: (search) => getIt<CustomersRepository>().getCustomers(search: search),
    titleOf: (c) => c.name,
    subtitleOf: (c) => c.phone,
    trailingOf: (c) => c.debtAmount > 0 ? 'Долг: ${Formatters.formatUzs(c.debtAmount)}' : null,
    emptyText: 'Клиенты не найдены.\nВведите имя, чтобы добавить нового',
    createLabel: (name) => 'Новый клиент «$name»',
  );
}
