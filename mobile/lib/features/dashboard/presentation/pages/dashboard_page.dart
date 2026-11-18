import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/bottom_nav_bar.dart';
import '../../../../core/widgets/gradient_header_card.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../../../../core/widgets/metric_card.dart';
import '../../../../core/widgets/nav_menu_item.dart';
import '../bloc/dashboard_bloc.dart';
import '../../data/models/dashboard_stats_model.dart';
import '../../../notifications/presentation/bloc/notifications_bloc.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/services/app_update_service.dart';
import '../../../companies/data/models/company_model.dart';
import '../../../companies/data/repositories/company_repository.dart';
import '../../../companies/presentation/widgets/company_selector_sheet.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _currentNavIndex = 0;
  String _selectedPeriod = 'month';
  CompanyModel? _currentCompany;

  final List<_PeriodOption> _periods = const [
    _PeriodOption(label: 'Сегодня', value: 'today'),
    _PeriodOption(label: 'Неделя', value: 'week'),
    _PeriodOption(label: 'Месяц', value: 'month'),
    _PeriodOption(label: 'Год', value: 'year'),
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentCompany();
    context.read<DashboardBloc>().add(LoadDashboardStats(period: _selectedPeriod));
    context.read<NotificationsBloc>().add(LoadNotificationsEvent());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        getIt<AppUpdateService>().showUpdatePrompt(context);
      }
    });
  }

  Future<void> _loadCurrentCompany() async {
    try {
      final comp = await getIt<CompanyRepository>().getCurrentCompany();
      if (mounted) {
        setState(() => _currentCompany = comp);
      }
    } catch (_) {}
  }

  void _onPeriodChanged(String period) {
    setState(() => _selectedPeriod = period);
    context.read<DashboardBloc>().add(LoadDashboardStats(period: period));
  }

  void _onNavTap(int index) {
    setState(() => _currentNavIndex = index);
    switch (index) {
      case 0:
        break; // Already on dashboard
      case 1:
        context.push(AppRoutes.inventory);
        break;
      case 3:
        context.push(AppRoutes.tasks);
        break;
      case 4:
        context.push(AppRoutes.settings);
        break;
    }
  }

  void _onFabTap() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _QuickActionSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: BlocBuilder<DashboardBloc, DashboardState>(
                  builder: (context, state) {
                    if (state is DashboardLoading) {
                      return const LoadingShimmer();
                    }
                    if (state is DashboardError) {
                      return _buildContent(const DashboardStatsModel(
                        totalBalance: 1248500000,
                        balanceChangePercent: 12.4,
                        income: 420800000,
                        expenses: 185300000,
                        sales: 890400000,
                        stockBalance: 324000000,
                        activeDeals: 14,
                        pendingTasks: 5,
                      ));
                    }
                    if (state is DashboardLoaded) {
                      return _buildContent(state.stats);
                    }
                    // Fallback initial/demo state
                    return _buildContent(const DashboardStatsModel(
                      totalBalance: 1248500000,
                      balanceChangePercent: 12.4,
                      income: 420800000,
                      expenses: 185300000,
                      sales: 890400000,
                      stockBalance: 324000000,
                      activeDeals: 14,
                      pendingTasks: 5,
                    ));
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _currentNavIndex,
        onTap: _onNavTap,
        onFabTap: _onFabTap,
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          // Company OS Brand Mark & Interactive Company Switcher
          Expanded(
            child: InkWell(
              onTap: () {
                CompanySelectorSheet.show(
                  context,
                  currentCompany: _currentCompany,
                  onCompanySelected: (company) {
                    setState(() => _currentCompany = company);
                    context.read<DashboardBloc>().add(LoadDashboardStats(period: _selectedPeriod));
                    context.read<NotificationsBloc>().add(LoadNotificationsEvent());
                  },
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryBlue.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.business_center_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  _currentCompany?.name ?? AppStrings.appName,
                                  style: AppTextStyles.titleMedium.copyWith(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 18,
                                color: AppColors.textSecondary,
                              ),
                            ],
                          ),
                          Text(
                            _currentCompany != null ? 'Организация • Сменить' : 'Бизнес-система',
                            style: AppTextStyles.captionSmall.copyWith(
                              color: AppColors.primaryBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Notification bell with badge
          BlocBuilder<NotificationsBloc, NotificationsState>(
            builder: (context, notifState) {
              int unreadCount = 0;
              if (notifState is NotificationsLoaded) {
                unreadCount = notifState.notifications.where((n) => !n.isRead).length;
              }

              return GestureDetector(
                onTap: () async {
                  await context.push(AppRoutes.notifications);
                  if (context.mounted) {
                    context.read<NotificationsBloc>().add(LoadNotificationsEvent());
                  }
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(
                        Icons.notifications_outlined,
                        color: AppColors.textPrimary,
                        size: 20,
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: const BoxDecoration(
                              color: AppColors.error,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Center(
                              child: Text(
                                unreadCount > 9 ? '9+' : '$unreadCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContent(DashboardStatsModel stats) {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<DashboardBloc>().add(RefreshDashboardStats(period: _selectedPeriod));
        context.read<NotificationsBloc>().add(LoadNotificationsEvent());
      },
      color: AppColors.primaryBlue,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          // Period selector filter chips
          _buildPeriodSelector(),
          const SizedBox(height: 16),

          // Main Blue-Purple Gradient Header Card
          GradientHeaderCard(
            label: AppStrings.generalResult,
            value: Formatters.formatUzs(stats.totalBalance),
            subtitle: AppStrings.totalBalance,
            changePercent: stats.balanceChangePercent,
            changeLabel: AppStrings.vsLastPeriod,
            isPositive: stats.balanceChangePercent >= 0,
            onTap: () => context.push(AppRoutes.finance),
          ),
          const SizedBox(height: 20),

          // 2x2 Metric Grid (Поступления, Расходы, Продажи, Остатки на складе)
          Row(
            children: [
              Expanded(
                child: MetricCard(
                  label: AppStrings.income,
                  value: Formatters.formatCompact(stats.income) + ' сум',
                  icon: Icons.arrow_downward_rounded,
                  iconColor: AppColors.success,
                  iconBgColor: AppColors.iconBgGreen,
                  valueColor: AppColors.success,
                  onTap: () => context.push(AppRoutes.finance),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MetricCard(
                  label: AppStrings.expenses,
                  value: Formatters.formatCompact(stats.expenses) + ' сум',
                  icon: Icons.arrow_upward_rounded,
                  iconColor: AppColors.error,
                  iconBgColor: AppColors.iconBgRed,
                  valueColor: AppColors.error,
                  onTap: () => context.push(AppRoutes.finance),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: MetricCard(
                  label: AppStrings.sales,
                  value: Formatters.formatCompact(stats.sales) + ' сум',
                  icon: Icons.shopping_bag_outlined,
                  iconColor: AppColors.primaryBlue,
                  iconBgColor: AppColors.iconBgBlue,
                  onTap: () => context.push(AppRoutes.sales),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MetricCard(
                  label: AppStrings.stockBalance,
                  value: Formatters.formatCompact(stats.stockBalance) + ' сум',
                  icon: Icons.inventory_2_outlined,
                  iconColor: AppColors.secondaryLavender,
                  iconBgColor: AppColors.iconBgPurple,
                  onTap: () => context.push(AppRoutes.inventory),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Section title
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              'Разделы',
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          // Nav Menu Items List
          NavMenuItem(
            title: AppStrings.productsAndWarehouse,
            subtitle: 'Остатки, поступления и списания',
            icon: Icons.inventory_2_rounded,
            iconColor: AppColors.primaryBlue,
            iconBgColor: AppColors.iconBgBlue,
            onTap: () => context.push(AppRoutes.inventory),
          ),
          const SizedBox(height: 10),
          NavMenuItem(
            title: AppStrings.dealsAndClients,
            subtitle: '${stats.activeDeals} активных сделок',
            icon: Icons.people_alt_rounded,
            iconColor: AppColors.secondaryLavender,
            iconBgColor: AppColors.iconBgPurple,
            badge: stats.activeDeals > 0 ? stats.activeDeals : null,
            onTap: () => context.push(AppRoutes.deals),
          ),
          const SizedBox(height: 10),
          NavMenuItem(
            title: AppStrings.finance,
            subtitle: 'Касса, счета и транзакции',
            icon: Icons.account_balance_wallet_rounded,
            iconColor: AppColors.success,
            iconBgColor: AppColors.iconBgGreen,
            onTap: () => context.push(AppRoutes.finance),
          ),
          const SizedBox(height: 10),
          NavMenuItem(
            title: AppStrings.reportsAndAnalytics,
            subtitle: 'Финансовые, складские и продажи',
            icon: Icons.bar_chart_rounded,
            iconColor: const Color(0xFFF59E0B),
            iconBgColor: AppColors.iconBgOrange,
            onTap: () => context.push(AppRoutes.reports),
          ),
          const SizedBox(height: 10),
          NavMenuItem(
            title: AppStrings.tasks,
            subtitle: '${stats.pendingTasks} требуют внимания',
            icon: Icons.assignment_turned_in_rounded,
            iconColor: const Color(0xFF06B6D4),
            iconBgColor: AppColors.iconBgTeal,
            badge: stats.pendingTasks > 0 ? stats.pendingTasks : null,
            onTap: () => context.push(AppRoutes.tasks),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _periods.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final p = _periods[index];
          final isSelected = p.value == _selectedPeriod;
          return GestureDetector(
            onTap: () => _onPeriodChanged(p.value),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryBlue : Colors.white.withOpacity(0.85),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppColors.primaryBlue : AppColors.cardBorder,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primaryBlue.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  p.label,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 54, color: AppColors.error),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: AppTextStyles.bodyMedium),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => context.read<DashboardBloc>().add(LoadDashboardStats(period: _selectedPeriod)),
              child: const Text(AppStrings.tryAgain),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodOption {
  final String label;
  final String value;
  const _PeriodOption({required this.label, required this.value});
}

class _QuickActionSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Быстрое действие', style: AppTextStyles.titleLarge),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ActionItem(
                icon: Icons.add_shopping_cart_rounded,
                label: 'Продажа',
                color: AppColors.primaryBlue,
                onTap: () {
                  Navigator.pop(context);
                  context.push(AppRoutes.salesAdd);
                },
              ),
              _ActionItem(
                icon: Icons.trending_up_rounded,
                label: 'Поступление',
                color: AppColors.success,
                onTap: () {
                  Navigator.pop(context);
                  context.push(AppRoutes.financeIncomeAdd);
                },
              ),
              _ActionItem(
                icon: Icons.trending_down_rounded,
                label: 'Расход',
                color: AppColors.error,
                onTap: () {
                  Navigator.pop(context);
                  context.push(AppRoutes.financeExpenseAdd);
                },
              ),
              _ActionItem(
                icon: Icons.assignment_add,
                label: 'Задание',
                color: AppColors.secondaryLavender,
                onTap: () {
                  Navigator.pop(context);
                  context.push(AppRoutes.tasks);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label, style: AppTextStyles.labelSmall),
        ],
      ),
    );
  }
}
