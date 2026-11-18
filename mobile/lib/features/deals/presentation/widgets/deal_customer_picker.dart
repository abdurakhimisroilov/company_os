import 'dart:async';

import 'package:flutter/material.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../customers/data/models/customer_model.dart';
import '../../../customers/data/repositories/customers_repository.dart';

/// The customer chosen for a deal: an existing record ([id] set) or a new
/// one that the server creates by [name].
class DealCustomerChoice {
  final String? id;
  final String name;
  const DealCustomerChoice({this.id, required this.name});

  bool get isNew => id == null;
}

Future<DealCustomerChoice?> showDealCustomerPicker(BuildContext context) {
  return showModalBottomSheet<DealCustomerChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _DealCustomerPickerSheet(),
  );
}

class _DealCustomerPickerSheet extends StatefulWidget {
  const _DealCustomerPickerSheet();

  @override
  State<_DealCustomerPickerSheet> createState() => _DealCustomerPickerSheetState();
}

class _DealCustomerPickerSheetState extends State<_DealCustomerPickerSheet> {
  final _searchController = TextEditingController();
  final CustomersRepository _repository = getIt<CustomersRepository>();
  Timer? _debounce;
  List<CustomerModel> _customers = const [];
  bool _loading = true;
  String? _error;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _repository.getCustomers(search: _searchController.text.trim());
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _customers = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _loading = false;
        _error = apiErrorMessage(e, fallback: 'Не удалось загрузить клиентов');
      });
    }
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final typed = _searchController.text.trim();
    final exactExists = _customers.any((c) => c.name.toLowerCase() == typed.toLowerCase());
    final showCreate = typed.isNotEmpty && !_loading && _error == null && !exactExists;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 20,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Выберите клиента', style: AppTextStyles.titleMedium),
          const SizedBox(height: 14),
          TextField(
            controller: _searchController,
            onChanged: _onChanged,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Поиск или название нового клиента',
              prefixIcon: const Icon(Icons.search, color: AppColors.primaryBlue),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _buildResults(typed, showCreate)),
        ],
      ),
    );
  }

  Widget _buildResults(String typed, bool showCreate) {
    if (_loading && _customers.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Повторить')),
          ],
        ),
      );
    }
    if (_customers.isEmpty && !showCreate) {
      return Center(
        child: Text(
          'Клиентов пока нет. Введите название, чтобы добавить нового',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        if (showCreate)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: AppColors.iconBgGreen,
              child: const Icon(Icons.person_add, color: AppColors.success, size: 20),
            ),
            title: Text('Новый клиент: «$typed»', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            subtitle: Text('Будет создан вместе со сделкой', style: AppTextStyles.caption),
            onTap: () => Navigator.pop(context, DealCustomerChoice(name: typed)),
          ),
        ..._customers.map(
          (c) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: AppColors.iconBgBlue,
              child: Text(
                c.name.isNotEmpty ? c.name.characters.first.toUpperCase() : '?',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
              ),
            ),
            title: Text(c.name, style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            subtitle: c.phone.isNotEmpty ? Text(c.phone, style: AppTextStyles.caption) : null,
            onTap: () => Navigator.pop(context, DealCustomerChoice(id: c.id, name: c.name)),
          ),
        ),
      ],
    );
  }
}
