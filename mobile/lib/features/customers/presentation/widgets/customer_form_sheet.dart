import 'package:flutter/material.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/customer_model.dart';
import '../../data/repositories/customers_repository.dart';

/// Opens the create / edit customer sheet. Returns the saved customer, or
/// null when the sheet was dismissed.
Future<CustomerModel?> showCustomerFormSheet(BuildContext context, {CustomerModel? customer}) {
  return showModalBottomSheet<CustomerModel>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CustomerFormSheet(customer: customer),
  );
}

class _CustomerFormSheet extends StatefulWidget {
  const _CustomerFormSheet({this.customer});

  final CustomerModel? customer;

  @override
  State<_CustomerFormSheet> createState() => _CustomerFormSheetState();
}

class _CustomerFormSheetState extends State<_CustomerFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _address;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.customer != null;

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    _name = TextEditingController(text: c?.name ?? '');
    _phone = TextEditingController(text: c?.phone ?? '');
    _email = TextEditingController(text: c?.email ?? '');
    _address = TextEditingController(text: c?.address ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final data = {
      'name': _name.text.trim(),
      'phone': _phone.text.trim(),
      'email': _email.text.trim(),
      'address': _address.text.trim(),
    };
    try {
      final repo = getIt<CustomersRepository>();
      final saved = _isEdit ? await repo.updateCustomer(widget.customer!.id, data) : await repo.createCustomer(data);
      if (!mounted) return;
      Navigator.pop(context, saved);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = apiErrorMessage(e, fallback: 'Не удалось сохранить клиента');
      });
    }
  }

  InputDecoration _deco(String label) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 20,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_isEdit ? 'Изменить клиента' : 'Новый клиент', style: AppTextStyles.titleMedium),
              const SizedBox(height: 14),
              TextFormField(
                controller: _name,
                enabled: !_saving,
                textCapitalization: TextCapitalization.sentences,
                decoration: _deco('Имя / Название компании *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Укажите имя или название' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                enabled: !_saving,
                keyboardType: TextInputType.phone,
                decoration: _deco('Телефон'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                enabled: !_saving,
                keyboardType: TextInputType.emailAddress,
                decoration: _deco('Email'),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return null;
                  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t) ? null : 'Некорректный email';
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _address,
                enabled: !_saving,
                decoration: _deco('Адрес'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error)),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : Text(_isEdit ? 'Сохранить изменения' : 'Сохранить клиента'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
