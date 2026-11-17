import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/di/injection.dart' as di;

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
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize DI
  await di.configureDependencies();

  runApp(const CompanyOsApp());
}

class CompanyOsApp extends StatelessWidget {
  const CompanyOsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (_) => di.getIt<AuthBloc>(),
        ),
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
      child: MaterialApp.router(
        title: 'COMPANY OS',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.light,
        routerConfig: AppRouter.router,
      ),
    );
  }
}
