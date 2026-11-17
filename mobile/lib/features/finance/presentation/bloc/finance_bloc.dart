import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/models/transaction_model.dart';
import '../../data/repositories/finance_repository.dart';

// ─── Events ─────────────────────────────────────────────────────────────────
abstract class FinanceEvent extends Equatable {
  const FinanceEvent();
  @override
  List<Object?> get props => [];
}

class LoadFinanceData extends FinanceEvent {
  final String? type;
  const LoadFinanceData({this.type});
  @override
  List<Object?> get props => [type];
}

class FilterTransactionsByType extends FinanceEvent {
  final String type; // 'all', 'income', 'expense', 'transfer'
  const FilterTransactionsByType(this.type);
  @override
  List<Object?> get props => [type];
}

class CreateIncomeEvent extends FinanceEvent {
  final Map<String, dynamic> data;
  const CreateIncomeEvent(this.data);
  @override
  List<Object?> get props => [data];
}

class CreateExpenseEvent extends FinanceEvent {
  final Map<String, dynamic> data;
  const CreateExpenseEvent(this.data);
  @override
  List<Object?> get props => [data];
}

class PayDebtEvent extends FinanceEvent {
  final Map<String, dynamic> data;
  const PayDebtEvent(this.data);
  @override
  List<Object?> get props => [data];
}

class LoadDebtsEvent extends FinanceEvent {}

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

  const FinanceLoaded({
    required this.accounts,
    required this.transactions,
    this.currentFilter = 'all',
    required this.totalCash,
    required this.totalBank,
  });

  @override
  List<Object?> get props => [accounts, transactions, currentFilter, totalCash, totalBank];
}

class FinanceDebtsLoaded extends FinanceState {
  final List<DebtModel> customerDebts;
  final List<DebtModel> supplierDebts;

  const FinanceDebtsLoaded({
    required this.customerDebts,
    required this.supplierDebts,
  });

  @override
  List<Object?> get props => [customerDebts, supplierDebts];
}

class FinanceActionSuccess extends FinanceState {
  final String message;
  const FinanceActionSuccess(this.message);
  @override
  List<Object?> get props => [message];
}

class FinanceError extends FinanceState {
  final String message;
  const FinanceError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─── BLoC ───────────────────────────────────────────────────────────────────
class FinanceBloc extends Bloc<FinanceEvent, FinanceState> {
  final FinanceRepository financeRepository;
  List<AccountModel> _cachedAccounts = [];
  List<TransactionModel> _allTransactions = [];

  FinanceBloc({required this.financeRepository}) : super(FinanceInitial()) {
    on<LoadFinanceData>(_onLoadFinanceData);
    on<FilterTransactionsByType>(_onFilterTransactions);
    on<CreateIncomeEvent>(_onCreateIncome);
    on<CreateExpenseEvent>(_onCreateExpense);
    on<PayDebtEvent>(_onPayDebt);
    on<LoadDebtsEvent>(_onLoadDebts);
  }

  Future<void> _onLoadFinanceData(LoadFinanceData event, Emitter<FinanceState> emit) async {
    emit(FinanceLoading());
    try {
      final accounts = await financeRepository.getAccounts();
      final transactions = await financeRepository.getTransactions(type: event.type);
      _cachedAccounts = accounts;
      _allTransactions = transactions;

      double cash = 0.0;
      double bank = 0.0;
      for (final a in accounts) {
        if (a.type == 'cash') {
          cash += a.balance;
        } else {
          bank += a.balance;
        }
      }

      emit(FinanceLoaded(
        accounts: accounts,
        transactions: transactions,
        currentFilter: event.type ?? 'all',
        totalCash: cash,
        totalBank: bank,
      ));
    } catch (e) {
      emit(FinanceError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  void _onFilterTransactions(FilterTransactionsByType event, Emitter<FinanceState> emit) {
    if (state is FinanceLoaded) {
      final current = state as FinanceLoaded;
      List<TransactionModel> filtered = _allTransactions;
      if (event.type != 'all') {
        filtered = _allTransactions.where((t) => t.type == event.type).toList();
      }
      emit(FinanceLoaded(
        accounts: current.accounts,
        transactions: filtered,
        currentFilter: event.type,
        totalCash: current.totalCash,
        totalBank: current.totalBank,
      ));
    }
  }

  Future<void> _onCreateIncome(CreateIncomeEvent event, Emitter<FinanceState> emit) async {
    emit(FinanceLoading());
    try {
      await financeRepository.createIncome(event.data);
      emit(const FinanceActionSuccess('Поступление успешно добавлено'));
      add(const LoadFinanceData());
    } catch (e) {
      emit(FinanceError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onCreateExpense(CreateExpenseEvent event, Emitter<FinanceState> emit) async {
    emit(FinanceLoading());
    try {
      await financeRepository.createExpense(event.data);
      emit(const FinanceActionSuccess('Расход успешно добавлен'));
      add(const LoadFinanceData());
    } catch (e) {
      emit(FinanceError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onLoadDebts(LoadDebtsEvent event, Emitter<FinanceState> emit) async {
    emit(FinanceLoading());
    try {
      final cDebts = await financeRepository.getCustomerDebts();
      final sDebts = await financeRepository.getSupplierDebts();
      emit(FinanceDebtsLoaded(customerDebts: cDebts, supplierDebts: sDebts));
    } catch (e) {
      emit(FinanceError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onPayDebt(PayDebtEvent event, Emitter<FinanceState> emit) async {
    emit(FinanceLoading());
    try {
      await financeRepository.payDebt(event.data);
      emit(const FinanceActionSuccess('Оплата задолженности успешно зарегистрирована'));
      add(LoadDebtsEvent());
      add(const LoadFinanceData());
    } catch (e) {
      emit(FinanceError(e.toString().replaceAll('Exception: ', '')));
    }
  }
}
