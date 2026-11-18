import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart' as xl;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;
import '../../../core/utils/formatters.dart';
import 'models/report_model.dart';

/// Builds report files on the device from an already loaded [ReportModel];
/// the server has no export routes.
class ReportExporter {
  ReportExporter._();

  static String _amount(num value) => Formatters.formatUzs(value, showCurrency: false);

  static String _stamp() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${n.year}${two(n.month)}${two(n.day)}_${two(n.hour)}${two(n.minute)}${two(n.second)}';
  }

  static String _range(ReportModel r) {
    if (r.from.isEmpty || r.to.isEmpty) return '';
    final from = Formatters.formatDate(r.from);
    final to = Formatters.formatDate(r.to);
    return from == to ? from : '$from — $to';
  }

  static Future<File> _write(String name, List<int> bytes) async {
    final dir = Directory('${(await getTemporaryDirectory()).path}/reports');
    await dir.create(recursive: true);
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static List<List<String>> _summary(ReportModel r) => [
        ['Поступления', _amount(r.income)],
        ['Расходы', _amount(r.expenses)],
        ['Чистая прибыль', _amount(r.netProfit)],
        ['Выручка от продаж', _amount(r.revenue)],
        ['Количество продаж', r.salesCount.toString()],
        ['Себестоимость проданного', _amount(r.costOfGoods)],
        ['Валовая прибыль', _amount(r.grossProfit)],
      ];

  /// [currency] is the label to print next to amounts ("сум", "USD"), may be empty.
  static Future<Uint8List> buildPdfBytes(ReportModel r, {required String periodLabel, required String currency}) async {
    // Bundled so PDFs with Cyrillic text can be made offline.
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));

    final doc = pw.Document(theme: pw.ThemeData.withFont(base: regular, bold: bold));
    final unit = currency.isEmpty ? '' : ', $currency';
    final range = _range(r);
    final headerStyle = pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10);
    const cellStyle = pw.TextStyle(fontSize: 10);

    pw.Widget table(List<String> headers, List<List<String>> rows) {
      return pw.TableHelper.fromTextArray(
        headers: headers,
        data: rows,
        headerStyle: headerStyle,
        cellStyle: cellStyle,
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
        cellAlignments: {for (var i = 1; i < headers.length; i++) i: pw.Alignment.centerRight},
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      );
    }

    pw.Widget section(String title) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 18, bottom: 6),
          child: pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
        );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Text('Финансовый отчёт', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 20)),
          pw.SizedBox(height: 4),
          pw.Text(
            range.isEmpty ? 'Период: $periodLabel' : 'Период: $periodLabel ($range)',
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
          ),
          pw.Text(
            'Сформирован: ${Formatters.formatDateTime(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
          ),
          section('Итоги'),
          table(['Показатель', 'Значение$unit'], _summary(r)),
          if (r.monthlyData.isNotEmpty) ...[
            section('Поступления и расходы по датам'),
            table(
              ['Дата', 'Поступления$unit', 'Расходы$unit'],
              r.monthlyData.map((m) => [m.month, _amount(m.income), _amount(m.expense)]).toList(),
            ),
          ],
          if (r.expensesByCategory.isNotEmpty) ...[
            section('Расходы по категориям'),
            table(
              ['Категория', 'Сумма$unit'],
              r.expensesByCategory.map((c) => [c.category, _amount(c.amount)]).toList(),
            ),
          ],
          if (r.salesTrend.isNotEmpty) ...[
            section('Продажи по датам'),
            table(
              ['Дата', 'Сумма$unit'],
              r.salesTrend.map((p) => [p.label, _amount(p.amount)]).toList(),
            ),
          ],
        ],
      ),
    );
    return doc.save();
  }

  static Future<File> savePdf(Uint8List bytes) => _write('report_${_stamp()}.pdf', bytes);

  static Future<File> exportExcel(ReportModel r, {required String periodLabel, required String currency}) async {
    final book = xl.Excel.createExcel();
    final defaultSheet = book.getDefaultSheet();
    const summaryName = 'Итоги';
    final summary = book[summaryName];
    book.setDefaultSheet(summaryName);
    if (defaultSheet != null && defaultSheet != summaryName) book.delete(defaultSheet);

    xl.CellValue text(String v) => xl.TextCellValue(v);
    xl.CellValue number(num v) => xl.DoubleCellValue(v.toDouble());
    final unit = currency.isEmpty ? '' : ', $currency';
    final range = _range(r);

    summary.appendRow([text('Финансовый отчёт')]);
    summary.appendRow([text('Период'), text(range.isEmpty ? periodLabel : '$periodLabel ($range)')]);
    summary.appendRow([text('Сформирован'), text(Formatters.formatDateTime(DateTime.now()))]);
    summary.appendRow([text('')]);
    summary.appendRow([text('Показатель'), text('Значение$unit')]);
    summary.appendRow([text('Поступления'), number(r.income)]);
    summary.appendRow([text('Расходы'), number(r.expenses)]);
    summary.appendRow([text('Чистая прибыль'), number(r.netProfit)]);
    summary.appendRow([text('Выручка от продаж'), number(r.revenue)]);
    summary.appendRow([text('Количество продаж'), xl.IntCellValue(r.salesCount)]);
    summary.appendRow([text('Себестоимость проданного'), number(r.costOfGoods)]);
    summary.appendRow([text('Валовая прибыль'), number(r.grossProfit)]);

    if (r.monthlyData.isNotEmpty) {
      final sheet = book['Движение денег'];
      sheet.appendRow([text('Дата'), text('Поступления$unit'), text('Расходы$unit')]);
      for (final m in r.monthlyData) {
        sheet.appendRow([text(m.date.isEmpty ? m.month : m.date), number(m.income), number(m.expense)]);
      }
    }
    if (r.expensesByCategory.isNotEmpty) {
      final sheet = book['Расходы по категориям'];
      sheet.appendRow([text('Категория'), text('Сумма$unit')]);
      for (final c in r.expensesByCategory) {
        sheet.appendRow([text(c.category), number(c.amount)]);
      }
    }
    if (r.salesTrend.isNotEmpty) {
      final sheet = book['Продажи'];
      sheet.appendRow([text('Дата'), text('Сумма$unit')]);
      for (final p in r.salesTrend) {
        sheet.appendRow([text(p.date.isEmpty ? p.label : p.date), number(p.amount)]);
      }
    }

    final bytes = book.encode();
    if (bytes == null) throw Exception('Не удалось сформировать файл Excel');
    return _write('report_${_stamp()}.xlsx', bytes);
  }
}
