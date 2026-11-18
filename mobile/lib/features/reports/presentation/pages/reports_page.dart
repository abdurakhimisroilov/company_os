import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:open_filex/open_filex.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../../../finance/data/company_currency.dart';
import '../bloc/reports_bloc.dart';
import '../../data/models/report_model.dart';
import '../../data/report_exporter.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  String _selectedPeriod = 'month';
  String _selectedType = 'financial';

  /// 'pdf' | 'excel' while that file is being generated.
  String? _exporting;

  final List<Map<String, String>> _periods = [
    {'id': 'today', 'label': 'Сегодня'},
    {'id': 'week', 'label': 'Неделя'},
    {'id': 'month', 'label': 'Месяц'},
    {'id': 'year', 'label': 'Год'},
  ];

  // Both views are built from GET /reports/financial; the server has no
  // warehouse report, so there is no "Склад" view.
  final List<Map<String, String>> _types = [
    {'id': 'financial', 'label': 'Финансы'},
    {'id': 'sales', 'label': 'Продажи'},
  ];

  @override
  void initState() {
    super.initState();
    context.read<ReportsBloc>().add(LoadReportEvent(period: _selectedPeriod));
    CompanyCurrency.instance.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
  }

  void _load() {
    context.read<ReportsBloc>().add(LoadReportEvent(period: _selectedPeriod));
  }

  Future<void> _refresh() {
    final done = Completer<void>();
    context.read<ReportsBloc>().add(RefreshReportEvent(done: done));
    return done.future;
  }

  void _onPeriodChanged(String period) {
    if (period == _selectedPeriod) return;
    setState(() => _selectedPeriod = period);
    _load();
  }

  void _onTypeChanged(String type) {
    setState(() => _selectedType = type);
  }

  String _periodLabel(String id) => _periods.firstWhere((p) => p['id'] == id, orElse: () => _periods[2])['label']!;

  void _showMessage(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: error ? AppColors.error : null),
    );
  }

  /// Builds the file on the device from the report that is on screen and opens it.
  Future<void> _export(String format) async {
    if (_exporting != null) return;
    final state = context.read<ReportsBloc>().state;
    if (state is! ReportsLoaded) {
      _showMessage('Отчёт ещё не загружен');
      return;
    }
    final report = state.report;
    final periodLabel = _periodLabel(state.period);
    final currency = CompanyCurrency.instance.label;

    setState(() => _exporting = format);
    try {
      if (format == 'pdf') {
        final bytes = await ReportExporter.buildPdfBytes(report, periodLabel: periodLabel, currency: currency);
        final file = await ReportExporter.savePdf(bytes);
        final result = await OpenFilex.open(file.path, type: 'application/pdf');
        if (!mounted) return;
        if (result.type == ResultType.noAppToOpen) {
          _showMessage('На устройстве нет приложения для открытия PDF', error: true);
        } else if (result.type != ResultType.done) {
          _showMessage('Не удалось открыть файл: ${result.message}', error: true);
        }
      } else {
        final file = await ReportExporter.exportExcel(report, periodLabel: periodLabel, currency: currency);
        final result = await OpenFilex.open(
          file.path,
          type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
        if (!mounted) return;
        if (result.type == ResultType.noAppToOpen) {
          _showMessage('На устройстве нет приложения для открытия файлов Excel', error: true);
        } else if (result.type != ResultType.done) {
          _showMessage('Не удалось открыть файл: ${result.message}', error: true);
        }
      }
    } catch (e) {
      if (mounted) _showMessage(apiErrorMessage(e, fallback: 'Не удалось сформировать файл'), error: true);
    } finally {
      if (mounted) setState(() => _exporting = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildHeader(),
              _buildSelectors(),
              Expanded(
                child: BlocConsumer<ReportsBloc, ReportsState>(
                  listenWhen: (previous, current) =>
                      current is ReportsLoaded &&
                      current.notice != null &&
                      (previous is! ReportsLoaded || previous.noticeId != current.noticeId),
                  listener: (context, state) {
                    if (state is ReportsLoaded && state.notice != null) _showMessage(state.notice!, error: true);
                  },
                  builder: (context, state) {
                    if (state is ReportsError) {
                      return _buildErrorState(state.message);
                    }
                    if (state is ReportsLoaded) {
                      return _buildContent(state.report);
                    }
                    return const LoadingShimmer();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _exportIcon(String format, IconData icon, Color color, String tooltip, bool enabled) {
    if (_exporting == format) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: color)),
      );
    }
    return IconButton(
      icon: Icon(icon, color: enabled ? color : AppColors.textTertiary),
      tooltip: tooltip,
      onPressed: enabled && _exporting == null ? () => _export(format) : null,
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
            onPressed: () => context.pop(),
          ),
          Expanded(
            child: Text(
              'Аналитика и отчёты',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ),
          BlocBuilder<ReportsBloc, ReportsState>(
            builder: (context, state) {
              final ready = state is ReportsLoaded;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _exportIcon('pdf', Icons.picture_as_pdf, AppColors.error, 'Экспорт PDF', ready),
                  _exportIcon('excel', Icons.table_chart, AppColors.success, 'Экспорт Excel', ready),
                ],
              );
            },
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
                backgroundColor: AppColors.cardBackground.withOpacity(0.7),
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
            color: AppColors.cardBackground.withOpacity(0.6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: _periods.map((p) {
              final isSel = p['id'] == _selectedPeriod;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
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
    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.primaryBlue,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (_selectedType == 'sales') ..._buildSalesView(report) else ..._buildFinancialView(report),
          const SizedBox(height: 20),

          // Export Actions
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _exporting == null ? () => _export('pdf') : null,
                  icon: _exporting == 'pdf'
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.picture_as_pdf, color: Colors.white),
                  label: const Text('Экспорт в PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.error.withOpacity(0.5),
                    disabledForegroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _exporting == null ? () => _export('excel') : null,
                  icon: _exporting == 'excel'
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.table_chart, color: Colors.white),
                  label: const Text('Экспорт в Excel'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.success.withOpacity(0.5),
                    disabledForegroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // ─── Финансы ──────────────────────────────────────────────────────────────
  List<Widget> _buildFinancialView(ReportModel report) {
    final yearly = report.period == 'year';
    return [
      Row(
        children: [
          Expanded(
            child: _summaryCard('Поступления', money(report.income), AppColors.primaryBlue),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _summaryCard('Расходы', money(report.expenses), AppColors.error),
          ),
        ],
      ),
      const SizedBox(height: 10),
      _summaryCard(
        'Чистая прибыль',
        money(report.netProfit),
        report.netProfit < 0 ? AppColors.error : AppColors.success,
      ),
      const SizedBox(height: 20),

      // Bar Chart (income vs expense)
      Text(yearly ? 'Доходы и расходы по месяцам' : 'Доходы и расходы по дням', style: AppTextStyles.titleMedium),
      const SizedBox(height: 12),
      GlassCard(
        padding: const EdgeInsets.all(16),
        borderRadius: 20,
        child: report.hasCashFlow
            ? Column(
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
                  _buildCashFlowChart(report.monthlyData),
                ],
              )
            : _emptyChart('За выбранный период нет поступлений и расходов'),
      ),
      const SizedBox(height: 20),

      Text('Расходы по категориям', style: AppTextStyles.titleMedium),
      const SizedBox(height: 12),
      GlassCard(
        padding: const EdgeInsets.all(16),
        borderRadius: 20,
        child: report.expensesByCategory.isEmpty
            ? _emptyChart('За выбранный период расходов нет')
            : Column(
                children: report.expensesByCategory.map((c) => _categoryRow(c, report.expenses)).toList(),
              ),
      ),
    ];
  }

  Widget _buildCashFlowChart(List<MonthlyChartData> data) {
    double maxValue = 0;
    for (final m in data) {
      maxValue = math.max(maxValue, math.max(m.income, m.expense));
    }
    // Every bucket gets a readable slot; long periods scroll sideways.
    const slot = 34.0;
    final labelStep = data.length > 16 ? 2 : 1;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(constraints.maxWidth, data.length * slot);
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width,
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxValue * 1.1,
                minY: 0,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final m = data[group.x];
                      return BarTooltipItem(
                        '${m.month}\n${rodIndex == 0 ? 'Доходы' : 'Расходы'}: ${money(rod.toY)}',
                        const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= data.length || i % labelStep != 0) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(data[i].month, style: AppTextStyles.caption.copyWith(fontSize: 10)),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
                barGroups: [
                  for (var i = 0; i < data.length; i++) _makeBarGroup(i, data[i].income, data[i].expense),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _categoryRow(CategoryExpense c, double totalExpenses) {
    final share = totalExpenses > 0 ? (c.amount / totalExpenses).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  c.category,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${money(c.amount)} • ${(share * 100).round()}%',
                style: AppTextStyles.caption,
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: share,
              minHeight: 6,
              backgroundColor: AppColors.error.withOpacity(0.12),
              color: AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Продажи ──────────────────────────────────────────────────────────────
  List<Widget> _buildSalesView(ReportModel report) {
    return [
      Row(
        children: [
          Expanded(
            child: _summaryCard('Выручка', money(report.revenue), AppColors.primaryBlue),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _summaryCard('Количество продаж', report.salesCount.toString(), AppColors.textPrimary),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: _summaryCard('Себестоимость', money(report.costOfGoods), AppColors.error),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _summaryCard(
              'Вал. прибыль',
              money(report.grossProfit),
              report.grossProfit < 0 ? AppColors.error : AppColors.secondaryLavender,
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),

      // Line Chart (Sales trend)
      Text('Динамика продаж', style: AppTextStyles.titleMedium),
      const SizedBox(height: 12),
      GlassCard(
        padding: const EdgeInsets.all(16),
        borderRadius: 20,
        child: report.hasSales ? _buildSalesChart(report.salesTrend) : _emptyChart('За выбранный период продаж нет'),
      ),
    ];
  }

  Widget _buildSalesChart(List<SalesTrendPoint> points) {
    double maxValue = 0;
    for (final p in points) {
      maxValue = math.max(maxValue, p.amount);
    }
    final labelStep = math.max(1, (points.length / 6).ceil());

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxValue * 1.1,
          minX: 0,
          // A single point still needs a non-empty axis to be drawn.
          maxX: math.max(1, points.length - 1).toDouble(),
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            show: true,
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (value != i.toDouble() || i < 0 || i >= points.length || i % labelStep != 0) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(points[i].label, style: AppTextStyles.caption.copyWith(fontSize: 10)),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots.map((s) {
                final p = points[s.x.toInt().clamp(0, points.length - 1)];
                return LineTooltipItem(
                  '${p.label}\n${money(p.amount)}',
                  const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                );
              }).toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].amount)],
              isCurved: false,
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
    );
  }

  // ─── Shared pieces ────────────────────────────────────────────────────────
  Widget _emptyChart(String text) {
    return SizedBox(
      height: 120,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_chart_outlined, size: 36, color: AppColors.textTertiary),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(String title, String value, Color textCol) {
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: AppTextStyles.bodyMedium),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _load,
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}
