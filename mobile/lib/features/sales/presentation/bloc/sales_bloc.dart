import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/models/sale_model.dart';
import '../../data/repositories/sales_repository.dart';

// ─── Events ─────────────────────────────────────────────────────────────────
abstract class SalesEvent extends Equatable {
  const SalesEvent();
  @override
  List<Object?> get props => [];
}

class LoadSalesEvent extends SalesEvent {
  final String? status;
  const LoadSalesEvent({this.status});
  @override
  List<Object?> get props => [status];
}

class LoadSaleDetailEvent extends SalesEvent {
  final String id;
  const LoadSaleDetailEvent(this.id);
  @override
  List<Object?> get props => [id];
}

class CreateSaleEvent extends SalesEvent {
  final Map<String, dynamic> data;
  const CreateSaleEvent(this.data);
  @override
  List<Object?> get props => [data];
}

class AddSalePaymentEvent extends SalesEvent {
  final String saleId;
  final double amount;
  final String method;
  const AddSalePaymentEvent({required this.saleId, required this.amount, required this.method});
  @override
  List<Object?> get props => [saleId, amount, method];
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
  const SalesLoaded({required this.sales, this.currentFilter = 'all'});
  @override
  List<Object?> get props => [sales, currentFilter];
}

class SaleDetailLoaded extends SalesState {
  final SaleModel sale;
  const SaleDetailLoaded(this.sale);
  @override
  List<Object?> get props => [sale];
}

class SalesActionSuccess extends SalesState {
  final String message;
  const SalesActionSuccess(this.message);
  @override
  List<Object?> get props => [message];
}

class SalesError extends SalesState {
  final String message;
  const SalesError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─── BLoC ───────────────────────────────────────────────────────────────────
class SalesBloc extends Bloc<SalesEvent, SalesState> {
  final SalesRepository salesRepository;

  SalesBloc({required this.salesRepository}) : super(SalesInitial()) {
    on<LoadSalesEvent>(_onLoadSales);
    on<LoadSaleDetailEvent>(_onLoadDetail);
    on<CreateSaleEvent>(_onCreateSale);
    on<AddSalePaymentEvent>(_onAddPayment);
  }

  Future<void> _onLoadSales(LoadSalesEvent event, Emitter<SalesState> emit) async {
    emit(SalesLoading());
    try {
      final sales = await salesRepository.getSales(status: event.status);
      emit(SalesLoaded(sales: sales, currentFilter: event.status ?? 'all'));
    } catch (e) {
      emit(SalesError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onLoadDetail(LoadSaleDetailEvent event, Emitter<SalesState> emit) async {
    emit(SalesLoading());
    try {
      final sale = await salesRepository.getSaleById(event.id);
      emit(SaleDetailLoaded(sale));
    } catch (e) {
      emit(SalesError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onCreateSale(CreateSaleEvent event, Emitter<SalesState> emit) async {
    emit(SalesLoading());
    try {
      await salesRepository.createSale(event.data);
      emit(const SalesActionSuccess('Продажа успешно оформлена'));
      add(const LoadSalesEvent());
    } catch (e) {
      emit(SalesError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onAddPayment(AddSalePaymentEvent event, Emitter<SalesState> emit) async {
    emit(SalesLoading());
    try {
      await salesRepository.addPayment(event.saleId, event.amount, event.method);
      emit(const SalesActionSuccess('Оплата успешно принята'));
      add(LoadSaleDetailEvent(event.saleId));
    } catch (e) {
      emit(SalesError(e.toString().replaceAll('Exception: ', '')));
    }
  }
}
