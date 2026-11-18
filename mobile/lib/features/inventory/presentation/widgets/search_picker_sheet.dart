import 'dart:async';

import 'package:flutter/material.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// What the user chose in a [showSearchPicker] sheet: an existing record,
/// or (when the sheet allows it) a new name that the server will create.
class PickerResult<T> {
  final T? item;
  final String? newName;
  const PickerResult.existing(T this.item) : newName = null;
  const PickerResult.created(String this.newName) : item = null;
}

/// Bottom sheet that searches records on the server and returns the chosen one.
Future<PickerResult<T>?> showSearchPicker<T>({
  required BuildContext context,
  required String title,
  required String searchHint,
  required Future<List<T>> Function(String search) loader,
  required String Function(T item) titleOf,
  String? Function(T item)? subtitleOf,
  String? Function(T item)? trailingOf,
  IconData icon = Icons.inventory_2_outlined,
  String emptyText = 'Ничего не найдено',
  String Function(String name)? createLabel,
}) {
  return showModalBottomSheet<PickerResult<T>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _SearchPickerSheet<T>(
      title: title,
      searchHint: searchHint,
      loader: loader,
      titleOf: titleOf,
      subtitleOf: subtitleOf,
      trailingOf: trailingOf,
      icon: icon,
      emptyText: emptyText,
      createLabel: createLabel,
    ),
  );
}

class _SearchPickerSheet<T> extends StatefulWidget {
  const _SearchPickerSheet({
    required this.title,
    required this.searchHint,
    required this.loader,
    required this.titleOf,
    required this.icon,
    required this.emptyText,
    this.subtitleOf,
    this.trailingOf,
    this.createLabel,
  });

  final String title;
  final String searchHint;
  final Future<List<T>> Function(String search) loader;
  final String Function(T item) titleOf;
  final String? Function(T item)? subtitleOf;
  final String? Function(T item)? trailingOf;
  final IconData icon;
  final String emptyText;
  final String Function(String name)? createLabel;

  @override
  State<_SearchPickerSheet<T>> createState() => _SearchPickerSheetState<T>();
}

class _SearchPickerSheetState<T> extends State<_SearchPickerSheet<T>> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  int _requestSeq = 0;
  bool _loading = true;
  String? _error;
  List<T> _items = [];

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
    final seq = ++_requestSeq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.loader(_searchController.text.trim());
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _error = apiErrorMessage(e, fallback: 'Не удалось загрузить список');
        _loading = false;
      });
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _load);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final typed = _searchController.text.trim();
    final hasExactMatch = _items.any((e) => widget.titleOf(e).trim().toLowerCase() == typed.toLowerCase());
    final canCreate = widget.createLabel != null && typed.isNotEmpty && !_loading && _error == null && !hasExactMatch;

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
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
          Row(
            children: [
              Expanded(child: Text(widget.title, style: AppTextStyles.titleMedium)),
              IconButton(
                icon: Icon(Icons.close, color: AppColors.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: widget.searchHint,
              prefixIcon: const Icon(Icons.search, color: AppColors.primaryBlue),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 8),
          if (canCreate)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.iconBgGreen, shape: BoxShape.circle),
                child: const Icon(Icons.add, color: AppColors.success, size: 20),
              ),
              title: Text(
                widget.createLabel!(typed),
                style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              onTap: () => Navigator.pop(context, PickerResult<T>.created(typed)),
            ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: AppColors.error),
            const SizedBox(height: 8),
            Text(_error!, style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Повторить')),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Text(
          widget.emptyText,
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 20),
      itemCount: _items.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.divider),
      itemBuilder: (context, index) {
        final item = _items[index];
        final subtitle = widget.subtitleOf?.call(item);
        final trailing = widget.trailingOf?.call(item);
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.iconBgBlue, shape: BoxShape.circle),
            child: Icon(widget.icon, color: AppColors.primaryBlue, size: 20),
          ),
          title: Text(
            widget.titleOf(item),
            style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: subtitle == null || subtitle.isEmpty ? null : Text(subtitle, style: AppTextStyles.caption),
          trailing: trailing == null || trailing.isEmpty
              ? null
              : Text(
                  trailing,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                ),
          onTap: () => Navigator.pop(context, PickerResult<T>.existing(item)),
        );
      },
    );
  }
}
