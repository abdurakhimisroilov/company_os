import '../../../../core/utils/json_helpers.dart';

class MonthlyChartData {
  final String month;
  final double income;
  final double expense;

  const MonthlyChartData({
    required this.month,
    required this.income,
    required this.expense,
  });

  factory MonthlyChartData.fromJson(Map<String, dynamic> json) {
    return MonthlyChartData(
      month: JsonHelpers.toStr(json['month']),
      income: JsonHelpers.toDouble(json['income'] ?? json['revenue']),
      expense: JsonHelpers.toDouble(json['expense'] ?? json['expenses']),
    );
  }
}

class SalesTrendPoint {
  final String date;
  final double amount;

  const SalesTrendPoint({required this.date, required this.amount});

  factory SalesTrendPoint.fromJson(Map<String, dynamic> json) {
    return SalesTrendPoint(
      date: JsonHelpers.toStr(json['date']),
      amount: JsonHelpers.toDouble(json['amount'] ?? json['total']),
    );
  }
}

class ReportModel {
  final double revenue;
  final double expenses;
  final double grossProfit;
  final double netProfit;
  final String period;
  final List<MonthlyChartData> monthlyData;
  final List<SalesTrendPoint> salesTrend;

  const ReportModel({
    required this.revenue,
    required this.expenses,
    required this.grossProfit,
    required this.netProfit,
    this.period = 'month',
    this.monthlyData = const [],
    this.salesTrend = const [],
  });

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    final monthly = JsonHelpers.toList(json['monthlyData'] ?? json['monthly'])
        .map((e) => MonthlyChartData.fromJson(JsonHelpers.toMap(e)))
        .toList();

    final trends = JsonHelpers.toList(json['salesTrend'] ?? json['trends'])
        .map((e) => SalesTrendPoint.fromJson(JsonHelpers.toMap(e)))
        .toList();

    final rev = JsonHelpers.toDouble(json['revenue'] ?? json['income'] ?? json['totalRevenue']);
    final exp = JsonHelpers.toDouble(json['expenses'] ?? json['totalExpenses']);
    final gross = JsonHelpers.toDouble(json['grossProfit'] ?? (rev - exp));
    final net = JsonHelpers.toDouble(json['netProfit'] ?? (rev - exp));

    return ReportModel(
      revenue: rev,
      expenses: exp,
      grossProfit: gross,
      netProfit: net,
      period: JsonHelpers.toStr(json['period'], 'month'),
      monthlyData: monthly,
      salesTrend: trends,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'revenue': revenue,
      'expenses': expenses,
      'grossProfit': grossProfit,
      'netProfit': netProfit,
      'period': period,
    };
  }
}
