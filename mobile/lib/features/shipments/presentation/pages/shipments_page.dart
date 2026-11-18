import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../bloc/shipments_bloc.dart';
import '../../data/models/shipment_model.dart';

class ShipmentsPage extends StatefulWidget {
  const ShipmentsPage({super.key});

  @override
  State<ShipmentsPage> createState() => _ShipmentsPageState();
}

class _ShipmentsPageState extends State<ShipmentsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _filters = ['all', 'pending', 'received'];
  final List<String> _filterLabels = ['Все', 'Ожидаются', 'Получено'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _filters.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) _load();
    });
    context.read<ShipmentsBloc>().add(const LoadShipmentsEvent());
  }

  void _load() {
    context.read<ShipmentsBloc>().add(LoadShipmentsEvent(status: _filters[_tabController.index]));
  }

  Future<void> _refresh() async {
    final error = await context.read<ShipmentsBloc>().refresh();
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.error),
      );
    }
  }

  /// Opens a page that may change shipments and brings the list up to date afterwards.
  Future<void> _openAndRefresh(String location) async {
    await context.push(location);
    if (!mounted) return;
    context.read<ShipmentsBloc>().add(const RefreshShipmentsEvent());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
              _buildTabBar(),
              Expanded(
                child: BlocBuilder<ShipmentsBloc, ShipmentsState>(
                  builder: (context, state) {
                    if (state is ShipmentsError) {
                      return _buildErrorState(state.message);
                    }
                    if (state is ShipmentsLoaded) {
                      return Column(
                        children: [
                          SizedBox(
                            height: 2,
                            child: state.isLoading ? const LinearProgressIndicator(minHeight: 2) : null,
                          ),
                          Expanded(child: _buildContent(state)),
                        ],
                      );
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
        onPressed: () => _openAndRefresh('/incoming-goods/add'),
        backgroundColor: AppColors.primaryBlue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Поставка', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
              'Поступление товаров',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: AppColors.primaryBlue,
        ),
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        tabs: _filterLabels.map((l) => Tab(text: l)).toList(),
      ),
    );
  }

  Widget _buildContent(ShipmentsLoaded state) {
    final shipments = state.shipments;
    if (shipments.isEmpty && state.isLoading) {
      return const SizedBox.expand();
    }
    if (shipments.isEmpty) {
      final isFiltered = state.currentFilter != 'all';
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 60),
          children: [
            Center(
              child: Column(
                children: [
                  Icon(Icons.local_shipping_outlined, size: 56, color: AppColors.textTertiary),
                  const SizedBox(height: 12),
                  Text(
                    isFiltered ? 'Поставок с таким статусом нет' : 'Данных пока нет',
                    style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary),
                  ),
                  if (!isFiltered) ...[
                    const SizedBox(height: 6),
                    Text('Оформите первое поступление товаров на склад', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _openAndRefresh('/incoming-goods/add'),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Оформить поставку'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: shipments.length,
        itemBuilder: (context, index) {
          final shipment = shipments[index];
          return _buildShipmentCard(shipment);
        },
      ),
    );
  }

  Widget _buildShipmentCard(ShipmentModel shipment) {
    Color statusColor;
    Color statusBg;
    String statusLabel;

    if (shipment.status == 'received') {
      statusColor = AppColors.success;
      statusBg = AppColors.iconBgGreen;
      statusLabel = 'Получено';
    } else if (shipment.status == 'cancelled') {
      statusColor = AppColors.error;
      statusBg = AppColors.iconBgRed;
      statusLabel = 'Отменена';
    } else {
      statusColor = AppColors.primaryBlue;
      statusBg = AppColors.iconBgBlue;
      statusLabel = 'Ожидается';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        onTap: () => _openAndRefresh('/incoming-goods/${shipment.id}'),
        padding: const EdgeInsets.all(16),
        borderRadius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.iconBgBlue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.local_shipping, color: AppColors.primaryBlue, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shipment.supplierLabel,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text('Накладная: ${shipment.invoiceNumber}', style: AppTextStyles.caption),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    statusLabel,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(_cardDate(shipment), style: AppTextStyles.caption),
                  ],
                ),
                Text(
                  Formatters.formatUzs(shipment.grandTotal),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _cardDate(ShipmentModel shipment) {
    if (shipment.isReceived && shipment.receivedDate != null) {
      return 'Принято ${Formatters.formatDate(shipment.receivedDate!.toLocal())}';
    }
    if (shipment.expectedDate != null) {
      return 'Ожидается ${Formatters.formatDate(shipment.expectedDate!.toLocal())}';
    }
    return '';
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(message, style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _load,
            child: const Text('Повторить'),
          ),
        ],
      ),
    );
  }
}
