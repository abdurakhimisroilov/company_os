import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/utils/json_helpers.dart';
import '../models/transaction_model.dart';

class FinanceRepository {
  final ApiClient apiClient;

  FinanceRepository({required this.apiClient});

  static const int pageSize = 30;

  static String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Calendar day in the form the server expects (`YYYY-MM-DD`).
  static String dayParam(DateTime d) => _day(d);

  Map<String, dynamic> _unwrap(dynamic body) {
    return JsonHelpers.toMap(body is Map && body.containsKey('data') ? body['data'] : body);
  }

  /// `type`: 'all' | 'income' | 'expense' | 'transfer'.
  Future<TransactionPage> getTransactions({
    String? type,
    DateTime? startDate,
    DateTime? endDate,
    int page = 1,
    int limit = pageSize,
  }) async {
    final query = <String, dynamic>{'page': page, 'limit': limit};
    if (type != null && type.isNotEmpty && type != 'all') query['type'] = type;
    if (startDate != null) query['startDate'] = _day(startDate);
    if (endDate != null) query['endDate'] = _day(endDate);

    final response = await apiClient.get(ApiEndpoints.transactions, queryParameters: query);
    final body = response.data;
    final items = JsonHelpers.toList(body).map((e) => TransactionModel.fromJson(JsonHelpers.toMap(e))).toList();
    final meta = body is Map ? JsonHelpers.toMap(body['meta']) : const <String, dynamic>{};
    return TransactionPage(items: items, total: JsonHelpers.toInt(meta['total'], items.length));
  }

  Future<List<AccountModel>> getAccounts() async {
    final response = await apiClient.get(ApiEndpoints.accounts);
    return JsonHelpers.toList(response.data).map((e) => AccountModel.fromJson(JsonHelpers.toMap(e))).toList();
  }

  /// `type`: 'cash' | 'bank' | 'card'. Only an administrator may create accounts.
  Future<AccountModel> createAccount({required String name, required String type, String? accountNumber}) async {
    final response = await apiClient.post(ApiEndpoints.accounts, data: {
      'name': name,
      'type': type,
      if (accountNumber != null && accountNumber.isNotEmpty) 'accountNumber': accountNumber,
    });
    return AccountModel.fromJson(_unwrap(response.data));
  }

  Future<List<String>> getExpenseCategories() async {
    final response = await apiClient.get(ApiEndpoints.expenseCategories);
    return JsonHelpers.toList(response.data)
        .map((e) => JsonHelpers.toStr(JsonHelpers.toMap(e)['name']).trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();
  }

  Future<List<PartyRef>> getCustomers() => _parties(ApiEndpoints.customers);

  Future<List<PartyRef>> getSuppliers() => _parties(ApiEndpoints.suppliers);

  Future<List<PartyRef>> _parties(String path) async {
    final response = await apiClient.get(path);
    return JsonHelpers.toList(response.data)
        .map((e) => PartyRef.fromJson(JsonHelpers.toMap(e)))
        .where((p) => p.id.isNotEmpty && p.name.isNotEmpty)
        .toList();
  }

  Future<List<DebtModel>> getCustomerDebts() async {
    final response = await apiClient.get('/finance/customer-debts');
    return JsonHelpers.toList(response.data).map((e) => DebtModel.fromJson(JsonHelpers.toMap(e))).toList();
  }

  Future<List<DebtModel>> getSupplierDebts() async {
    final response = await apiClient.get('/finance/supplier-debts');
    return JsonHelpers.toList(response.data).map((e) => DebtModel.fromJson(JsonHelpers.toMap(e))).toList();
  }

  Future<TransactionModel> createIncome(Map<String, dynamic> data) async {
    final response = await apiClient.post('/finance/transactions/income', data: data);
    return TransactionModel.fromJson(_unwrap(response.data));
  }

  Future<TransactionModel> createExpense(Map<String, dynamic> data) async {
    final response = await apiClient.post('/finance/transactions/expense', data: data);
    return TransactionModel.fromJson(_unwrap(response.data));
  }

  Future<TransactionModel> createTransfer({
    required String fromAccountId,
    required String toAccountId,
    required double amount,
    String? description,
    DateTime? date,
  }) async {
    final response = await apiClient.post('/finance/transactions/transfer', data: {
      'fromAccountId': fromAccountId,
      'toAccountId': toAccountId,
      'amount': amount,
      if (description != null && description.isNotEmpty) 'description': description,
      if (date != null) 'date': _day(date),
    });
    return TransactionModel.fromJson(_unwrap(response.data));
  }

  /// Administrators only; the server restores the account balance.
  Future<void> deleteTransaction(String id) async {
    await apiClient.delete(ApiEndpoints.transaction(id));
  }

  Future<TransactionModel> payDebt(Map<String, dynamic> data) async {
    final response = await apiClient.post('/finance/debts/pay', data: data);
    return TransactionModel.fromJson(_unwrap(response.data));
  }

  /// Removes an uploaded file that was never attached to a saved record.
  Future<void> deleteUploadedFile(String url) async {
    await apiClient.delete('/files', queryParameters: {'url': url});
  }
}
