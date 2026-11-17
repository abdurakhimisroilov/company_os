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

class DealDetailPage extends StatefulWidget {
  final String dealId;

  const DealDetailPage({super.key, required this.dealId});

  @override
  State<DealDetailPage> createState() => _DealDetailPageState();
}

class _DealDetailPageState extends State<DealDetailPage> {
  final _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<DealsBloc>().add(LoadDealDetailEvent(widget.dealId));
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _sendComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    context.read<DealsBloc>().add(AddDealCommentEvent(dealId: widget.dealId, comment: text));
    _commentController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Карточка сделки'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: BlocConsumer<DealsBloc, DealsState>(
          listener: (context, state) {
            if (state is DealsActionSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message), backgroundColor: AppColors.success),
              );
            }
          },
          builder: (context, state) {
            if (state is DealsLoading) {
              return const LoadingShimmer();
            }
            if (state is DealDetailLoaded) {
              return _buildContent(state.deal);
            }
            if (state is DealsError) {
              return Center(child: Text(state.message));
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildContent(DealModel deal) {
    return Column(
      children: [
        Expanded(
          child: ListView(
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
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    Text('Клиент: ${deal.customerName}', style: AppTextStyles.bodyMedium),
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
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: deal.status,
                              items: DealModel.statusKeys.map((s) {
                                return DropdownMenuItem(
                                  value: s,
                                  child: Text(DealModel.statusNames[s] ?? s, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                );
                              }).toList(),
                              onChanged: (newStatus) {
                                if (newStatus != null) {
                                  context.read<DealsBloc>().add(
                                        UpdateDealStatusEvent(dealId: deal.id, status: newStatus),
                                      );
                                }
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
                          const Icon(Icons.calendar_today, size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Text('План закрытия: ${Formatters.formatDate(deal.expectedCloseDate!)}', style: AppTextStyles.caption),
                        ],
                      ),
                    ],
                    if (deal.assignedEmployeeName != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.badge_outlined, size: 14, color: AppColors.textSecondary),
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
                                Text(c.authorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryBlue)),
                                Text(Formatters.formatDate(c.createdAt), style: AppTextStyles.caption),
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

        // Add Comment Bar at bottom
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
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
                  icon: const Icon(Icons.send, color: AppColors.primaryBlue),
                  onPressed: _sendComment,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
