import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../di/injection.dart';
import '../network/api_client.dart';
import '../services/security_service.dart';

// Auth & Dashboard
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/pin_setup_page.dart';
import '../../features/auth/presentation/pages/pin_lock_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';

// Finance
import '../../features/finance/presentation/pages/finance_page.dart';
import '../../features/finance/presentation/pages/add_income_page.dart';
import '../../features/finance/presentation/pages/add_expense_page.dart';
import '../../features/finance/presentation/pages/accounts_page.dart';
import '../../features/finance/presentation/pages/debts_page.dart';

// Inventory
import '../../features/inventory/presentation/pages/inventory_page.dart';
import '../../features/inventory/presentation/pages/product_detail_page.dart';
import '../../features/inventory/presentation/pages/add_product_page.dart';
import '../../features/inventory/presentation/pages/stock_adjustment_page.dart';

// Shipments
import '../../features/shipments/presentation/pages/shipments_page.dart';
import '../../features/shipments/presentation/pages/add_shipment_page.dart';
import '../../features/shipments/presentation/pages/shipment_detail_page.dart';

// Sales
import '../../features/sales/presentation/pages/sales_page.dart';
import '../../features/sales/presentation/pages/add_sale_page.dart';
import '../../features/sales/presentation/pages/sale_detail_page.dart';

// Deals
import '../../features/deals/presentation/pages/deals_page.dart';
import '../../features/deals/presentation/pages/deal_detail_page.dart';
import '../../features/deals/presentation/pages/add_deal_page.dart';

// Tasks
import '../../features/tasks/presentation/pages/tasks_page.dart';
import '../../features/tasks/presentation/pages/task_detail_page.dart';
import '../../features/tasks/presentation/pages/add_task_page.dart';

// Messenger
import '../../features/messenger/presentation/pages/messenger_page.dart';
import '../../features/messenger/presentation/pages/chat_page.dart';

// Employees
import '../../features/employees/presentation/pages/employees_page.dart';
import '../../features/employees/presentation/pages/employee_detail_page.dart';
import '../../features/employees/presentation/pages/add_employee_page.dart';

// Suppliers
import '../../features/suppliers/presentation/pages/suppliers_page.dart';
import '../../features/suppliers/presentation/pages/supplier_detail_page.dart';

// Customers
import '../../features/customers/presentation/pages/customers_page.dart';
import '../../features/customers/presentation/pages/customer_detail_page.dart';

// Reports
import '../../features/reports/presentation/pages/reports_page.dart';

// Documents
import '../../features/documents/presentation/pages/documents_page.dart';

// Settings
import '../../features/settings/presentation/pages/settings_page.dart';

// Notifications
import '../../features/notifications/presentation/pages/notifications_page.dart';

class AppRoutes {
  AppRoutes._();
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String pinSetup = '/pin-setup';
  static const String pinLock = '/pin-lock';
  static const String dashboard = '/dashboard';
  static const String finance = '/finance';
  static const String financeIncomeAdd = '/finance/income/add';
  static const String financeExpenseAdd = '/finance/expense/add';
  static const String financeAccounts = '/finance/accounts';
  static const String financeDebts = '/finance/debts';
  static const String incomingGoods = '/incoming-goods';
  static const String incomingGoodsAdd = '/incoming-goods/add';
  static const String incomingGoodsDetail = '/incoming-goods/:id';
  static const String inventory = '/inventory';
  static const String productAdd = '/inventory/product/add';
  static const String productDetail = '/inventory/product/:id';
  static const String stockAdjustment = '/inventory/adjust';
  static const String sales = '/sales';
  static const String salesAdd = '/sales/add';
  static const String saleDetail = '/sales/:id';
  static const String deals = '/deals';
  static const String dealAdd = '/deals/add';
  static const String dealDetail = '/deals/:id';
  static const String reports = '/reports';
  static const String tasks = '/tasks';
  static const String taskAdd = '/tasks/add';
  static const String taskDetail = '/tasks/:id';
  static const String messenger = '/messenger';
  static const String chatRoom = '/messenger/chat/:id';
  static const String employees = '/employees';
  static const String employeeAdd = '/employees/add';
  static const String employeeDetail = '/employees/:id';
  static const String suppliers = '/suppliers';
  static const String supplierDetail = '/suppliers/:id';
  static const String customers = '/customers';
  static const String customerDetail = '/customers/:id';
  static const String documents = '/documents';
  static const String settings = '/settings';
  static const String notifications = '/notifications';
}

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    redirect: (BuildContext context, GoRouterState state) async {
      final token = await getIt<ApiClient>().getAccessToken();
      final isAuth = token != null && token.isNotEmpty;
      final location = state.matchedLocation;
      final isPublic = location == AppRoutes.login || location == AppRoutes.register;

      if (location == AppRoutes.splash) return null;
      if (!isAuth) return isPublic ? null : AppRoutes.login;
      if (location == AppRoutes.pinSetup || location == AppRoutes.pinLock) return null;

      final hasPin = await getIt<SecurityService>().isPinSet();
      if (!hasPin) return AppRoutes.pinSetup;
      if (isPublic) return AppRoutes.pinLock;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: 'register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: AppRoutes.pinSetup,
        name: 'pin-setup',
        builder: (context, state) {
          final mode = state.uri.queryParameters['mode'];
          return PinSetupPage(isChangeMode: mode == 'change');
        },
      ),
      GoRoute(
        path: AppRoutes.pinLock,
        name: 'pin-lock',
        builder: (context, state) => const PinLockPage(),
      ),
      GoRoute(
        path: AppRoutes.dashboard,
        name: 'dashboard',
        builder: (context, state) => const DashboardPage(),
      ),

      // Finance
      GoRoute(
        path: AppRoutes.finance,
        name: 'finance',
        builder: (context, state) => const FinancePage(),
      ),
      GoRoute(
        path: AppRoutes.financeIncomeAdd,
        name: 'finance-income-add',
        builder: (context, state) => const AddIncomePage(),
      ),
      GoRoute(
        path: AppRoutes.financeExpenseAdd,
        name: 'finance-expense-add',
        builder: (context, state) => const AddExpensePage(),
      ),
      GoRoute(
        path: AppRoutes.financeAccounts,
        name: 'finance-accounts',
        builder: (context, state) => const AccountsPage(),
      ),
      GoRoute(
        path: AppRoutes.financeDebts,
        name: 'finance-debts',
        builder: (context, state) => const DebtsPage(),
      ),

      // Incoming Goods (Shipments)
      GoRoute(
        path: AppRoutes.incomingGoods,
        name: 'incoming-goods',
        builder: (context, state) => const ShipmentsPage(),
      ),
      GoRoute(
        path: AppRoutes.incomingGoodsAdd,
        name: 'incoming-goods-add',
        builder: (context, state) => const AddShipmentPage(),
      ),
      GoRoute(
        path: AppRoutes.incomingGoodsDetail,
        name: 'incoming-goods-detail',
        builder: (context, state) => ShipmentDetailPage(
          shipmentId: state.pathParameters['id'] ?? '',
        ),
      ),

      // Inventory
      GoRoute(
        path: AppRoutes.inventory,
        name: 'inventory',
        builder: (context, state) => const InventoryPage(),
      ),
      GoRoute(
        path: AppRoutes.productAdd,
        name: 'product-add',
        builder: (context, state) => const AddProductPage(),
      ),
      GoRoute(
        path: AppRoutes.productDetail,
        name: 'product-detail',
        builder: (context, state) => ProductDetailPage(
          productId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.stockAdjustment,
        name: 'stock-adjustment',
        builder: (context, state) => const StockAdjustmentPage(),
      ),

      // Sales
      GoRoute(
        path: AppRoutes.sales,
        name: 'sales',
        builder: (context, state) => const SalesPage(),
      ),
      GoRoute(
        path: AppRoutes.salesAdd,
        name: 'sales-add',
        builder: (context, state) => const AddSalePage(),
      ),
      GoRoute(
        path: AppRoutes.saleDetail,
        name: 'sale-detail',
        builder: (context, state) => SaleDetailPage(
          saleId: state.pathParameters['id'] ?? '',
        ),
      ),

      // Deals / CRM
      GoRoute(
        path: AppRoutes.deals,
        name: 'deals',
        builder: (context, state) => const DealsPage(),
      ),
      GoRoute(
        path: AppRoutes.dealAdd,
        name: 'deal-add',
        builder: (context, state) => const AddDealPage(),
      ),
      GoRoute(
        path: AppRoutes.dealDetail,
        name: 'deal-detail',
        builder: (context, state) => DealDetailPage(
          dealId: state.pathParameters['id'] ?? '',
        ),
      ),

      // Tasks
      GoRoute(
        path: AppRoutes.tasks,
        name: 'tasks',
        builder: (context, state) => const TasksPage(),
      ),
      GoRoute(
        path: AppRoutes.taskAdd,
        name: 'task-add',
        builder: (context, state) => const AddTaskPage(),
      ),
      GoRoute(
        path: '/tasks/create',
        builder: (context, state) => const AddTaskPage(),
      ),
      GoRoute(
        path: AppRoutes.taskDetail,
        name: 'task-detail',
        builder: (context, state) => TaskDetailPage(
          taskId: state.pathParameters['id'] ?? '',
        ),
      ),

      // Messenger
      GoRoute(
        path: AppRoutes.messenger,
        name: 'messenger',
        builder: (context, state) => const MessengerPage(),
      ),
      GoRoute(
        path: AppRoutes.chatRoom,
        name: 'chat-room',
        builder: (context, state) => ChatPage(
          roomId: state.pathParameters['id'] ?? '',
          roomName: state.uri.queryParameters['name'],
        ),
      ),

      // Employees
      GoRoute(
        path: AppRoutes.employees,
        name: 'employees',
        builder: (context, state) => const EmployeesPage(),
      ),
      GoRoute(
        path: AppRoutes.employeeAdd,
        name: 'employee-add',
        builder: (context, state) => const AddEmployeePage(),
      ),
      GoRoute(
        path: AppRoutes.employeeDetail,
        name: 'employee-detail',
        builder: (context, state) => EmployeeDetailPage(
          employeeId: state.pathParameters['id'] ?? '',
        ),
      ),

      // Suppliers
      GoRoute(
        path: AppRoutes.suppliers,
        name: 'suppliers',
        builder: (context, state) => const SuppliersPage(),
      ),
      GoRoute(
        path: AppRoutes.supplierDetail,
        name: 'supplier-detail',
        builder: (context, state) => SupplierDetailPage(
          supplierId: state.pathParameters['id'] ?? '',
        ),
      ),

      // Customers
      GoRoute(
        path: AppRoutes.customers,
        name: 'customers',
        builder: (context, state) => const CustomersPage(),
      ),
      GoRoute(
        path: AppRoutes.customerDetail,
        name: 'customer-detail',
        builder: (context, state) => CustomerDetailPage(
          customerId: state.pathParameters['id'] ?? '',
        ),
      ),

      // Reports
      GoRoute(
        path: AppRoutes.reports,
        name: 'reports',
        builder: (context, state) => const ReportsPage(),
      ),

      // Documents
      GoRoute(
        path: AppRoutes.documents,
        name: 'documents',
        builder: (context, state) => const DocumentsPage(),
      ),

      // Settings
      GoRoute(
        path: AppRoutes.settings,
        name: 'settings',
        builder: (context, state) => const SettingsPage(),
      ),

      // Notifications
      GoRoute(
        path: AppRoutes.notifications,
        name: 'notifications',
        builder: (context, state) => const NotificationsPage(),
      ),
    ],
  );
}
