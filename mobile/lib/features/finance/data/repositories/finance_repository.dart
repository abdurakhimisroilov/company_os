import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/utils/json_helpers.dart';
import '../models/transaction_model.dart';

class FinanceRepository {
  final ApiClient apiClient;

  FinanceRepository({required this.apiClient});

  Future<List<TransactionModel>> getTransactions({
    String? type,
    String? startDate,
    String? endDate,
    int page = 1,
    int limit = 50,
  }) async {
    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
    };
    if (type != null && type.isNotEmpty && type != 'all') {
      query['type'] = type;
    }
    if (startDate != null) query['startDate'] = startDate;
    if (endDate != null) query['endDate'] = endDate;

    final response = await apiClient.get(
      ApiEndpoints.transactions,
      queryParameters: query,
    );

    if (response.statusCode == 200) {
      final list = JsonHelpers.toList(response.data);
      return list.map((e) => TransactionModel.fromJson(JsonHelpers.toMap(e))).toList();
    }
    throw Exception('Не удалось загрузить транзакции');
  }

  Future<List<AccountModel>> getAccounts() async {
    final response = await apiClient.get(ApiEndpoints.accounts);
    if (response.statusCode == 200) {
      final list = JsonHelpers.toList(response.data);
      return list.map((e) => AccountModel.fromJson(JsonHelpers.toMap(e))).toList();
    }
    throw Exception('Не удалось загрузить счета');
  }

  Future<List<DebtModel>> getCustomerDebts() async {
    final response = await apiClient.get('/finance/customer-debts');
    if (response.statusCode == 200) {
      final list = JsonHelpers.toList(response.data);
      return list.map((e) => DebtModel.fromJson(JsonHelpers.toMap(e))).toList();
    }
    throw Exception('Не удалось загрузить задолженности клиентов');
  }

  Future<List<DebtModel>> getSupplierDebts() async {
    final response = await apiClient.get('/finance/supplier-debts');
    if (response.statusCode == 200) {
      final list = JsonHelpers.toList(response.data);
      return list.map((e) => DebtModel.fromJson(JsonHelpers.toMap(e))).toList();
    }
    throw Exception('Не удалось загрузить задолженности поставщикам');
  }

  Future<TransactionModel> createIncome(Map<String, dynamic> data) async {
    final response = await apiClient.post('/finance/transactions/income', data: data);
    if (response.statusCode == 200 || response.statusCode == 201) {
      final map = JsonHelpers.toMap(
        response.data is Map && (response.data as Map).containsKey('data')
            ? (response.data as Map)['data']
            : response.data,
      );
      return TransactionModel.fromJson(map);
    }
    throw Exception('Ошибка при сохранении поступления');
  }

  Future<TransactionModel> createExpense(Map<String, dynamic> data) async {
    final response = await apiClient.post('/finance/transactions/expense', data: data);
    if (response.statusCode == 200 || response.statusCode == 201) {
      final map = JsonHelpers.toMap(
        response.data is Map && (response.data as Map).containsKey('data')
            ? (response.data as Map)['data']
            : response.data,
      );
      return TransactionModel.fromJson(map);
    }
    throw Exception('Ошибка при сохранении расхода');
  }

  Future<TransactionModel> createTransfer(Map<String, dynamic> data) async {
    final response = await apiClient.post('/finance/transactions/transfer', data: data);
    if (response.statusCode == 200 || response.statusCode == 201) {
      final map = JsonHelpers.toMap(
        response.data is Map && (response.data as Map).containsKey('data')
            ? (response.data as Map)['data']
            : response.data,
      );
      return TransactionModel.fromJson(map);
    }
    throw Exception('Ошибка при сохранении перевода');
  }

  Future<TransactionModel> payDebt(Map<String, dynamic> data) async {
    final response = await apiClient.post('/finance/debts/pay', data: data);
    if (response.statusCode == 200 || response.statusCode == 201) {
      final map = JsonHelpers.toMap(
        response.data is Map && (response.data as Map).containsKey('data')
            ? (response.data as Map)['data']
            : response.data,
      );
      return TransactionModel.fromJson(map);
    }
    throw Exception('Ошибка при регистрации оплаты задолженности');
  }
}
