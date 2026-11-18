import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/network/api_error.dart';
import '../../data/models/supplier_model.dart';
import '../../data/repositories/suppliers_repository.dart';

// ─── Events ─────────────────────────────────────────────────────────────────
abstract class SuppliersEvent extends Equatable {
  const SuppliersEvent();
  @override
  List<Object?> get props => [];
}

/// Loads the supplier list. When a list is already on screen it stays there
/// until the new one arrives. [completer] finishes with null on success or
/// with the error text, so the caller can wait for the request.
class LoadSuppliersEvent extends SuppliersEvent {
  final String? search;
  final Completer<String?>? completer;
  const LoadSuppliersEvent({this.search, this.completer});
  @override
  List<Object?> get props => [search, completer];
}

// ─── States ─────────────────────────────────────────────────────────────────
abstract class SuppliersState extends Equatable {
  const SuppliersState();
  @override
  List<Object?> get props => [];
}

class SuppliersInitial extends SuppliersState {}

class SuppliersLoading extends SuppliersState {}

class SuppliersLoaded extends SuppliersState {
  final List<SupplierModel> suppliers;
  final String search;
  const SuppliersLoaded({required this.suppliers, this.search = ''});
  @override
  List<Object?> get props => [suppliers, search];
}

class SuppliersError extends SuppliersState {
  final String message;
  const SuppliersError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─── BLoC ───────────────────────────────────────────────────────────────────
/// Holds the supplier list only. Supplier cards and forms talk to the
/// repository themselves and then ask this bloc to reload.
class SuppliersBloc extends Bloc<SuppliersEvent, SuppliersState> {
  final SuppliersRepository suppliersRepository;
  String _search = '';
  int _requestId = 0;

  SuppliersBloc({required this.suppliersRepository}) : super(SuppliersInitial()) {
    on<LoadSuppliersEvent>(_onLoadSuppliers);
  }

  Future<void> _onLoadSuppliers(LoadSuppliersEvent event, Emitter<SuppliersState> emit) async {
    if (event.search != null) _search = event.search!.trim();
    final search = _search;
    final requestId = ++_requestId;
    if (state is! SuppliersLoaded) emit(SuppliersLoading());
    try {
      final suppliers = await suppliersRepository.getSuppliers(search: search);
      if (requestId == _requestId) emit(SuppliersLoaded(suppliers: suppliers, search: search));
      event.completer?.complete(null);
    } catch (e) {
      final message = apiErrorMessage(e, fallback: 'Не удалось загрузить поставщиков');
      if (requestId == _requestId && state is! SuppliersLoaded) emit(SuppliersError(message));
      event.completer?.complete(message);
    }
  }
}
