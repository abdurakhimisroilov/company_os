import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/models/supplier_model.dart';
import '../../data/repositories/suppliers_repository.dart';

// ─── Events ─────────────────────────────────────────────────────────────────
abstract class SuppliersEvent extends Equatable {
  const SuppliersEvent();
  @override
  List<Object?> get props => [];
}

class LoadSuppliersEvent extends SuppliersEvent {
  final String? search;
  const LoadSuppliersEvent({this.search});
  @override
  List<Object?> get props => [search];
}

class LoadSupplierDetailEvent extends SuppliersEvent {
  final String id;
  const LoadSupplierDetailEvent(this.id);
  @override
  List<Object?> get props => [id];
}

class CreateSupplierEvent extends SuppliersEvent {
  final Map<String, dynamic> data;
  const CreateSupplierEvent(this.data);
  @override
  List<Object?> get props => [data];
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

class SupplierDetailLoaded extends SuppliersState {
  final SupplierModel supplier;
  const SupplierDetailLoaded(this.supplier);
  @override
  List<Object?> get props => [supplier];
}

class SuppliersActionSuccess extends SuppliersState {
  final String message;
  const SuppliersActionSuccess(this.message);
  @override
  List<Object?> get props => [message];
}

class SuppliersError extends SuppliersState {
  final String message;
  const SuppliersError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─── BLoC ───────────────────────────────────────────────────────────────────
class SuppliersBloc extends Bloc<SuppliersEvent, SuppliersState> {
  final SuppliersRepository suppliersRepository;

  SuppliersBloc({required this.suppliersRepository}) : super(SuppliersInitial()) {
    on<LoadSuppliersEvent>(_onLoadSuppliers);
    on<LoadSupplierDetailEvent>(_onLoadDetail);
    on<CreateSupplierEvent>(_onCreateSupplier);
  }

  Future<void> _onLoadSuppliers(LoadSuppliersEvent event, Emitter<SuppliersState> emit) async {
    emit(SuppliersLoading());
    try {
      final suppliers = await suppliersRepository.getSuppliers(search: event.search);
      emit(SuppliersLoaded(suppliers: suppliers, search: event.search ?? ''));
    } catch (e) {
      emit(SuppliersError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onLoadDetail(LoadSupplierDetailEvent event, Emitter<SuppliersState> emit) async {
    emit(SuppliersLoading());
    try {
      final supplier = await suppliersRepository.getSupplierById(event.id);
      emit(SupplierDetailLoaded(supplier));
    } catch (e) {
      emit(SuppliersError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onCreateSupplier(CreateSupplierEvent event, Emitter<SuppliersState> emit) async {
    emit(SuppliersLoading());
    try {
      await suppliersRepository.createSupplier(event.data);
      emit(const SuppliersActionSuccess('Поставщик успешно добавлен'));
      add(const LoadSuppliersEvent());
    } catch (e) {
      emit(SuppliersError(e.toString().replaceAll('Exception: ', '')));
    }
  }
}
