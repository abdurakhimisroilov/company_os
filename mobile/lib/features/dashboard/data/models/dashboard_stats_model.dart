import '../../../../core/utils/json_helpers.dart';

class DashboardStatsModel {
  final double totalBalance;
  final double balanceChangePercent;
  final double income;
  final double expenses;
  final double sales;
  final double stockBalance;
  final int totalProducts;
  final int activeDeals;
  final int pendingTasks;
  final double customerDebts;
  final double supplierDebts;
  final String period;

  const DashboardStatsModel({
    required this.totalBalance,
    required this.balanceChangePercent,
    required this.income,
    required this.expenses,
    required this.sales,
    required this.stockBalance,
    this.totalProducts = 0,
    this.activeDeals = 0,
    this.pendingTasks = 0,
    this.customerDebts = 0.0,
    this.supplierDebts = 0.0,
    this.period = 'month',
  });

  factory DashboardStatsModel.fromJson(Map<String, dynamic> json) {
    return DashboardStatsModel(
      totalBalance: JsonHelpers.toDouble(json['totalBalance'] ?? json['balance']),
      balanceChangePercent: JsonHelpers.toDouble(json['balanceChangePercent'] ?? json['changePercent'], 0.0),
      income: JsonHelpers.toDouble(json['income'] ?? json['totalIncome']),
      expenses: JsonHelpers.toDouble(json['expenses'] ?? json['totalExpenses']),
      sales: JsonHelpers.toDouble(json['sales'] ?? json['totalSales']),
      stockBalance: JsonHelpers.toDouble(json['stockBalance'] ?? json['inventoryValue']),
      totalProducts: JsonHelpers.toInt(json['totalProducts'] ?? json['productsCount']),
      activeDeals: JsonHelpers.toInt(json['activeDeals'] ?? json['dealsCount']),
      pendingTasks: JsonHelpers.toInt(json['pendingTasks'] ?? json['tasksCount']),
      customerDebts: JsonHelpers.toDouble(json['customerDebts'] ?? json['receivables']),
      supplierDebts: JsonHelpers.toDouble(json['supplierDebts'] ?? json['payables']),
      period: JsonHelpers.toStr(json['period'], 'month'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalBalance': totalBalance,
      'balanceChangePercent': balanceChangePercent,
      'income': income,
      'expenses': expenses,
      'sales': sales,
      'stockBalance': stockBalance,
      'totalProducts': totalProducts,
      'activeDeals': activeDeals,
      'pendingTasks': pendingTasks,
      'customerDebts': customerDebts,
      'supplierDebts': supplierDebts,
      'period': period,
    };
  }
}
