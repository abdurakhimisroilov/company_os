import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/bottom_nav_bar.dart';
import '../../../../core/widgets/gradient_header_card.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../../../../core/widgets/metric_card.dart';
import '../../../../core/widgets/nav_menu_item.dart';
import '../bloc/dashboard_bloc.dart';
import '../../data/models/dashboard_stats_model.dart';
import '../../../notifications/presentation/bloc/notifications_bloc.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/services/app_session.dart';
import '../../../../core/services/app_update_service.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../finance/data/company_currency.dart';
import '../../../companies/data/models/company_model.dart';
import '../../../companies/data/repositories/company_repository.dart';
import '../../../companies/presentation/widgets/company_selector_sheet.dart';
import '../../../../core/services/push_service.dart';
import '../../../../core/network/api_client.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _currentNavIndex = 0;
  String _selectedPeriod = 'month';
  CompanyModel? _currentCompany;
  bool _companyLoadFailed = false;

  final List<_PeriodOption> _periods = const [
    _PeriodOption(label: 'Сегодня', value: 'today', changeLabel: 'за сегодня'),
    _PeriodOption(label: 'Неделя', value: 'week', changeLabel: 'за неделю'),
    _PeriodOption(label: 'Месяц', value: 'month', changeLabel: 'с начала месяца'),
    _PeriodOption(label: 'Год', value: 'year', changeLabel: 'с начала года'),
  ];

  @override
  void initState() {
    super.initState();
    AppSession.instance.addListener(_onSessionChanged);
    PushService.instance.received.addListener(_onPushReceived);
    PushService.instance.opened.addListener(_onPushOpened);
    _notificationsSub = context.read<NotificationsBloc>().stream.listen((state) {
      if (state is NotificationsLoaded) PushService.instance.setBadge(state.unreadCount);
    });
    _reloadAll();
    WidgetsBinding.instance.addPostFrameCallback((_) => _enablePush());
    // The in-app updater installs an APK, which only exists on Android.
    if (defaultTargetPlatform == TargetPlatform.android) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          getIt<AppUpdateService>().showUpdatePrompt(context);
        }
      });
    }
  }

  @override
  void dispose() {
    AppSession.instance.removeListener(_onSessionChanged);
    PushService.instance.received.removeListener(_onPushReceived);
    PushService.instance.opened.removeListener(_onPushOpened);
    _notificationsSub?.cancel();
    super.dispose();
  }

  StreamSubscription<NotificationsState>? _notificationsSub;

  /// Registers this phone for notifications unless the user switched them off.
  Future<void> _enablePush() async {
    if (!mounted || !await PushService.instance.isEnabledLocally()) return;
    try {
      await PushService.instance.enable(getIt<ApiClient>());
    } catch (e) {
      debugPrint('[Dashboard] push registration failed: $e');
    }
  }

  /// A push arrived while the app is open: the figures it reports changed too.
  void _onPushReceived() {
    if (mounted) _refresh();
  }

  void _onPushOpened() {
    if (!mounted) return;
    context.read<NotificationsBloc>().add(LoadNotificationsEvent());
    context.push(AppRoutes.notifications);
  }

  /// Sign-in, sign-out or another organization: everything shown is stale.
  void _onSessionChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _currentCompany = null;
        _companyLoadFailed = false;
      });
      _reloadAll();
    });
  }

  void _reloadAll() {
    _loadCurrentCompany();
    context.read<DashboardBloc>().add(LoadDashboardStats(period: _selectedPeriod));
    context.read<NotificationsBloc>().add(LoadNotificationsEvent());
  }

  /// Re-reads everything without hiding the content; resolves when the figures have arrived.
  Future<void> _refresh() async {
    final done = Completer<void>();
    context.read<DashboardBloc>().add(RefreshDashboardStats(period: _selectedPeriod, done: done));
    context.read<NotificationsBloc>().add(LoadNotificationsEvent());
    await Future.wait([done.future, _loadCurrentCompany()]);
  }

  Future<void> _loadCurrentCompany() async {
    final session = AppSession.instance.value;
    try {
      final comp = await getIt<CompanyRepository>().getCurrentCompany();
      if (!mounted || session != AppSession.instance.value) return;
      final hasCompany = comp.id.isNotEmpty;
      if (hasCompany) CompanyCurrency.instance.set(comp.currency);
      setState(() {
        _currentCompany = hasCompany ? comp : null;
        _companyLoadFailed = false;
      });
    } catch (_) {
      if (!mounted || session != AppSession.instance.value) return;
      setState(() => _companyLoadFailed = true);
    }
  }

  void _onPeriodChanged(String period) {
    if (period == _selectedPeriod) return;
    setState(() => _selectedPeriod = period);
    context.read<DashboardBloc>().add(LoadDashboardStats(period: period));
  }

  /// Opens a screen and refreshes the dashboard when the user comes back, so
  /// whatever was added or changed there is reflected immediately.
  Future<void> _open(String route) async {
    await context.push(route);
    if (mounted) _refresh();
  }

  Future<void> _onNavTap(int index) async {
    const routes = {1: AppRoutes.inventory, 3: AppRoutes.tasks, 4: AppRoutes.settings};
    final route = routes[index];
    if (route == null) return;
    setState(() => _currentNavIndex = index);
    await context.push(route);
    if (!mounted) return;
    setState(() => _currentNavIndex = 0);
    _refresh();
  }

  void _onFabTap() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _QuickActionSheet(onOpen: _open),
    );
  }

  String get _subtitle {
    if (_currentCompany != null) return 'Организация • Сменить';
    if (_companyLoadFailed) return 'Организация не загружена • Выбрать';
    return 'Бизнес-система';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: BlocConsumer<DashboardBloc, DashboardState>(
                  listenWhen: (previous, current) =>
                      current is DashboardLoaded &&
                      current.notice != null &&
                      (previous is! DashboardLoaded || previous.noticeId != current.noticeId),
                  listener: (context, state) {
                    if (state is DashboardLoaded && state.notice != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(state.notice!), backgroundColor: AppColors.error),
                      );
                    }
                  },
                  builder: (context, state) {
                    if (state is DashboardError) {
                      return _buildErrorState(state.message);
                    }
                    if (state is DashboardLoaded) {
                      // The currency label arrives with the organization.
                      return ValueListenableBuilder<String>(
                        valueListenable: CompanyCurrency.instance,
                        builder: (context, _, __) => _buildContent(state),
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
          // Opero brand mark & Interactive Company Switcher
          Expanded(
            child: InkWell(
              onTap: () {
                CompanySelectorSheet.show(
                  context,
                  currentCompany: _currentCompany,
                  onCompanySelected: (company) {
                    if (!mounted) return;
                    CompanyCurrency.instance.set(company.currency);
                    setState(() {
                      _currentCompany = company;
                      _companyLoadFailed = false;
                    });
                    _reloadAll();
                  },
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const AppLogo(size: 38, borderRadius: 10, shadowOpacity: 0.2, shadowBlur: 8, shadowOffsetY: 3),
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
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 18,
                                color: AppColors.textSecondary,
                              ),
                            ],
                          ),
                          Text(
                            _subtitle,
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
                onTap: () => _open(AppRoutes.notifications),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
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

  Widget _buildContent(DashboardLoaded state) {
    final DashboardStatsModel stats = state.stats;
    final shownPeriod = _periods.firstWhere((p) => p.value == state.activePeriod, orElse: () => _periods[2]);
    final hasDebts = stats.customerDebts > 0 || stats.supplierDebts > 0;

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.primaryBlue,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          // Period selector filter chips
          _buildPeriodSelector(),
          SizedBox(
            height: 16,
            child: state.isUpdating
                ? const Center(child: LinearProgressIndicator(minHeight: 2, color: AppColors.primaryBlue))
                : null,
          ),

          // Main Blue-Purple Gradient Header Card
          GradientHeaderCard(
            label: AppStrings.generalResult,
            value: money(stats.totalBalance),
            subtitle: AppStrings.totalBalance,
            changePercent: stats.balanceChangePercent,
            changeLabel: shownPeriod.changeLabel,
            isPositive: stats.balanceChangePercent >= 0,
            onTap: () => _open(AppRoutes.finance),
          ),
          const SizedBox(height: 20),

          // 2x2 Metric Grid (Поступления, Расходы, Продажи, Остатки на складе)
          Row(
            children: [
              Expanded(
                child: MetricCard(
                  label: AppStrings.income,
                  value: moneyCompact(stats.income),
                  icon: Icons.arrow_downward_rounded,
                  iconColor: AppColors.success,
                  iconBgColor: AppColors.iconBgGreen,
                  valueColor: AppColors.success,
                  onTap: () => _open(AppRoutes.finance),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MetricCard(
                  label: AppStrings.expenses,
                  value: moneyCompact(stats.expenses),
                  icon: Icons.arrow_upward_rounded,
                  iconColor: AppColors.error,
                  iconBgColor: AppColors.iconBgRed,
                  valueColor: AppColors.error,
                  onTap: () => _open(AppRoutes.finance),
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
                  value: moneyCompact(stats.sales),
                  icon: Icons.shopping_bag_outlined,
                  iconColor: AppColors.primaryBlue,
                  iconBgColor: AppColors.iconBgBlue,
                  onTap: () => _open(AppRoutes.sales),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MetricCard(
                  label: AppStrings.stockBalance,
                  value: moneyCompact(stats.stockBalance),
                  icon: Icons.inventory_2_outlined,
                  iconColor: AppColors.secondaryLavender,
                  iconBgColor: AppColors.iconBgPurple,
                  onTap: () => _open(AppRoutes.inventory),
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
            subtitle: 'Товаров в каталоге: ${stats.totalProducts}',
            icon: Icons.inventory_2_rounded,
            iconColor: AppColors.primaryBlue,
            iconBgColor: AppColors.iconBgBlue,
            onTap: () => _open(AppRoutes.inventory),
          ),
          const SizedBox(height: 10),
          NavMenuItem(
            title: 'Поставки',
            subtitle: 'Приход товара от поставщиков',
            icon: Icons.local_shipping_rounded,
            iconColor: AppColors.secondaryLavender,
            iconBgColor: AppColors.iconBgPurple,
            onTap: () => _open(AppRoutes.incomingGoods),
          ),
          const SizedBox(height: 10),
          NavMenuItem(
            title: 'Продажи',
            subtitle: 'Чеки, оплаты и возвраты',
            icon: Icons.shopping_bag_rounded,
            iconColor: AppColors.primaryBlue,
            iconBgColor: AppColors.iconBgBlue,
            onTap: () => _open(AppRoutes.sales),
          ),
          const SizedBox(height: 10),
          NavMenuItem(
            title: AppStrings.dealsAndClients,
            subtitle: '${stats.activeDeals} активных сделок',
            icon: Icons.people_alt_rounded,
            iconColor: AppColors.secondaryLavender,
            iconBgColor: AppColors.iconBgPurple,
            badge: stats.activeDeals > 0 ? stats.activeDeals : null,
            onTap: () => _open(AppRoutes.deals),
          ),
          const SizedBox(height: 10),
          NavMenuItem(
            title: 'Клиенты',
            subtitle: stats.customerDebts > 0 ? 'Нам должны: ${money(stats.customerDebts)}' : 'База клиентов и их покупки',
            icon: Icons.groups_rounded,
            iconColor: AppColors.success,
            iconBgColor: AppColors.iconBgGreen,
            onTap: () => _open(AppRoutes.customers),
          ),
          const SizedBox(height: 10),
          NavMenuItem(
            title: 'Поставщики',
            subtitle: stats.supplierDebts > 0 ? 'Мы должны: ${money(stats.supplierDebts)}' : 'Контакты и история поставок',
            icon: Icons.factory_rounded,
            iconColor: const Color(0xFFF59E0B),
            iconBgColor: AppColors.iconBgOrange,
            onTap: () => _open(AppRoutes.suppliers),
          ),
          const SizedBox(height: 10),
          NavMenuItem(
            title: AppStrings.finance,
            subtitle: hasDebts ? 'Касса, счета, операции и долги' : 'Касса, счета и транзакции',
            icon: Icons.account_balance_wallet_rounded,
            iconColor: AppColors.success,
            iconBgColor: AppColors.iconBgGreen,
            onTap: () => _open(AppRoutes.finance),
          ),
          const SizedBox(height: 10),
          NavMenuItem(
            title: AppStrings.reportsAndAnalytics,
            subtitle: 'Финансы и продажи за период',
            icon: Icons.bar_chart_rounded,
            iconColor: const Color(0xFFF59E0B),
            iconBgColor: AppColors.iconBgOrange,
            onTap: () => _open(AppRoutes.reports),
          ),
          const SizedBox(height: 10),
          NavMenuItem(
            title: AppStrings.tasks,
            subtitle: '${stats.pendingTasks} требуют внимания',
            icon: Icons.assignment_turned_in_rounded,
            iconColor: const Color(0xFF06B6D4),
            iconBgColor: AppColors.iconBgTeal,
            badge: stats.pendingTasks > 0 ? stats.pendingTasks : null,
            onTap: () => _open(AppRoutes.tasks),
          ),
          const SizedBox(height: 10),
          NavMenuItem(
            title: 'Документы',
            subtitle: 'Договоры, акты и файлы компании',
            icon: Icons.folder_copy_rounded,
            iconColor: AppColors.primaryBlue,
            iconBgColor: AppColors.iconBgBlue,
            onTap: () => _open(AppRoutes.documents),
          ),
          const SizedBox(height: 10),
          NavMenuItem(
            title: 'Мессенджер',
            subtitle: 'Переписка с сотрудниками',
            icon: Icons.chat_bubble_rounded,
            iconColor: const Color(0xFF06B6D4),
            iconBgColor: AppColors.iconBgTeal,
            onTap: () => _open(AppRoutes.messenger),
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
                color: isSelected ? AppColors.primaryBlue : AppColors.cardBackground.withOpacity(0.85),
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
              onPressed: _reloadAll,
              child: const Text('Повторить'),
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

  /// What the balance change percentage is measured against.
  final String changeLabel;
  const _PeriodOption({required this.label, required this.value, required this.changeLabel});
}

class _QuickActionSheet extends StatelessWidget {
  const _QuickActionSheet({required this.onOpen});

  /// Opens the chosen screen from the dashboard, which refreshes on return.
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
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
                  onOpen(AppRoutes.salesAdd);
                },
              ),
              _ActionItem(
                icon: Icons.trending_up_rounded,
                label: 'Поступление',
                color: AppColors.success,
                onTap: () {
                  Navigator.pop(context);
                  onOpen(AppRoutes.financeIncomeAdd);
                },
              ),
              _ActionItem(
                icon: Icons.trending_down_rounded,
                label: 'Расход',
                color: AppColors.error,
                onTap: () {
                  Navigator.pop(context);
                  onOpen(AppRoutes.financeExpenseAdd);
                },
              ),
              _ActionItem(
                icon: Icons.assignment_add,
                label: 'Задание',
                color: AppColors.secondaryLavender,
                onTap: () {
                  Navigator.pop(context);
                  onOpen(AppRoutes.taskAdd);
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
