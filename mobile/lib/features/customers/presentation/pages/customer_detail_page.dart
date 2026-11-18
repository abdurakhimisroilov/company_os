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
import '../bloc/customers_bloc.dart';
import '../../data/models/customer_model.dart';
import '../../data/repositories/customers_repository.dart';
import '../widgets/customer_form_sheet.dart';

class CustomerDetailPage extends StatefulWidget {
  final String customerId;

  const CustomerDetailPage({super.key, required this.customerId});

  @override
  State<CustomerDetailPage> createState() => _CustomerDetailPageState();
}

class _CustomerDetailPageState extends State<CustomerDetailPage> {
  final CustomersRepository _repository = getIt<CustomersRepository>();
  CustomerModel? _customer;
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
    if (_customer == null) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final customer = await _repository.getCustomerById(widget.customerId);
      if (!mounted) return;
      setState(() {
        _customer = customer;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      final message = apiErrorMessage(e, fallback: 'Не удалось загрузить данные клиента');
      if (_customer == null) {
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

  void _reloadList() => context.read<CustomersBloc>().add(const LoadCustomersEvent());

  Future<void> _edit() async {
    final current = _customer;
    if (current == null) return;
    final saved = await showCustomerFormSheet(context, customer: current);
    if (saved == null || !mounted) return;
    _showMessage('Данные клиента обновлены');
    _reloadList();
    await _load();
  }

  Future<void> _delete() async {
    final current = _customer;
    if (current == null || _deleting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить клиента?'),
        content: Text('Клиент «${current.name}» будет удалён. Это действие нельзя отменить.'),
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
      await _repository.deleteCustomer(current.id);
      if (!mounted) return;
      _reloadList();
      _showMessage('Клиент удалён');
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      _showMessage(apiErrorMessage(e, fallback: 'Не удалось удалить клиента'), isError: true);
    }
  }

  Future<void> _copy(String value, String what) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    _showMessage('$what скопирован');
  }

  @override
  Widget build(BuildContext context) {
    final loaded = _customer != null;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Карточка клиента'),
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
    final customer = _customer;
    if (customer != null) {
      return RefreshIndicator(onRefresh: _load, child: _buildContent(customer));
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
            Text(_error ?? 'Не удалось загрузить данные клиента', style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: const Text('Повторить')),
          ],
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'paid':
        return 'Оплачено';
      case 'partial':
        return 'Частично';
      default:
        return 'Долг';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'paid':
        return AppColors.success;
      case 'partial':
        return AppColors.warning;
      default:
        return AppColors.error;
    }
  }

  Widget _buildContent(CustomerModel c) {
    final bool hasDebt = c.debtAmount > 0;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        // Header profile card
        GlassCard(
          padding: const EdgeInsets.all(20),
          borderRadius: 20,
          borderColor: hasDebt ? AppColors.error.withOpacity(0.3) : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: hasDebt ? AppColors.iconBgRed : AppColors.iconBgBlue,
                    child: Text(
                      c.name.isNotEmpty ? c.name.characters.first.toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: hasDebt ? AppColors.error : AppColors.primaryBlue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.name,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary),
                        ),
                        if (c.phone.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(c.phone, style: AppTextStyles.bodyMedium),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              if (c.phone.isNotEmpty)
                _row(Icons.phone_outlined, 'Телефон:', c.phone, onTap: () => _copy(c.phone, 'Телефон')),
              if (c.email.isNotEmpty)
                _row(Icons.email_outlined, 'Email:', c.email, onTap: () => _copy(c.email, 'Email')),
              if (c.address.isNotEmpty) _row(Icons.location_on_outlined, 'Адрес:', c.address),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Всего покупок', style: AppTextStyles.caption),
                      const SizedBox(height: 2),
                      Text(
                        Formatters.formatUzs(c.totalPurchases),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryBlue),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Текущий долг', style: AppTextStyles.caption),
                      const SizedBox(height: 2),
                      Text(
                        Formatters.formatUzs(c.debtAmount),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: hasDebt ? AppColors.error : AppColors.success,
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

        // History of Purchases
        Text('История заказов / покупок', style: AppTextStyles.titleMedium),
        const SizedBox(height: 10),

        if (c.purchaseHistory.isEmpty)
          GlassCard(
            padding: const EdgeInsets.all(20),
            borderRadius: 14,
            child: Center(child: Text('Покупок пока нет', style: AppTextStyles.caption)),
          )
        else
          ...c.purchaseHistory.map((p) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  onTap: p.id.isEmpty ? null : () => context.push('/sales/${p.id}'),
                  padding: const EdgeInsets.all(14),
                  borderRadius: 14,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.saleNumber.isNotEmpty ? 'Продажа № ${p.saleNumber}' : 'Продажа',
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
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            p.status == 'paid'
                                ? _statusLabel(p.status)
                                : '${_statusLabel(p.status)}: ${Formatters.formatUzs(p.amount - p.paidAmount)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _statusColor(p.status),
                            ),
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
