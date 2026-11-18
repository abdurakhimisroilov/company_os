import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../bloc/suppliers_bloc.dart';
import '../../data/models/supplier_model.dart';
import '../../data/repositories/suppliers_repository.dart';
import '../widgets/supplier_form_sheet.dart';

class SupplierDetailPage extends StatefulWidget {
  final String supplierId;

  const SupplierDetailPage({super.key, required this.supplierId});

  @override
  State<SupplierDetailPage> createState() => _SupplierDetailPageState();
}

class _SupplierDetailPageState extends State<SupplierDetailPage> {
  final SuppliersRepository _repository = getIt<SuppliersRepository>();
  SupplierModel? _supplier;
  String? _error;
  bool _loading = true;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Loads the card. An already shown card stays on screen while it refreshes.
  Future<void> _load() async {
    if (_supplier == null) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final supplier = await _repository.getSupplierById(widget.supplierId);
      if (!mounted) return;
      setState(() {
        _supplier = supplier;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      final message = apiErrorMessage(e, fallback: 'Не удалось загрузить данные поставщика');
      if (_supplier == null) {
        setState(() {
          _loading = false;
          _error = message;
        });
      } else {
        _showMessage(message, isError: true);
      }
    }
  }

  void _showMessage(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: isError ? AppColors.error : AppColors.success),
    );
  }

  void _reloadList() => context.read<SuppliersBloc>().add(const LoadSuppliersEvent());

  Future<void> _edit() async {
    final current = _supplier;
    if (current == null) return;
    final saved = await showSupplierFormSheet(context, supplier: current);
    if (saved == null || !mounted) return;
    _showMessage('Данные поставщика обновлены');
    _reloadList();
    await _load();
  }

  Future<void> _delete() async {
    final current = _supplier;
    if (current == null || _deleting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить поставщика?'),
        content: Text('Поставщик «${current.name}» будет удалён. Это действие нельзя отменить.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await _repository.deleteSupplier(current.id);
      if (!mounted) return;
      _reloadList();
      _showMessage('Поставщик удалён');
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      _showMessage(apiErrorMessage(e, fallback: 'Не удалось удалить поставщика'), isError: true);
    }
  }

  Future<void> _copy(String value, String what) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    _showMessage('$what скопирован');
  }

  @override
  Widget build(BuildContext context) {
    final loaded = _supplier != null;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Карточка поставщика'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (loaded) ...[
            IconButton(
              tooltip: 'Изменить',
              icon: const Icon(Icons.edit_outlined, color: AppColors.primaryBlue),
              onPressed: _deleting ? null : _edit,
            ),
            IconButton(
              tooltip: 'Удалить',
              icon: _deleting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.delete_outline, color: AppColors.error),
              onPressed: _deleting ? null : _delete,
            ),
          ],
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final supplier = _supplier;
    if (supplier != null) {
      return RefreshIndicator(onRefresh: _load, child: _buildContent(supplier));
    }
    if (_loading) return const LoadingShimmer();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(_error ?? 'Не удалось загрузить данные поставщика', style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: const Text('Повторить')),
          ],
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'received':
        return 'Принято';
      case 'cancelled':
        return 'Отменено';
      default:
        return 'Ожидается';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'received':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  Widget _buildContent(SupplierModel s) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        // Info card
        GlassCard(
          padding: const EdgeInsets.all(20),
          borderRadius: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.name,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              if (s.contactPerson.isNotEmpty)
                _row(Icons.person, 'Контакт:', s.contactPerson),
              if (s.phone.isNotEmpty)
                _row(Icons.phone, 'Телефон:', s.phone, onTap: () => _copy(s.phone, 'Телефон')),
              if (s.email.isNotEmpty)
                _row(Icons.email, 'Email:', s.email, onTap: () => _copy(s.email, 'Email')),
              if (s.address.isNotEmpty)
                _row(Icons.location_on, 'Адрес:', s.address),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Всего закупок', style: AppTextStyles.caption),
                      const SizedBox(height: 2),
                      Text(
                        Formatters.formatUzs(s.totalPurchases),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryBlue),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Наш долг', style: AppTextStyles.caption),
                      const SizedBox(height: 2),
                      Text(
                        Formatters.formatUzs(s.payableBalance),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: s.payableBalance > 0 ? AppColors.error : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Purchase history
        Text('История поставок / закупок', style: AppTextStyles.titleMedium),
        const SizedBox(height: 10),

        if (s.purchases.isEmpty)
          GlassCard(
            padding: const EdgeInsets.all(20),
            borderRadius: 14,
            child: Center(child: Text('Закупок у данного поставщика пока нет', style: AppTextStyles.caption)),
          )
        else
          ...s.purchases.map((p) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  onTap: p.id.isEmpty ? null : () => context.push('/incoming-goods/${p.id}'),
                  padding: const EdgeInsets.all(14),
                  borderRadius: 14,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.invoiceNumber.isNotEmpty ? 'Накладная ${p.invoiceNumber}' : 'Накладная',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                          ),
                          if (p.date != null) ...[
                            const SizedBox(height: 4),
                            Text(Formatters.formatDate(p.date), style: AppTextStyles.caption),
                          ],
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            Formatters.formatUzs(p.amount),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primaryBlue),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _statusLabel(p.status),
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _statusColor(p.status)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )),
      ],
    );
  }

  Widget _row(IconData icon, String label, String value, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.primaryBlue),
            const SizedBox(width: 8),
            Text(label, style: AppTextStyles.caption),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                value,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
              ),
            ),
            if (onTap != null) Icon(Icons.copy_outlined, size: 14, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
