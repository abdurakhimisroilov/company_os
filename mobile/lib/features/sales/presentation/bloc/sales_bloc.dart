import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/network/api_error.dart';
import '../../data/models/sale_model.dart';
import '../../data/repositories/sales_repository.dart';

// ─── Events ─────────────────────────────────────────────────────────────────
abstract class SalesEvent extends Equatable {
  const SalesEvent();
  @override
  List<Object?> get props => [];
}

/// Loads the list for a payment status: 'all', 'paid', 'partial', 'unpaid'.
class LoadSalesEvent extends SalesEvent {
  final String status;
  const LoadSalesEvent({this.status = 'all'});
  @override
  List<Object?> get props => [status];
}

/// Reloads the list with the current filter without hiding what is on screen.
class RefreshSalesEvent extends SalesEvent {
  final Completer<String?>? completer;
  const RefreshSalesEvent({this.completer});
  @override
  List<Object?> get props => [completer];
}

// ─── States ─────────────────────────────────────────────────────────────────
abstract class SalesState extends Equatable {
  const SalesState();
  @override
  List<Object?> get props => [];
}

class SalesInitial extends SalesState {}

class SalesLoading extends SalesState {}

class SalesLoaded extends SalesState {
  final List<SaleModel> sales;
  final String currentFilter;

  /// A request for another filter is in flight; [sales] are still the previous result.
  final bool isLoading;

  const SalesLoaded({required this.sales, this.currentFilter = 'all', this.isLoading = false});
  @override
  List<Object?> get props => [sales, currentFilter, isLoading];
}

class SalesError extends SalesState {
  final String message;
  const SalesError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─── BLoC ───────────────────────────────────────────────────────────────────
/// Holds the sales LIST only. Sale detail and the new-sale form talk to the
/// repository themselves and ask this bloc to refresh afterwards.
class SalesBloc extends Bloc<SalesEvent, SalesState> {
  final SalesRepository salesRepository;

  String _status = 'all';
  int _requestSeq = 0;

  SalesBloc({required this.salesRepository}) : super(SalesInitial()) {
    on<LoadSalesEvent>(_onLoadSales);
    on<RefreshSalesEvent>(_onRefreshSales);
  }

  /// Reloads with the current filter; completes with an error text or null.
  Future<String?> refresh() {
    final completer = Completer<String?>();
    add(RefreshSalesEvent(completer: completer));
    return completer.future;
  }

  Future<void> _onLoadSales(LoadSalesEvent event, Emitter<SalesState> emit) async {
    _status = event.status;
    final current = state;
    if (current is SalesLoaded) {
      emit(SalesLoaded(sales: current.sales, currentFilter: _status, isLoading: true));
    } else {
      emit(SalesLoading());
    }
    await _fetch(emit, silent: false);
  }

  Future<void> _onRefreshSales(RefreshSalesEvent event, Emitter<SalesState> emit) async {
    if (state is! SalesLoaded) emit(SalesLoading());
    final error = await _fetch(emit, silent: state is SalesLoaded);
    event.completer?.complete(error);
  }

  Future<String?> _fetch(Emitter<SalesState> emit, {required bool silent}) async {
    final seq = ++_requestSeq;
    try {
      final sales = await salesRepository.getSales(status: _status);
      if (seq != _requestSeq) return null;
      emit(SalesLoaded(sales: sales, currentFilter: _status));
      return null;
    } catch (e) {
      final message = apiErrorMessage(e, fallback: 'Не удалось загрузить продажи');
      if (seq != _requestSeq) return message;
      final current = state;
      if (silent && current is SalesLoaded) {
        // Keep the list the user is looking at; the caller reports the failure.
        if (current.isLoading) emit(SalesLoaded(sales: current.sales, currentFilter: current.currentFilter));
        return message;
      }
      emit(SalesError(message));
      return message;
    }
  }
}
