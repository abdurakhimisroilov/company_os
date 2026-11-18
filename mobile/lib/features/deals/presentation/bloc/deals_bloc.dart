import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/network/api_error.dart';
import '../../data/models/deal_model.dart';
import '../../data/repositories/deals_repository.dart';

// ─── Events ─────────────────────────────────────────────────────────────────
abstract class DealsEvent extends Equatable {
  const DealsEvent();
  @override
  List<Object?> get props => [];
}

/// Loads every deal of the organization. A list already on screen stays there
/// until the new one arrives. [completer] finishes with null on success or
/// with the error text, so the caller can wait for the request.
class LoadDealsEvent extends DealsEvent {
  final Completer<String?>? completer;
  const LoadDealsEvent({this.completer});
  @override
  List<Object?> get props => [completer];
}

// ─── States ─────────────────────────────────────────────────────────────────
abstract class DealsState extends Equatable {
  const DealsState();
  @override
  List<Object?> get props => [];
}

class DealsInitial extends DealsState {}

class DealsLoading extends DealsState {}

class DealsLoaded extends DealsState {
  final List<DealModel> deals;
  const DealsLoaded({required this.deals});
  @override
  List<Object?> get props => [deals];
}

class DealsError extends DealsState {
  final String message;
  const DealsError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─── BLoC ───────────────────────────────────────────────────────────────────
/// Holds the deal list only. The deal card and the deal form talk to the
/// repository themselves and then ask this bloc to reload.
class DealsBloc extends Bloc<DealsEvent, DealsState> {
  final DealsRepository dealsRepository;
  int _requestId = 0;

  DealsBloc({required this.dealsRepository}) : super(DealsInitial()) {
    on<LoadDealsEvent>(_onLoadDeals);
  }

  Future<void> _onLoadDeals(LoadDealsEvent event, Emitter<DealsState> emit) async {
    final requestId = ++_requestId;
    if (state is! DealsLoaded) emit(DealsLoading());
    try {
      final deals = await dealsRepository.getDeals();
      if (requestId == _requestId) emit(DealsLoaded(deals: deals));
      event.completer?.complete(null);
    } catch (e) {
      final message = apiErrorMessage(e, fallback: 'Не удалось загрузить сделки');
      if (requestId == _requestId && state is! DealsLoaded) emit(DealsError(message));
      event.completer?.complete(message);
    }
  }
}
