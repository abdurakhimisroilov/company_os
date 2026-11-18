import 'package:flutter/foundation.dart';
import '../../../core/di/injection.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/services/app_session.dart';
import '../../../core/utils/formatters.dart';

/// Currency of the organization the user is working in (`GET /companies/current`).
/// Empty until the server has answered, so no amount is labelled with a guessed currency.
class CompanyCurrency extends ValueNotifier<String> {
  CompanyCurrency._() : super('') {
    AppSession.instance.addListener(_onSessionChanged);
  }

  static final CompanyCurrency instance = CompanyCurrency._();

  Future<void>? _loading;

  void _onSessionChanged() {
    _loading = null;
    value = '';
  }

  /// Sets the code when another screen has already loaded the organization.
  void set(String code) {
    final clean = code.trim().toUpperCase();
    if (clean.isNotEmpty) value = clean;
  }

  /// Loads the currency once per session; failures leave amounts unlabelled.
  Future<void> ensureLoaded() {
    if (value.isNotEmpty) return Future.value();
    return _loading ??= _load().whenComplete(() => _loading = null);
  }

  Future<void> _load() async {
    final session = AppSession.instance.value;
    try {
      final response = await getIt<ApiClient>().get(ApiEndpoints.currentCompany);
      final body = response.data;
      final data = body is Map ? body['data'] : null;
      if (session != AppSession.instance.value) return;
      if (data is Map && data['currency'] != null) set(data['currency'].toString());
    } catch (_) {
      // The amounts stay readable without a currency label.
    }
  }

  /// Short label shown after an amount: UZS is written as «сум».
  String get label => value == 'UZS' ? 'сум' : value;
}

/// "1 248 500 сум" in the organization's currency.
String money(num amount) {
  final text = Formatters.formatUzs(amount, showCurrency: false);
  final label = CompanyCurrency.instance.label;
  return label.isEmpty ? text : '$text $label';
}

/// "1.2 млн сум" in the organization's currency.
String moneyCompact(num amount) {
  final text = Formatters.formatCompact(amount);
  final label = CompanyCurrency.instance.label;
  return label.isEmpty ? text : '$text $label';
}
