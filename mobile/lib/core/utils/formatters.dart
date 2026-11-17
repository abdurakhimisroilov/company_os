import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  static final NumberFormat _uzsFormatter = NumberFormat('#,###', 'ru_RU');
  static final NumberFormat _decimalFormatter = NumberFormat('#,##0.00', 'ru_RU');

  /// Formats amount in UZS: "1 248 500 000 сум"
  static String formatUzs(dynamic amount, {bool showCurrency = true}) {
    if (amount == null) return showCurrency ? '0 сум' : '0';
    double value = 0.0;
    if (amount is num) {
      value = amount.toDouble();
    } else if (amount is String) {
      value = double.tryParse(amount.replaceAll(' ', '')) ?? 0.0;
    }
    final formatted = _uzsFormatter.format(value.round()).replaceAll(',', ' ');
    return showCurrency ? '$formatted сум' : formatted;
  }

  /// Formats amount with decimals: "1 248.50"
  static String formatDecimal(dynamic amount) {
    if (amount == null) return '0.00';
    double value = 0.0;
    if (amount is num) {
      value = amount.toDouble();
    } else if (amount is String) {
      value = double.tryParse(amount.replaceAll(' ', '')) ?? 0.0;
    }
    return _decimalFormatter.format(value).replaceAll(',', ' ');
  }

  /// Compact currency format: 1.2M, 500K
  static String formatCompact(dynamic amount) {
    if (amount == null) return '0';
    double value = (amount is num) ? amount.toDouble() : (double.tryParse(amount.toString()) ?? 0);
    if (value.abs() >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(1)} млрд';
    } else if (value.abs() >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)} млн';
    } else if (value.abs() >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)} тыс';
    }
    return value.toStringAsFixed(0);
  }

  /// Date format: "12.11.2026"
  static String formatDate(dynamic date) {
    if (date == null) return '';
    DateTime dt;
    if (date is DateTime) {
      dt = date;
    } else if (date is String) {
      dt = DateTime.tryParse(date) ?? DateTime.now();
    } else {
      return '';
    }
    return DateFormat('dd.MM.yyyy').format(dt);
  }

  /// Date & time format: "12.11.2026 14:30"
  static String formatDateTime(dynamic date) {
    if (date == null) return '';
    DateTime dt;
    if (date is DateTime) {
      dt = date;
    } else if (date is String) {
      dt = DateTime.tryParse(date) ?? DateTime.now();
    } else {
      return '';
    }
    return DateFormat('dd.MM.yyyy HH:mm').format(dt);
  }

  /// Time format: "14:30"
  static String formatTime(dynamic date) {
    if (date == null) return '';
    DateTime dt = (date is DateTime) ? date : (DateTime.tryParse(date.toString()) ?? DateTime.now());
    return DateFormat('HH:mm').format(dt);
  }

  /// Relative date: "Сегодня", "Вчера" or "dd.MM.yyyy"
  static String formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final aDate = DateTime(date.year, date.month, date.day);
    if (aDate == today) return 'Сегодня';
    if (aDate == today.subtract(const Duration(days: 1))) return 'Вчера';
    return formatDate(date);
  }

  /// Percent format: "+12.5%" or "-3.2%"
  static String formatPercentage(double percent, {bool includeSign = true}) {
    final sign = includeSign && percent > 0 ? '+' : '';
    return '$sign${percent.toStringAsFixed(1)}%';
  }

  /// Phone format: "+998 90 123 45 67"
  static String formatPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 12 && digits.startsWith('998')) {
      return '+998 ${digits.substring(3, 5)} ${digits.substring(5, 8)} ${digits.substring(8, 10)} ${digits.substring(10, 12)}';
    } else if (digits.length == 9) {
      return '+998 ${digits.substring(0, 2)} ${digits.substring(2, 5)} ${digits.substring(5, 7)} ${digits.substring(7, 9)}';
    }
    return phone;
  }
}
