import 'package:flutter/material.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/transaction_model.dart';

/// Counterparty input: the user either picks a real record loaded from the
/// server (its id is then sent with the operation) or types a one-off name.
class PartyPickerField extends StatelessWidget {
  final TextEditingController controller;
  final PartyRef? selected;

  /// Called with the picked record, or with null as soon as the text no longer
  /// matches the picked record.
  final ValueChanged<PartyRef?> onChanged;
  final Future<List<PartyRef>> Function() loader;
  final String hint;
  final String sheetTitle;
  final String emptyText;
  final String linkedHelper;
  final String freeHelper;
  final IconData icon;
  final String? Function(String?)? validator;

  const PartyPickerField({
    super.key,
    required this.controller,
    required this.selected,
    required this.onChanged,
    required this.loader,
    required this.hint,
    required this.sheetTitle,
    required this.emptyText,
    required this.linkedHelper,
    required this.freeHelper,
    this.icon = Icons.person_outline,
    this.validator,
  });

  Future<void> _openPicker(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final picked = await showModalBottomSheet<PartyRef>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PartyPickerSheet(title: sheetTitle, emptyText: emptyText, loader: loader),
    );
    if (picked == null) return;
    controller.text = picked.name;
    onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final linked = selected != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          textCapitalization: TextCapitalization.sentences,
          style: TextStyle(color: AppColors.textPrimary),
          onChanged: (text) {
            if (selected != null && text.trim() != selected!.name) onChanged(null);
          },
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(linked ? Icons.verified_user_outlined : icon, color: AppColors.primaryBlue),
            suffixIcon: IconButton(
              icon: const Icon(Icons.list_alt_rounded, color: AppColors.primaryBlue),
              tooltip: sheetTitle,
              onPressed: () => _openPicker(context),
            ),
            filled: true,
            fillColor: AppColors.cardBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.cardBorder),
            ),
          ),
          validator: validator,
        ),
        const SizedBox(height: 6),
        Text(
          linked ? linkedHelper : freeHelper,
          style: AppTextStyles.caption.copyWith(color: linked ? AppColors.success : AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _PartyPickerSheet extends StatefulWidget {
  final String title;
  final String emptyText;
  final Future<List<PartyRef>> Function() loader;

  const _PartyPickerSheet({required this.title, required this.emptyText, required this.loader});

  @override
  State<_PartyPickerSheet> createState() => _PartyPickerSheetState();
}

class _PartyPickerSheetState extends State<_PartyPickerSheet> {
  List<PartyRef>? _items;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _items = null;
      _error = null;
    });
    try {
      final items = await widget.loader();
      if (!mounted) return;
      setState(() => _items = items);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = apiErrorMessage(e, fallback: 'Не удалось загрузить список'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.7;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: height,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: AppColors.neutral300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text(
              widget.title,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            TextField(
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              style: TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Поиск по названию или телефону',
                prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.background.withOpacity(0.3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.cardBorder),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: AppColors.error),
            const SizedBox(height: 10),
            Text(_error!, textAlign: TextAlign.center, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Повторить')),
          ],
        ),
      );
    }
    final items = _items;
    if (items == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue));
    }
    final shown = _query.isEmpty
        ? items
        : items.where((p) => p.name.toLowerCase().contains(_query) || p.phone.toLowerCase().contains(_query)).toList();
    if (shown.isEmpty) {
      return Center(
        child: Text(
          items.isEmpty ? widget.emptyText : 'Ничего не найдено',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
        ),
      );
    }
    return ListView.separated(
      itemCount: shown.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.cardBorder),
      itemBuilder: (context, index) {
        final party = shown[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(party.name, style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          subtitle: party.phone.isEmpty ? null : Text(party.phone, style: AppTextStyles.caption),
          onTap: () => Navigator.pop(context, party),
        );
      },
    );
  }
}
