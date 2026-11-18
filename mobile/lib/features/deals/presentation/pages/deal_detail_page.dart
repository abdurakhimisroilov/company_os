import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../bloc/deals_bloc.dart';
import '../../data/models/deal_model.dart';
import '../../data/repositories/deals_repository.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_error.dart';
import 'add_deal_page.dart';

class DealDetailPage extends StatefulWidget {
  final String dealId;

  const DealDetailPage({super.key, required this.dealId});

  @override
  State<DealDetailPage> createState() => _DealDetailPageState();
}

class _DealDetailPageState extends State<DealDetailPage> {
  final _commentController = TextEditingController();
  final DealsRepository _repository = getIt<DealsRepository>();

  DealModel? _deal;
  String? _error;
  bool _loading = true;
  bool _sendingComment = false;
  bool _changingStatus = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  /// Loads the deal. An already shown deal stays on screen while it refreshes.
  Future<void> _load() async {
    if (_deal == null) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final deal = await _repository.getDealById(widget.dealId);
      if (!mounted) return;
      setState(() {
        _deal = deal;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      final message = apiErrorMessage(e, fallback: 'Не удалось загрузить данные сделки');
      if (_deal == null) {
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

  void _reloadList() => context.read<DealsBloc>().add(const LoadDealsEvent());

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _sendingComment || _deal == null) return;

    setState(() => _sendingComment = true);
    try {
      final comment = await _repository.addComment(widget.dealId, text);
      if (!mounted) return;
      _commentController.clear();
      setState(() {
        _sendingComment = false;
        _deal = _deal!.copyWith(comments: [..._deal!.comments, comment]);
      });
    } catch (e) {
      // The typed text stays in the field so it can be sent again.
      if (!mounted) return;
      setState(() => _sendingComment = false);
      _showMessage(apiErrorMessage(e, fallback: 'Не удалось добавить комментарий'), isError: true);
    }
  }

  Future<void> _changeStatus(String newStatus) async {
    final deal = _deal;
    if (deal == null || _changingStatus || newStatus == deal.status) return;
    setState(() => _changingStatus = true);
    try {
      final updated = await _repository.updateDealStatus(deal.id, newStatus);
      if (!mounted) return;
      setState(() {
        _deal = updated;
        _changingStatus = false;
      });
      _reloadList();
      _showMessage('Статус сделки обновлён');
    } catch (e) {
      if (!mounted) return;
      setState(() => _changingStatus = false);
      _showMessage(apiErrorMessage(e, fallback: 'Не удалось обновить статус сделки'), isError: true);
    }
  }

  Future<void> _edit() async {
    final deal = _deal;
    if (deal == null) return;
    final saved = await Navigator.of(context).push<DealModel>(
      MaterialPageRoute(builder: (_) => AddDealPage(deal: deal)),
    );
    if (saved == null || !mounted) return;
    setState(() => _deal = saved);
  }

  Future<void> _delete() async {
    final deal = _deal;
    if (deal == null || _deleting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить сделку?'),
        content: Text('Сделка «${deal.title}» и её комментарии будут удалены. Это действие нельзя отменить.'),
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
      await _repository.deleteDeal(deal.id);
      if (!mounted) return;
      _reloadList();
      _showMessage('Сделка удалена');
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      _showMessage(apiErrorMessage(e, fallback: 'Не удалось удалить сделку'), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loaded = _deal != null;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Карточка сделки'),
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
    final deal = _deal;
    if (deal != null) return _buildContent(deal);
    if (_loading) return const LoadingShimmer();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(_error ?? 'Не удалось загрузить данные сделки', style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: const Text('Повторить')),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(DealModel deal) {
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              // Header Card
              GlassCard(
                padding: const EdgeInsets.all(18),
                borderRadius: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deal.title,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      deal.customerName.isNotEmpty ? 'Клиент: ${deal.customerName}' : 'Клиент не указан',
                      style: AppTextStyles.bodyMedium,
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Сумма сделки', style: AppTextStyles.caption),
                            const SizedBox(height: 2),
                            Text(
                              Formatters.formatUzs(deal.amount),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primaryBlue),
                            ),
                          ],
                        ),
                        // Status selector dropdown
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: AppColors.cardBackground,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: deal.status,
                              items: DealModel.statusKeys.map((s) {
                                return DropdownMenuItem(
                                  value: s,
                                  child: Text(
                                    DealModel.statusNames[s] ?? s,
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                  ),
                                );
                              }).toList(),
                              onChanged: _changingStatus || _deleting
                                  ? null
                                  : (newStatus) {
                                      if (newStatus != null) _changeStatus(newStatus);
                                    },
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (deal.expectedCloseDate != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Text('План закрытия: ${Formatters.formatDate(deal.expectedCloseDate!)}', style: AppTextStyles.caption),
                        ],
                      ),
                    ],
                    if (deal.assignedEmployeeName != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.badge_outlined, size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Text('Ответственный: ${deal.assignedEmployeeName!}', style: AppTextStyles.caption),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (deal.description != null && deal.description!.isNotEmpty) ...[
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  borderRadius: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Описание сделки', style: AppTextStyles.titleMedium),
                      const SizedBox(height: 8),
                      Text(deal.description!, style: AppTextStyles.bodyMedium),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Comments timeline
              Text('Активность и комментарии', style: AppTextStyles.titleMedium),
              const SizedBox(height: 10),

              if (deal.comments.isEmpty)
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  borderRadius: 14,
                  child: Center(child: Text('Комментариев пока нет', style: AppTextStyles.caption)),
                )
              else
                ...deal.comments.map((c) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: GlassCard(
                        padding: const EdgeInsets.all(12),
                        borderRadius: 14,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    c.authorName.isNotEmpty ? c.authorName : 'Автор удалён',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryBlue),
                                  ),
                                ),
                                if (c.createdAt != null) Text(Formatters.formatDateTime(c.createdAt), style: AppTextStyles.caption),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(c.text, style: AppTextStyles.bodyMedium),
                          ],
                        ),
                      ),
                    )),
              const SizedBox(height: 20),
            ],
          ),
          ),
        ),

        // Add Comment Bar at bottom
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2)),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    enabled: !_sendingComment,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Добавить комментарий...',
                      hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 14),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: _sendingComment
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send, color: AppColors.primaryBlue),
                  onPressed: _sendingComment ? null : _sendComment,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
