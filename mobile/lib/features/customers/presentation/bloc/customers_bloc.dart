import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/network/api_error.dart';
import '../../data/models/customer_model.dart';
import '../../data/repositories/customers_repository.dart';

// ─── Events ─────────────────────────────────────────────────────────────────
abstract class CustomersEvent extends Equatable {
  const CustomersEvent();
  @override
  List<Object?> get props => [];
}

/// Loads the customer list. When a list is already on screen it stays there
/// until the new one arrives. [completer] finishes with null on success or
/// with the error text, so the caller can wait for the request.
class LoadCustomersEvent extends CustomersEvent {
  final String? search;
  final Completer<String?>? completer;
  const LoadCustomersEvent({this.search, this.completer});
  @override
  List<Object?> get props => [search, completer];
}

// ─── States ─────────────────────────────────────────────────────────────────
abstract class CustomersState extends Equatable {
  const CustomersState();
  @override
  List<Object?> get props => [];
}

class CustomersInitial extends CustomersState {}

class CustomersLoading extends CustomersState {}

class CustomersLoaded extends CustomersState {
  final List<CustomerModel> customers;
  final String search;
  const CustomersLoaded({required this.customers, this.search = ''});
  @override
  List<Object?> get props => [customers, search];
}

class CustomersError extends CustomersState {
  final String message;
  const CustomersError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─── BLoC ───────────────────────────────────────────────────────────────────
/// Holds the customer list only. Customer cards and forms talk to the
/// repository themselves and then ask this bloc to reload.
class CustomersBloc extends Bloc<CustomersEvent, CustomersState> {
  final CustomersRepository customersRepository;
  String _search = '';
  int _requestId = 0;

  CustomersBloc({required this.customersRepository}) : super(CustomersInitial()) {
    on<LoadCustomersEvent>(_onLoadCustomers);
  }

  Future<void> _onLoadCustomers(LoadCustomersEvent event, Emitter<CustomersState> emit) async {
    if (event.search != null) _search = event.search!.trim();
    final search = _search;
    final requestId = ++_requestId;
    if (state is! CustomersLoaded) emit(CustomersLoading());
    try {
      final customers = await customersRepository.getCustomers(search: search);
      if (requestId == _requestId) emit(CustomersLoaded(customers: customers, search: search));
      event.completer?.complete(null);
    } catch (e) {
      final message = apiErrorMessage(e, fallback: 'Не удалось загрузить клиентов');
      if (requestId == _requestId && state is! CustomersLoaded) emit(CustomersError(message));
      event.completer?.complete(message);
    }
  }
}
