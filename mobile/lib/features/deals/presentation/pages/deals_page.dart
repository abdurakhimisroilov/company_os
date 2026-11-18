import 'dart:async';

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

class DealsPage extends StatefulWidget {
  const DealsPage({super.key});

  @override
  State<DealsPage> createState() => _DealsPageState();
}

class _DealsPageState extends State<DealsPage> with SingleTickerProviderStateMixin {
  late TabController _viewTabController;
  final List<String> _viewModes = ['Список', 'Канбан'];

  @override
  void initState() {
    super.initState();
    _viewTabController = TabController(length: 2, vsync: this);
    context.read<DealsBloc>().add(const LoadDealsEvent());
  }

  @override
  void dispose() {
    _viewTabController.dispose();
    super.dispose();
  }

  /// Reloads the deals and finishes when the server has answered.
  Future<void> _reload() async {
    final completer = Completer<String?>();
    context.read<DealsBloc>().add(LoadDealsEvent(completer: completer));
    final error = await completer.future;
    if (!mounted || error == null) return;
    if (context.read<DealsBloc>().state is DealsLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _openDeal(DealModel deal) async {
    await context.push('/deals/${deal.id}');
    if (mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildHeader(),
              _buildViewSwitch(),
              Expanded(
                child: BlocBuilder<DealsBloc, DealsState>(
                  builder: (context, state) {
                    if (state is DealsLoaded) {
                      return TabBarView(
                        controller: _viewTabController,
                        children: [
                          _buildListView(state.deals),
                          _buildKanbanView(state.deals),
                        ],
                      );
                    }
                    if (state is DealsError) {
                      return _buildErrorState(state.message);
                    }
                    return const LoadingShimmer();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/deals/add'),
        backgroundColor: AppColors.primaryBlue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Сделка', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
            onPressed: () => context.pop(),
          ),
          Expanded(
            child: Text(
              'Сделки и CRM',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewSwitch() {
    return Container(
      height: 38,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withOpacity(0.6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TabBar(
        controller: _viewTabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: AppColors.primaryBlue,
        ),
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        tabs: _viewModes.map((v) => Tab(text: v)).toList(),
      ),
    );
  }

  Widget _buildListView(List<DealModel> deals) {
    if (deals.isEmpty) {
      return RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 60),
          children: [
            Center(
              child: Column(
                children: [
                  Icon(Icons.handshake_outlined, size: 56, color: AppColors.textTertiary),
                  const SizedBox(height: 12),
                  Text('Данных пока нет', style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary)),
                  const SizedBox(height: 6),
                  Text('Создайте первую сделку воронки продаж', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/deals/add'),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Добавить сделку'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: deals.length,
        itemBuilder: (context, index) {
          final deal = deals[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: GlassCard(
              onTap: () => _openDeal(deal),
              padding: const EdgeInsets.all(16),
              borderRadius: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          deal.title,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                        ),
                      ),
                      _statusChip(deal.status),
                    ],
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
                      Text(
                        Formatters.formatUzs(deal.amount),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryBlue),
                      ),
                      if (deal.assignedEmployeeName != null)
                        Row(
                          children: [
                            Icon(Icons.person, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(deal.assignedEmployeeName!, style: AppTextStyles.caption),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildKanbanView(List<DealModel> deals) {
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(12),
      children: DealModel.statusKeys.map((statusKey) {
        final columnDeals = deals.where((d) => d.status == statusKey).toList();
        final double columnTotal = columnDeals.fold(0.0, (sum, d) => sum + d.amount);

        return Container(
          width: 260,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: AppColors.cardBackground.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Column header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground.withOpacity(0.8),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DealModel.statusNames[statusKey] ?? statusKey,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${columnDeals.length}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primaryBlue),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(Formatters.formatUzs(columnTotal), style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              // Deals cards list in this column
              Expanded(
                child: columnDeals.isEmpty
                    ? Center(child: Text('Нет сделок', style: AppTextStyles.caption))
                    : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: columnDeals.length,
                  itemBuilder: (context, idx) {
                    final d = columnDeals[idx];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: GlassCard(
                        onTap: () => _openDeal(d),
                        padding: const EdgeInsets.all(12),
                        borderRadius: 12,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(d.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                            if (d.customerName.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(d.customerName, style: AppTextStyles.caption),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              Formatters.formatUzs(d.amount),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryBlue, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _statusChip(String status) {
    Color bg = AppColors.iconBgBlue;
    Color fg = AppColors.primaryBlue;

    if (status == 'won') {
      bg = AppColors.iconBgGreen;
      fg = AppColors.success;
    } else if (status == 'lost') {
      bg = AppColors.iconBgRed;
      fg = AppColors.error;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(
        DealModel.statusNames[status] ?? status,
        style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(message, style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _reload,
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}
