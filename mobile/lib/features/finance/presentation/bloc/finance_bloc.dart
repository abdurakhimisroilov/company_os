import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/network/api_error.dart';
import '../../data/models/transaction_model.dart';
import '../../data/repositories/finance_repository.dart';

// ─── Events ─────────────────────────────────────────────────────────────────
abstract class FinanceEvent extends Equatable {
  const FinanceEvent();
  @override
  List<Object?> get props => [];
}

/// First load of the finance screen (accounts + first page of operations).
class LoadFinanceData extends FinanceEvent {
  final String? type;

  /// Start from "all operations, any date" (the screen was opened anew).
  final bool resetFilters;
  const LoadFinanceData({this.type, this.resetFilters = false});
  @override
  List<Object?> get props => [type, resetFilters];
}

/// Reloads accounts and the first page with the current filters, keeping the
/// content on screen. [done] completes when the server has answered.
class RefreshFinanceData extends FinanceEvent {
  final Completer<void>? done;
  const RefreshFinanceData({this.done});
}

class FilterTransactionsByType extends FinanceEvent {
  final String type; // 'all', 'income', 'expense', 'transfer'
  const FilterTransactionsByType(this.type);
  @override
  List<Object?> get props => [type];
}

/// Both null clears the date filter.
class SetTransactionDateRange extends FinanceEvent {
  final DateTime? startDate;
  final DateTime? endDate;
  const SetTransactionDateRange({this.startDate, this.endDate});
  @override
  List<Object?> get props => [startDate, endDate];
}

class LoadMoreTransactions extends FinanceEvent {
  const LoadMoreTransactions();
}

// ─── States ─────────────────────────────────────────────────────────────────
abstract class FinanceState extends Equatable {
  const FinanceState();
  @override
  List<Object?> get props => [];
}

class FinanceInitial extends FinanceState {}

class FinanceLoading extends FinanceState {}

class FinanceLoaded extends FinanceState {
  final List<AccountModel> accounts;
  final List<TransactionModel> transactions;
  final String currentFilter;
  final double totalCash;
  final double totalBank;

  /// Number of operations matching the filters on the server.
  final int total;
  final DateTime? startDate;
  final DateTime? endDate;

  /// The list is being replaced because a filter changed.
  final bool isListLoading;
  final bool isLoadingMore;

  /// A failure that did not replace the content; shown once as a message.
  final String? notice;
  final int noticeId;

  const FinanceLoaded({
    required this.accounts,
    required this.transactions,
    this.currentFilter = 'all',
    required this.totalCash,
    required this.totalBank,
    this.total = 0,
    this.startDate,
    this.endDate,
    this.isListLoading = false,
    this.isLoadingMore = false,
    this.notice,
    this.noticeId = 0,
  });

  bool get hasMore => transactions.length < total;
  bool get hasDateFilter => startDate != null || endDate != null;

  @override
  List<Object?> get props => [
        accounts,
        transactions,
        currentFilter,
        totalCash,
        totalBank,
        total,
        startDate,
        endDate,
        isListLoading,
        isLoadingMore,
        notice,
        noticeId,
      ];
}

class FinanceError extends FinanceState {
  final String message;
  const FinanceError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─── BLoC ───────────────────────────────────────────────────────────────────
/// Holds only the finance screen's own list. Debts, accounts and the add forms
/// keep their own state, so opening them never replaces this list.
class FinanceBloc extends Bloc<FinanceEvent, FinanceState> {
  final FinanceRepository financeRepository;

  List<AccountModel> _accounts = [];
  List<TransactionModel> _transactions = [];
  int _total = 0;
  String _filter = 'all';
  DateTime? _startDate;
  DateTime? _endDate;
  int _page = 1;
  bool _hasData = false;
  int _listRequest = 0;
  int _noticeId = 0;

  FinanceBloc({required this.financeRepository}) : super(FinanceInitial()) {
    on<LoadFinanceData>(_onLoad);
    on<RefreshFinanceData>(_onRefresh);
    on<FilterTransactionsByType>(_onFilter);
    on<SetTransactionDateRange>(_onDateRange);
    on<LoadMoreTransactions>(_onLoadMore);
  }

  FinanceLoaded _loaded({bool isListLoading = false, bool isLoadingMore = false, String? notice}) {
    double cash = 0.0;
    double bank = 0.0;
    for (final a in _accounts) {
      if (a.type == 'cash') {
        cash += a.balance;
      } else {
        bank += a.balance;
      }
    }
    if (notice != null) _noticeId++;
    return FinanceLoaded(
      accounts: _accounts,
      transactions: _transactions,
      currentFilter: _filter,
      totalCash: cash,
      totalBank: bank,
      total: _total,
      startDate: _startDate,
      endDate: _endDate,
      isListLoading: isListLoading,
      isLoadingMore: isLoadingMore,
      notice: notice,
      noticeId: _noticeId,
    );
  }

  Future<TransactionPage> _fetchFirstPage() {
    return financeRepository.getTransactions(type: _filter, startDate: _startDate, endDate: _endDate, page: 1);
  }

  Future<void> _reloadEverything(Emitter<FinanceState> emit) async {
    final request = ++_listRequest;
    try {
      final results = await Future.wait([financeRepository.getAccounts(), _fetchFirstPage()]);
      if (request != _listRequest) return;
      _accounts = results[0] as List<AccountModel>;
      final page = results[1] as TransactionPage;
      _transactions = page.items;
      _total = page.total;
      _page = 1;
      _hasData = true;
      emit(_loaded());
    } catch (e) {
      if (request != _listRequest) return;
      final message = apiErrorMessage(e, fallback: 'Не удалось загрузить финансы');
      emit(_hasData ? _loaded(notice: message) : FinanceError(message));
    }
  }

  Future<void> _onLoad(LoadFinanceData event, Emitter<FinanceState> emit) async {
    if (event.resetFilters) {
      _filter = 'all';
      _startDate = null;
      _endDate = null;
    }
    if (event.type != null) _filter = event.type!;
    emit(_hasData ? _loaded(isListLoading: true) : FinanceLoading());
    await _reloadEverything(emit);
  }

  Future<void> _onRefresh(RefreshFinanceData event, Emitter<FinanceState> emit) async {
    try {
      if (!_hasData) emit(FinanceLoading());
      await _reloadEverything(emit);
    } finally {
      final done = event.done;
      if (done != null && !done.isCompleted) done.complete();
    }
  }

  Future<void> _reloadList(Emitter<FinanceState> emit) async {
    if (!_hasData) {
      emit(FinanceLoading());
      await _reloadEverything(emit);
      return;
    }
    final request = ++_listRequest;
    _transactions = [];
    _total = 0;
    emit(_loaded(isListLoading: true));
    try {
      final page = await _fetchFirstPage();
      if (request != _listRequest) return;
      _transactions = page.items;
      _total = page.total;
      _page = 1;
      emit(_loaded());
    } catch (e) {
      if (request != _listRequest) return;
      emit(_loaded(notice: apiErrorMessage(e, fallback: 'Не удалось загрузить операции')));
    }
  }

  Future<void> _onFilter(FilterTransactionsByType event, Emitter<FinanceState> emit) async {
    if (event.type == _filter && _hasData) return;
    _filter = event.type;
    await _reloadList(emit);
  }

  Future<void> _onDateRange(SetTransactionDateRange event, Emitter<FinanceState> emit) async {
    _startDate = event.startDate;
    _endDate = event.endDate;
    await _reloadList(emit);
  }

  Future<void> _onLoadMore(LoadMoreTransactions event, Emitter<FinanceState> emit) async {
    final current = state;
    if (current is! FinanceLoaded || current.isLoadingMore || current.isListLoading || !current.hasMore) return;
    final request = _listRequest;
    emit(_loaded(isLoadingMore: true));
    try {
      final page = await financeRepository.getTransactions(
        type: _filter,
        startDate: _startDate,
        endDate: _endDate,
        page: _page + 1,
      );
      if (request != _listRequest) return;
      final known = _transactions.map((t) => t.id).toSet();
      _transactions = [..._transactions, ...page.items.where((t) => !known.contains(t.id))];
      _total = page.total;
      _page += 1;
      // An empty page means the list shrank on the server; stop offering more.
      if (page.items.isEmpty) _total = _transactions.length;
      emit(_loaded());
    } catch (e) {
      if (request != _listRequest) return;
      emit(_loaded(notice: apiErrorMessage(e, fallback: 'Не удалось загрузить операции')));
    }
  }
}
