class ApiEndpoints {
  ApiEndpoints._();

  // Auth
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';

  // Users
  static const String users = '/users';
  static String user(String id) => '/users/$id';

  // Dashboard
  static const String dashboardStats = '/dashboard/stats';

  // Finance
  static const String financeOverview = '/finance/overview';
  static const String accounts = '/finance/accounts';
  static String account(String id) => '/finance/accounts/$id';
  static const String transactions = '/finance/transactions';
  static String transaction(String id) => '/finance/transactions/$id';
  static const String cashFlow = '/finance/cash-flow';
  static const String payments = '/finance/payments';
  static const String expenseCategories = '/finance/categories';

  // Inventory & Products
  static const String products = '/inventory/products';
  static String product(String id) => '/inventory/products/$id';
  static const String productCategories = '/inventory/categories';
  static const String inventoryLevels = '/inventory/levels';
  static const String stockMovements = '/inventory/movements';
  static const String adjustStock = '/inventory/adjust';
  static const String lowStockAlerts = '/inventory/alerts/low-stock';
  static const String warehouses = '/inventory/warehouses';

  // Incoming Goods (Shipments)
  static const String shipments = '/shipments';
  static String shipment(String id) => '/shipments/$id';
  static String confirmShipment(String id) => '/shipments/$id/confirm';

  // Sales
  static const String sales = '/sales';
  static String sale(String id) => '/sales/$id';
  static String salePayment(String id) => '/sales/$id/payments';
  static String saleReturn(String id) => '/sales/$id/return';

  // Deals / CRM
  static const String deals = '/deals';
  static String deal(String id) => '/deals/$id';
  static const String dealsKanban = '/deals/kanban';
  static String dealComments(String id) => '/deals/$id/comments';
  static String dealStatus(String id) => '/deals/$id/status';

  // Tasks
  static const String tasks = '/tasks';
  static String task(String id) => '/tasks/$id';
  static String taskStatus(String id) => '/tasks/$id/status';
  static String taskComments(String id) => '/tasks/$id/comments';
  static String taskAttachments(String id) => '/tasks/$id/attachments';

  // Chat / Messenger
  static const String chatRooms = '/chat/rooms';
  static String chatRoom(String id) => '/chat/rooms/$id';
  static String chatMessages(String roomId) => '/chat/rooms/$roomId/messages';
  static String chatMarkRead(String roomId) => '/chat/rooms/$roomId/read';
  static String chatReportMessage(String messageId) => '/chat/messages/$messageId/report';
  static const String chatBlocks = '/chat/blocks';
  static String chatBlock(String userId) => '/chat/blocks/$userId';

  // Employees
  static const String employees = '/employees';
  static String employee(String id) => '/employees/$id';
  static const String departments = '/employees/departments';
  static String employeeSalary(String id) => '/employees/$id/salary';

  // Suppliers & Customers
  static const String suppliers = '/suppliers';
  static String supplier(String id) => '/suppliers/$id';
  static const String customers = '/customers';
  static String customer(String id) => '/customers/$id';

  // Documents
  static const String documents = '/documents';
  static String document(String id) => '/documents/$id';
  static const String documentFolders = '/documents/folders';

  // Reports
  static const String reportsFinancial = '/reports/financial';
  static const String reportsSales = '/reports/sales';
  static const String reportsInventory = '/reports/inventory';
  static const String reportsExportPdf = '/reports/export/pdf';
  static const String reportsExportExcel = '/reports/export/excel';

  // Notifications
  static const String notifications = '/notifications';
  static const String notificationsUnread = '/notifications/unread';
  static const String notificationsMarkAllRead = '/notifications/read-all';

  // Files
  static const String fileUpload = '/files/upload';
  static String fileUrl(String id) => '/files/$id';

  // App Version & Updates
  static const String appVersion = '/app/version';
  static const String appDownload = '/app/download';

  // Companies / Multi-Organization
  static const String companies = '/companies';
  static const String currentCompany = '/companies/current';
  static const String switchCompany = '/companies/switch';
}
