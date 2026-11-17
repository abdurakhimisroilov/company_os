import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/models/shipment_model.dart';
import '../../data/repositories/shipments_repository.dart';

// ─── Events ─────────────────────────────────────────────────────────────────
abstract class ShipmentsEvent extends Equatable {
  const ShipmentsEvent();
  @override
  List<Object?> get props => [];
}

class LoadShipmentsEvent extends ShipmentsEvent {
  final String? status;
  const LoadShipmentsEvent({this.status});
  @override
  List<Object?> get props => [status];
}

class LoadShipmentDetailEvent extends ShipmentsEvent {
  final String id;
  const LoadShipmentDetailEvent(this.id);
  @override
  List<Object?> get props => [id];
}

class CreateShipmentEvent extends ShipmentsEvent {
  final Map<String, dynamic> data;
  const CreateShipmentEvent(this.data);
  @override
  List<Object?> get props => [data];
}

class ConfirmShipmentEvent extends ShipmentsEvent {
  final String id;
  const ConfirmShipmentEvent(this.id);
  @override
  List<Object?> get props => [id];
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
  const ShipmentsLoaded({required this.shipments, this.currentFilter = 'all'});
  @override
  List<Object?> get props => [shipments, currentFilter];
}

class ShipmentDetailLoaded extends ShipmentsState {
  final ShipmentModel shipment;
  const ShipmentDetailLoaded(this.shipment);
  @override
  List<Object?> get props => [shipment];
}

class ShipmentsActionSuccess extends ShipmentsState {
  final String message;
  const ShipmentsActionSuccess(this.message);
  @override
  List<Object?> get props => [message];
}

class ShipmentsError extends ShipmentsState {
  final String message;
  const ShipmentsError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─── BLoC ───────────────────────────────────────────────────────────────────
class ShipmentsBloc extends Bloc<ShipmentsEvent, ShipmentsState> {
  final ShipmentsRepository shipmentsRepository;

  ShipmentsBloc({required this.shipmentsRepository}) : super(ShipmentsInitial()) {
    on<LoadShipmentsEvent>(_onLoadShipments);
    on<LoadShipmentDetailEvent>(_onLoadDetail);
    on<CreateShipmentEvent>(_onCreateShipment);
    on<ConfirmShipmentEvent>(_onConfirmShipment);
  }

  Future<void> _onLoadShipments(LoadShipmentsEvent event, Emitter<ShipmentsState> emit) async {
    emit(ShipmentsLoading());
    try {
      final shipments = await shipmentsRepository.getShipments(status: event.status);
      emit(ShipmentsLoaded(shipments: shipments, currentFilter: event.status ?? 'all'));
    } catch (e) {
      emit(ShipmentsError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onLoadDetail(LoadShipmentDetailEvent event, Emitter<ShipmentsState> emit) async {
    emit(ShipmentsLoading());
    try {
      final shipment = await shipmentsRepository.getShipmentById(event.id);
      emit(ShipmentDetailLoaded(shipment));
    } catch (e) {
      emit(ShipmentsError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onCreateShipment(CreateShipmentEvent event, Emitter<ShipmentsState> emit) async {
    emit(ShipmentsLoading());
    try {
      await shipmentsRepository.createShipment(event.data);
      emit(const ShipmentsActionSuccess('Поставка успешно создана'));
      add(const LoadShipmentsEvent());
    } catch (e) {
      emit(ShipmentsError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onConfirmShipment(ConfirmShipmentEvent event, Emitter<ShipmentsState> emit) async {
    emit(ShipmentsLoading());
    try {
      await shipmentsRepository.confirmShipment(event.id);
      emit(const ShipmentsActionSuccess('Приёмка товара подтверждена'));
      add(LoadShipmentDetailEvent(event.id));
    } catch (e) {
      emit(ShipmentsError(e.toString().replaceAll('Exception: ', '')));
    }
  }
}
