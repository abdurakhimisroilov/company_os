import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../bloc/reports_bloc.dart';
import '../../data/models/report_model.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  String _selectedPeriod = 'month';
  String _selectedType = 'financial';

  final List<Map<String, String>> _periods = [
    {'id': 'today', 'label': 'Сегодня'},
    {'id': 'week', 'label': 'Неделя'},
    {'id': 'month', 'label': 'Месяц'},
    {'id': 'year', 'label': 'Год'},
  ];

  final List<Map<String, String>> _types = [
    {'id': 'financial', 'label': 'Финансы'},
    {'id': 'sales', 'label': 'Продажи'},
    {'id': 'inventory', 'label': 'Склад'},
  ];

  @override
  void initState() {
    super.initState();
    context.read<ReportsBloc>().add(LoadReportEvent(period: _selectedPeriod, type: _selectedType));
  }

  void _onPeriodChanged(String period) {
    setState(() => _selectedPeriod = period);
    context.read<ReportsBloc>().add(LoadReportEvent(period: period, type: _selectedType));
  }

  void _onTypeChanged(String type) {
    setState(() => _selectedType = type);
    context.read<ReportsBloc>().add(LoadReportEvent(period: _selectedPeriod, type: type));
  }

  void _export(String format) {
    context.read<ReportsBloc>().add(ExportReportEvent(format: format, period: _selectedPeriod));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildHeader(),
              _buildSelectors(),
              Expanded(
                child: BlocConsumer<ReportsBloc, ReportsState>(
                  listener: (context, state) {
                    if (state is ReportsExportSuccess) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(state.message), backgroundColor: AppColors.success),
                      );
                    }
                  },
                  builder: (context, state) {
                    if (state is ReportsLoading) {
                      return const LoadingShimmer();
                    }
                    if (state is ReportsError) {
                      return _buildErrorState(state.message);
                    }
                    if (state is ReportsLoaded) {
                      return _buildContent(state.report);
                    }
                    // Default fallback
                    return _buildContent(const ReportModel(
                      revenue: 1250000000,
                      expenses: 450000000,
                      grossProfit: 800000000,
                      netProfit: 680000000,
                    ));
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
            onPressed: () => context.pop(),
          ),
          const Expanded(
            child: Text(
              'Аналитика и отчёты',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: AppColors.error),
            tooltip: 'Экспорт PDF',
            onPressed: () => _export('pdf'),
          ),
          IconButton(
            icon: const Icon(Icons.table_chart, color: AppColors.success),
            tooltip: 'Экспорт Excel',
            onPressed: () => _export('excel'),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectors() {
    return Column(
      children: [
        // Type chips
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _types.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, idx) {
              final t = _types[idx];
              final isSel = t['id'] == _selectedType;
              return ChoiceChip(
                label: Text(t['label']!),
                selected: isSel,
                selectedColor: AppColors.primaryBlue,
                backgroundColor: Colors.white.withOpacity(0.7),
                labelStyle: TextStyle(
                  color: isSel ? Colors.white : AppColors.textPrimary,
                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
                onSelected: (_) => _onTypeChanged(t['id']!),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        // Period tabs
        Container(
          height: 36,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: _periods.map((p) {
              final isSel = p['id'] == _selectedPeriod;
              return Expanded(
                child: GestureDetector(
                  onTap: () => _onPeriodChanged(p['id']!),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSel ? AppColors.primaryBlue : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        p['label']!,
                        style: TextStyle(
                          color: isSel ? Colors.white : AppColors.textSecondary,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildContent(ReportModel report) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Financial summary cards
        Row(
          children: [
            Expanded(
              child: _summaryCard('Выручка', Formatters.formatUzs(report.revenue), AppColors.iconBgBlue, AppColors.primaryBlue),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _summaryCard('Расходы', Formatters.formatUzs(report.expenses), AppColors.iconBgRed, AppColors.error),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _summaryCard('Вал. прибыль', Formatters.formatUzs(report.grossProfit), AppColors.iconBgPurple, AppColors.secondaryLavender),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _summaryCard('Чистая прибыль', Formatters.formatUzs(report.netProfit), AppColors.iconBgGreen, AppColors.success),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Bar Chart (Monthly income vs expense)
        Text('Доходы и расходы по месяцам', style: AppTextStyles.titleMedium),
        const SizedBox(height: 12),
        GlassCard(
          padding: const EdgeInsets.all(16),
          borderRadius: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _chartLegend('Доходы', AppColors.primaryBlue),
                  const SizedBox(width: 16),
                  _chartLegend('Расходы', AppColors.error),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 180,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: 100,
                    barTouchData: BarTouchData(enabled: false),
                    titlesData: FlTitlesData(
                      show: true,
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            const months = ['Янв', 'Фев', 'Мар', 'Апр', 'Май', 'Июн'];
                            if (value.toInt() >= 0 && value.toInt() < months.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(months[value.toInt()], style: AppTextStyles.caption.copyWith(fontSize: 10)),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    gridData: const FlGridData(show: false),
                    barGroups: [
                      _makeBarGroup(0, 70, 35),
                      _makeBarGroup(1, 85, 45),
                      _makeBarGroup(2, 60, 40),
                      _makeBarGroup(3, 90, 50),
                      _makeBarGroup(4, 75, 42),
                      _makeBarGroup(5, 95, 48),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Line Chart (Sales trend)
        Text('Динамика продаж', style: AppTextStyles.titleMedium),
        const SizedBox(height: 12),
        GlassCard(
          padding: const EdgeInsets.all(16),
          borderRadius: 20,
          child: SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 20),
                      FlSpot(1, 35),
                      FlSpot(2, 28),
                      FlSpot(3, 45),
                      FlSpot(4, 60),
                      FlSpot(5, 55),
                      FlSpot(6, 80),
                    ],
                    isCurved: true,
                    color: AppColors.primaryBlue,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primaryBlue.withOpacity(0.15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Export Actions
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _export('pdf'),
                icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                label: const Text('Экспорт в PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _export('excel'),
                icon: const Icon(Icons.table_chart, color: Colors.white),
                label: const Text('Экспорт в Excel'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _summaryCard(String title, String value, Color bg, Color textCol) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.caption),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textCol),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  BarChartGroupData _makeBarGroup(int x, double y1, double y2) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(toY: y1, color: AppColors.primaryBlue, width: 8, borderRadius: BorderRadius.circular(4)),
        BarChartRodData(toY: y2, color: AppColors.error, width: 8, borderRadius: BorderRadius.circular(4)),
      ],
    );
  }

  Widget _chartLegend(String label, Color color) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: AppTextStyles.caption.copyWith(fontSize: 11)),
      ],
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          Text(message, style: AppTextStyles.bodyMedium),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.read<ReportsBloc>().add(LoadReportEvent(period: _selectedPeriod, type: _selectedType)),
            child: const Text('Повторить'),
          ),
        ],
      ),
    );
  }
}
