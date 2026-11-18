import '../../../../core/utils/json_helpers.dart';

/// Income and expenses of one bucket (a day, or a month for the yearly report).
class MonthlyChartData {
  /// Short axis label from the server ("12.11" or "Ноя").
  final String month;

  /// Bucket start, `YYYY-MM-DD`.
  final String date;
  final double income;
  final double expense;

  const MonthlyChartData({
    required this.month,
    this.date = '',
    required this.income,
    required this.expense,
  });

  factory MonthlyChartData.fromJson(Map<String, dynamic> json) {
    return MonthlyChartData(
      month: JsonHelpers.toStr(json['month'] ?? json['label']),
      date: JsonHelpers.toStr(json['date']),
      income: JsonHelpers.toDouble(json['income']),
      expense: JsonHelpers.toDouble(json['expense'] ?? json['expenses']),
    );
  }
}

class SalesTrendPoint {
  final String date;
  final String label;
  final double amount;

  const SalesTrendPoint({required this.date, this.label = '', required this.amount});

  factory SalesTrendPoint.fromJson(Map<String, dynamic> json) {
    final date = JsonHelpers.toStr(json['date']);
    return SalesTrendPoint(
      date: date,
      label: JsonHelpers.toStr(json['label'], date),
      amount: JsonHelpers.toDouble(json['amount'] ?? json['total']),
    );
  }
}

class CategoryExpense {
  final String category;
  final double amount;

  const CategoryExpense({required this.category, required this.amount});

  factory CategoryExpense.fromJson(Map<String, dynamic> json) {
    return CategoryExpense(
      category: JsonHelpers.toStr(json['category'], 'Прочее'),
      amount: JsonHelpers.toDouble(json['amount']),
    );
  }
}

/// `GET /reports/financial?period=` — everything the reports screen shows.
class ReportModel {
  /// Money received (all income operations of the period).
  final double income;

  /// Money spent (all expense operations of the period).
  final double expenses;

  /// income − expenses.
  final double netProfit;

  /// Sales total of the period.
  final double revenue;
  final int salesCount;
  final double costOfGoods;

  /// revenue − cost of goods sold.
  final double grossProfit;
  final String period;
  final String from;
  final String to;
  final List<MonthlyChartData> monthlyData;
  final List<SalesTrendPoint> salesTrend;
  final List<CategoryExpense> expensesByCategory;

  const ReportModel({
    required this.income,
    required this.expenses,
    required this.netProfit,
    required this.revenue,
    required this.grossProfit,
    this.salesCount = 0,
    this.costOfGoods = 0,
    this.period = 'month',
    this.from = '',
    this.to = '',
    this.monthlyData = const [],
    this.salesTrend = const [],
    this.expensesByCategory = const [],
  });

  bool get hasCashFlow => monthlyData.any((m) => m.income != 0 || m.expense != 0);
  bool get hasSales => salesTrend.any((p) => p.amount != 0);

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    final income = JsonHelpers.toDouble(json['income'] ?? json['totalRevenue']);
    final expenses = JsonHelpers.toDouble(json['expenses'] ?? json['totalExpenses']);
    final revenue = JsonHelpers.toDouble(json['revenue']);
    final costOfGoods = JsonHelpers.toDouble(json['costOfGoods']);

    return ReportModel(
      income: income,
      expenses: expenses,
      netProfit: JsonHelpers.toDouble(json['netProfit'], income - expenses),
      revenue: revenue,
      grossProfit: JsonHelpers.toDouble(json['grossProfit'], revenue - costOfGoods),
      salesCount: JsonHelpers.toInt(json['salesCount']),
      costOfGoods: costOfGoods,
      period: JsonHelpers.toStr(json['period'], 'month'),
      from: JsonHelpers.toStr(json['from']),
      to: JsonHelpers.toStr(json['to']),
      monthlyData: JsonHelpers.toList(json['monthlyData'])
          .map((e) => MonthlyChartData.fromJson(JsonHelpers.toMap(e)))
          .toList(),
      salesTrend: JsonHelpers.toList(json['salesTrend'])
          .map((e) => SalesTrendPoint.fromJson(JsonHelpers.toMap(e)))
          .toList(),
      expensesByCategory: JsonHelpers.toList(json['expensesByCategory'])
          .map((e) => CategoryExpense.fromJson(JsonHelpers.toMap(e)))
          .where((c) => c.amount != 0)
          .toList(),
    );
  }
}
