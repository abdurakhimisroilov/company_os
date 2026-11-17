import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/models/customer_model.dart';
import '../../data/repositories/customers_repository.dart';

// ─── Events ─────────────────────────────────────────────────────────────────
abstract class CustomersEvent extends Equatable {
  const CustomersEvent();
  @override
  List<Object?> get props => [];
}

class LoadCustomersEvent extends CustomersEvent {
  final String? search;
  const LoadCustomersEvent({this.search});
  @override
  List<Object?> get props => [search];
}

class LoadCustomerDetailEvent extends CustomersEvent {
  final String id;
  const LoadCustomerDetailEvent(this.id);
  @override
  List<Object?> get props => [id];
}

class CreateCustomerEvent extends CustomersEvent {
  final Map<String, dynamic> data;
  const CreateCustomerEvent(this.data);
  @override
  List<Object?> get props => [data];
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

class CustomerDetailLoaded extends CustomersState {
  final CustomerModel customer;
  const CustomerDetailLoaded(this.customer);
  @override
  List<Object?> get props => [customer];
}

class CustomersActionSuccess extends CustomersState {
  final String message;
  const CustomersActionSuccess(this.message);
  @override
  List<Object?> get props => [message];
}

class CustomersError extends CustomersState {
  final String message;
  const CustomersError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─── BLoC ───────────────────────────────────────────────────────────────────
class CustomersBloc extends Bloc<CustomersEvent, CustomersState> {
  final CustomersRepository customersRepository;

  CustomersBloc({required this.customersRepository}) : super(CustomersInitial()) {
    on<LoadCustomersEvent>(_onLoadCustomers);
    on<LoadCustomerDetailEvent>(_onLoadDetail);
    on<CreateCustomerEvent>(_onCreateCustomer);
  }

  Future<void> _onLoadCustomers(LoadCustomersEvent event, Emitter<CustomersState> emit) async {
    emit(CustomersLoading());
    try {
      final customers = await customersRepository.getCustomers(search: event.search);
      emit(CustomersLoaded(customers: customers, search: event.search ?? ''));
    } catch (e) {
      emit(CustomersError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onLoadDetail(LoadCustomerDetailEvent event, Emitter<CustomersState> emit) async {
    emit(CustomersLoading());
    try {
      final customer = await customersRepository.getCustomerById(event.id);
      emit(CustomerDetailLoaded(customer));
    } catch (e) {
      emit(CustomersError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onCreateCustomer(CreateCustomerEvent event, Emitter<CustomersState> emit) async {
    emit(CustomersLoading());
    try {
      await customersRepository.createCustomer(event.data);
      emit(const CustomersActionSuccess('Клиент успешно добавлен'));
      add(const LoadCustomersEvent());
    } catch (e) {
      emit(CustomersError(e.toString().replaceAll('Exception: ', '')));
    }
  }
}
