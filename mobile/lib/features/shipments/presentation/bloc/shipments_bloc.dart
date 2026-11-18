import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/network/api_error.dart';
import '../../data/models/shipment_model.dart';
import '../../data/repositories/shipments_repository.dart';

// ─── Events ─────────────────────────────────────────────────────────────────
abstract class ShipmentsEvent extends Equatable {
  const ShipmentsEvent();
  @override
  List<Object?> get props => [];
}

/// Loads the list for a status: 'all', 'pending', 'received'.
class LoadShipmentsEvent extends ShipmentsEvent {
  final String status;
  const LoadShipmentsEvent({this.status = 'all'});
  @override
  List<Object?> get props => [status];
}

/// Reloads the list with the current filter without hiding what is on screen.
class RefreshShipmentsEvent extends ShipmentsEvent {
  final Completer<String?>? completer;
  const RefreshShipmentsEvent({this.completer});
  @override
  List<Object?> get props => [completer];
}

// ─── States ─────────────────────────────────────────────────────────────────
abstract class ShipmentsState extends Equatable {
  const ShipmentsState();
  @override
  List<Object?> get props => [];
}

class ShipmentsInitial extends ShipmentsState {}

class ShipmentsLoading extends ShipmentsState {}

class ShipmentsLoaded extends ShipmentsState {
  final List<ShipmentModel> shipments;
  final String currentFilter;

  /// A request for another filter is in flight; [shipments] are still the previous result.
  final bool isLoading;

  const ShipmentsLoaded({required this.shipments, this.currentFilter = 'all', this.isLoading = false});
  @override
  List<Object?> get props => [shipments, currentFilter, isLoading];
}

class ShipmentsError extends ShipmentsState {
  final String message;
  const ShipmentsError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─── BLoC ───────────────────────────────────────────────────────────────────
/// Holds the shipments LIST only. Shipment detail and the new-shipment form talk to the
/// repository themselves and ask this bloc to refresh afterwards.
class ShipmentsBloc extends Bloc<ShipmentsEvent, ShipmentsState> {
  final ShipmentsRepository shipmentsRepository;

  String _status = 'all';
  int _requestSeq = 0;

  ShipmentsBloc({required this.shipmentsRepository}) : super(ShipmentsInitial()) {
    on<LoadShipmentsEvent>(_onLoadShipments);
    on<RefreshShipmentsEvent>(_onRefreshShipments);
  }

  /// Reloads with the current filter; completes with an error text or null.
  Future<String?> refresh() {
    final completer = Completer<String?>();
    add(RefreshShipmentsEvent(completer: completer));
    return completer.future;
  }

  Future<void> _onLoadShipments(LoadShipmentsEvent event, Emitter<ShipmentsState> emit) async {
    _status = event.status;
    final current = state;
    if (current is ShipmentsLoaded) {
      emit(ShipmentsLoaded(shipments: current.shipments, currentFilter: _status, isLoading: true));
    } else {
      emit(ShipmentsLoading());
    }
    await _fetch(emit, silent: false);
  }

  Future<void> _onRefreshShipments(RefreshShipmentsEvent event, Emitter<ShipmentsState> emit) async {
    if (state is! ShipmentsLoaded) emit(ShipmentsLoading());
    final error = await _fetch(emit, silent: state is ShipmentsLoaded);
    event.completer?.complete(error);
  }

  Future<String?> _fetch(Emitter<ShipmentsState> emit, {required bool silent}) async {
    final seq = ++_requestSeq;
    try {
      final shipments = await shipmentsRepository.getShipments(status: _status);
      if (seq != _requestSeq) return null;
      emit(ShipmentsLoaded(shipments: shipments, currentFilter: _status));
      return null;
    } catch (e) {
      final message = apiErrorMessage(e, fallback: 'Не удалось загрузить поставки');
      if (seq != _requestSeq) return message;
      final current = state;
      if (silent && current is ShipmentsLoaded) {
        // Keep the list the user is looking at; the caller reports the failure.
        if (current.isLoading) emit(ShipmentsLoaded(shipments: current.shipments, currentFilter: current.currentFilter));
        return message;
      }
      emit(ShipmentsError(message));
      return message;
    }
  }
}
