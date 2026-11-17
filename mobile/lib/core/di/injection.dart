import 'package:get_it/get_it.dart';
import '../network/api_client.dart';

// Auth & Dashboard
import '../../features/auth/data/repositories/auth_repository.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/dashboard/data/repositories/dashboard_repository.dart';
import '../../features/dashboard/presentation/bloc/dashboard_bloc.dart';

// Finance
import '../../features/finance/data/repositories/finance_repository.dart';
import '../../features/finance/presentation/bloc/finance_bloc.dart';

// Inventory
import '../../features/inventory/data/repositories/inventory_repository.dart';
import '../../features/inventory/presentation/bloc/inventory_bloc.dart';

// Shipments
import '../../features/shipments/data/repositories/shipments_repository.dart';
import '../../features/shipments/presentation/bloc/shipments_bloc.dart';

// Sales
import '../../features/sales/data/repositories/sales_repository.dart';
import '../../features/sales/presentation/bloc/sales_bloc.dart';

// Deals
import '../../features/deals/data/repositories/deals_repository.dart';
import '../../features/deals/presentation/bloc/deals_bloc.dart';

// Tasks
import '../../features/tasks/data/repositories/tasks_repository.dart';
import '../../features/tasks/presentation/bloc/tasks_bloc.dart';

// Messenger
import '../../features/messenger/data/repositories/messenger_repository.dart';
import '../../features/messenger/presentation/bloc/messenger_bloc.dart';

// Employees
import '../../features/employees/data/repositories/employees_repository.dart';
import '../../features/employees/presentation/bloc/employees_bloc.dart';

// Suppliers
import '../../features/suppliers/data/repositories/suppliers_repository.dart';
import '../../features/suppliers/presentation/bloc/suppliers_bloc.dart';

// Customers
import '../../features/customers/data/repositories/customers_repository.dart';
import '../../features/customers/presentation/bloc/customers_bloc.dart';

// Reports
import '../../features/reports/data/repositories/reports_repository.dart';
import '../../features/reports/presentation/bloc/reports_bloc.dart';

// Documents
import '../../features/documents/data/repositories/documents_repository.dart';
import '../../features/documents/presentation/bloc/documents_bloc.dart';
import '../../features/companies/data/repositories/company_repository.dart';

// Notifications
import '../../features/notifications/data/repositories/notifications_repository.dart';
import '../../features/notifications/presentation/bloc/notifications_bloc.dart';
import '../services/security_service.dart';
import '../services/app_update_service.dart';

final GetIt getIt = GetIt.instance;

Future<void> configureDependencies() async {
  // Services & Network
  getIt.registerLazySingleton<ApiClient>(() => ApiClient());
  getIt.registerLazySingleton<SecurityService>(() => SecurityService());
  getIt.registerLazySingleton<AppUpdateService>(() => AppUpdateService(apiClient: getIt<ApiClient>()));

  // Repositories
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepository(apiClient: getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<DashboardRepository>(
    () => DashboardRepository(apiClient: getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<FinanceRepository>(
    () => FinanceRepository(apiClient: getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<InventoryRepository>(
    () => InventoryRepository(apiClient: getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<ShipmentsRepository>(
    () => ShipmentsRepository(apiClient: getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<SalesRepository>(
    () => SalesRepository(apiClient: getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<DealsRepository>(
    () => DealsRepository(apiClient: getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<TasksRepository>(
    () => TasksRepository(apiClient: getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<MessengerRepository>(
    () => MessengerRepository(apiClient: getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<EmployeesRepository>(
    () => EmployeesRepository(apiClient: getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<SuppliersRepository>(
    () => SuppliersRepository(apiClient: getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<CustomersRepository>(
    () => CustomersRepository(apiClient: getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<ReportsRepository>(
    () => ReportsRepository(apiClient: getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<DocumentsRepository>(
    () => DocumentsRepository(apiClient: getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<NotificationsRepository>(
    () => NotificationsRepository(apiClient: getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<CompanyRepository>(
    () => CompanyRepository(apiClient: getIt<ApiClient>()),
  );

  // BLoCs
  getIt.registerFactory<AuthBloc>(
    () => AuthBloc(authRepository: getIt<AuthRepository>()),
  );
  getIt.registerFactory<DashboardBloc>(
    () => DashboardBloc(dashboardRepository: getIt<DashboardRepository>()),
  );
  getIt.registerFactory<FinanceBloc>(
    () => FinanceBloc(financeRepository: getIt<FinanceRepository>()),
  );
  getIt.registerFactory<InventoryBloc>(
    () => InventoryBloc(inventoryRepository: getIt<InventoryRepository>()),
  );
  getIt.registerFactory<ShipmentsBloc>(
    () => ShipmentsBloc(shipmentsRepository: getIt<ShipmentsRepository>()),
  );
  getIt.registerFactory<SalesBloc>(
    () => SalesBloc(salesRepository: getIt<SalesRepository>()),
  );
  getIt.registerFactory<DealsBloc>(
    () => DealsBloc(dealsRepository: getIt<DealsRepository>()),
  );
  getIt.registerFactory<TasksBloc>(
    () => TasksBloc(tasksRepository: getIt<TasksRepository>()),
  );
  getIt.registerFactory<MessengerBloc>(
    () => MessengerBloc(messengerRepository: getIt<MessengerRepository>()),
  );
  getIt.registerFactory<EmployeesBloc>(
    () => EmployeesBloc(employeesRepository: getIt<EmployeesRepository>()),
  );
  getIt.registerFactory<SuppliersBloc>(
    () => SuppliersBloc(suppliersRepository: getIt<SuppliersRepository>()),
  );
  getIt.registerFactory<CustomersBloc>(
    () => CustomersBloc(customersRepository: getIt<CustomersRepository>()),
  );
  getIt.registerFactory<ReportsBloc>(
    () => ReportsBloc(reportsRepository: getIt<ReportsRepository>()),
  );
  getIt.registerFactory<DocumentsBloc>(
    () => DocumentsBloc(documentsRepository: getIt<DocumentsRepository>()),
  );
  getIt.registerFactory<NotificationsBloc>(
    () => NotificationsBloc(notificationsRepository: getIt<NotificationsRepository>()),
  );
}
