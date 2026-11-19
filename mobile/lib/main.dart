import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'core/router/app_router.dart';
import 'core/di/injection.dart' as di;
import 'core/network/api_client.dart';
import 'core/services/app_session.dart';
import 'core/services/security_service.dart';

import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'features/finance/presentation/bloc/finance_bloc.dart';
import 'features/inventory/presentation/bloc/inventory_bloc.dart';
import 'features/shipments/presentation/bloc/shipments_bloc.dart';
import 'features/sales/presentation/bloc/sales_bloc.dart';
import 'features/deals/presentation/bloc/deals_bloc.dart';
import 'features/tasks/presentation/bloc/tasks_bloc.dart';
import 'features/messenger/presentation/bloc/messenger_bloc.dart';
import 'features/employees/presentation/bloc/employees_bloc.dart';
import 'features/suppliers/presentation/bloc/suppliers_bloc.dart';
import 'features/customers/presentation/bloc/customers_bloc.dart';
import 'features/reports/presentation/bloc/reports_bloc.dart';
import 'features/documents/presentation/bloc/documents_bloc.dart';
import 'features/notifications/presentation/bloc/notifications_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Status bar styling
  // Saved light/dark choice — must be known before the first frame.
  await ThemeController.instance.load();
  AppColors.isDark = ThemeController.instance.isDark;

  // Status bar styling
  SystemChrome.setSystemUIOverlayStyle(
    AppColors.isDark ? AppTheme.darkOverlayStyle : AppTheme.lightOverlayStyle,
  );

  // Initialize DI
  await di.configureDependencies();

  runApp(const CompanyOsApp());
}

void _rebuildAllChildren(BuildContext context) {
  void rebuild(Element element) {
    element.markNeedsBuild();
    element.visitChildren(rebuild);
  }

  (context as Element).visitChildren(rebuild);
}

class CompanyOsApp extends StatelessWidget {
  const CompanyOsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthBloc>(
      create: (_) => di.getIt<AuthBloc>(),
      child: const _SessionScope(),
    );
  }
}

/// Owns everything that depends on who is signed in: sends the user to the
/// login screen when the session ends, re-locks the app after it was in the
/// background, and gives every session its own fresh set of feature blocs.
class _SessionScope extends StatefulWidget {
  const _SessionScope();

  @override
  State<_SessionScope> createState() => _SessionScopeState();
}

class _SessionScopeState extends State<_SessionScope> with WidgetsBindingObserver {
  static const Duration _relockAfter = Duration(minutes: 2);
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    di.getIt<ApiClient>().onSessionExpired = () {
      if (mounted) context.read<AuthBloc>().add(SessionExpired());
    };
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    di.getIt<ApiClient>().onSessionExpired = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _backgroundedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final since = _backgroundedAt;
      _backgroundedAt = null;
      if (since != null && DateTime.now().difference(since) >= _relockAfter) _relock();
    }
  }

  Future<void> _relock() async {
    if (!di.getIt<ApiClient>().hasSessionCached) return;
    if (!await di.getIt<SecurityService>().isPinSet()) return;
    final location = AppRouter.router.routerDelegate.currentConfiguration.uri.path;
    const open = [AppRoutes.splash, AppRoutes.login, AppRoutes.register, AppRoutes.pinLock, AppRoutes.pinSetup];
    if (!open.contains(location)) AppRouter.router.go(AppRoutes.pinLock);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) => current is AuthUnauthenticated && previous is! AuthInitial && previous is! AuthLoading,
      listener: (context, state) {
        AppSession.instance.restart();
        AppRouter.router.go(AppRoutes.login);
      },
      child: ValueListenableBuilder<int>(
        valueListenable: AppSession.instance,
        builder: (context, session, _) => MultiBlocProvider(
          key: ValueKey<int>(session),
          providers: [
            BlocProvider<DashboardBloc>(
              create: (_) => di.getIt<DashboardBloc>(),
            ),
            BlocProvider<FinanceBloc>(
              create: (_) => di.getIt<FinanceBloc>(),
            ),
            BlocProvider<InventoryBloc>(
              create: (_) => di.getIt<InventoryBloc>(),
            ),
            BlocProvider<ShipmentsBloc>(
              create: (_) => di.getIt<ShipmentsBloc>(),
            ),
            BlocProvider<SalesBloc>(
              create: (_) => di.getIt<SalesBloc>(),
            ),
            BlocProvider<DealsBloc>(
              create: (_) => di.getIt<DealsBloc>(),
            ),
            BlocProvider<TasksBloc>(
              create: (_) => di.getIt<TasksBloc>(),
            ),
            BlocProvider<MessengerBloc>(
              create: (_) => di.getIt<MessengerBloc>(),
            ),
            BlocProvider<EmployeesBloc>(
              create: (_) => di.getIt<EmployeesBloc>(),
            ),
            BlocProvider<SuppliersBloc>(
              create: (_) => di.getIt<SuppliersBloc>(),
            ),
            BlocProvider<CustomersBloc>(
              create: (_) => di.getIt<CustomersBloc>(),
            ),
            BlocProvider<ReportsBloc>(
              create: (_) => di.getIt<ReportsBloc>(),
            ),
            BlocProvider<DocumentsBloc>(
              create: (_) => di.getIt<DocumentsBloc>(),
            ),
            BlocProvider<NotificationsBloc>(
              create: (_) => di.getIt<NotificationsBloc>(),
            ),
          ],
          child: ValueListenableBuilder<ThemeMode>(
        valueListenable: ThemeController.instance,
        builder: (context, mode, _) {
          final isDark = mode == ThemeMode.dark;
          if (AppColors.isDark != isDark) {
            AppColors.isDark = isDark;
            SystemChrome.setSystemUIOverlayStyle(
              isDark ? AppTheme.darkOverlayStyle : AppTheme.lightOverlayStyle,
            );
            // Widgets read AppColors.* directly (no Theme.of dependency), and
            // many are const instances that Flutter would skip. Mark every
            // mounted element dirty so the whole tree repaints in the new
            // palette while keeping navigation and widget state.
            _rebuildAllChildren(context);
          }
          // Only the active theme is built: the AppColors tokens resolve
          // against AppColors.isDark, so the other one would be wrong.
          return MaterialApp.router(
            title: 'Opero',
            debugShowCheckedModeBanner: false,
            theme: isDark ? AppTheme.dark : AppTheme.light,
            themeMode: mode,
            routerConfig: AppRouter.router,
          );
        },
      ),
        ),
      ),
    );
  }
}
