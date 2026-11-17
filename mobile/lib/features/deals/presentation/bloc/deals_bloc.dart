import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/models/deal_model.dart';
import '../../data/repositories/deals_repository.dart';

// ─── Events ─────────────────────────────────────────────────────────────────
abstract class DealsEvent extends Equatable {
  const DealsEvent();
  @override
  List<Object?> get props => [];
}

class LoadDealsEvent extends DealsEvent {
  final String? status;
  const LoadDealsEvent({this.status});
  @override
  List<Object?> get props => [status];
}

class LoadDealDetailEvent extends DealsEvent {
  final String id;
  const LoadDealDetailEvent(this.id);
  @override
  List<Object?> get props => [id];
}

class CreateDealEvent extends DealsEvent {
  final Map<String, dynamic> data;
  const CreateDealEvent(this.data);
  @override
  List<Object?> get props => [data];
}

class UpdateDealStatusEvent extends DealsEvent {
  final String dealId;
  final String status;
  const UpdateDealStatusEvent({required this.dealId, required this.status});
  @override
  List<Object?> get props => [dealId, status];
}

class AddDealCommentEvent extends DealsEvent {
  final String dealId;
  final String comment;
  const AddDealCommentEvent({required this.dealId, required this.comment});
  @override
  List<Object?> get props => [dealId, comment];
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
  final String currentFilter;
  const DealsLoaded({required this.deals, this.currentFilter = 'all'});
  @override
  List<Object?> get props => [deals, currentFilter];
}

class DealDetailLoaded extends DealsState {
  final DealModel deal;
  const DealDetailLoaded(this.deal);
  @override
  List<Object?> get props => [deal];
}

class DealsActionSuccess extends DealsState {
  final String message;
  const DealsActionSuccess(this.message);
  @override
  List<Object?> get props => [message];
}

class DealsError extends DealsState {
  final String message;
  const DealsError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─── BLoC ───────────────────────────────────────────────────────────────────
class DealsBloc extends Bloc<DealsEvent, DealsState> {
  final DealsRepository dealsRepository;

  DealsBloc({required this.dealsRepository}) : super(DealsInitial()) {
    on<LoadDealsEvent>(_onLoadDeals);
    on<LoadDealDetailEvent>(_onLoadDetail);
    on<CreateDealEvent>(_onCreateDeal);
    on<UpdateDealStatusEvent>(_onUpdateStatus);
    on<AddDealCommentEvent>(_onAddComment);
  }

  Future<void> _onLoadDeals(LoadDealsEvent event, Emitter<DealsState> emit) async {
    emit(DealsLoading());
    try {
      final deals = await dealsRepository.getDeals(status: event.status);
      emit(DealsLoaded(deals: deals, currentFilter: event.status ?? 'all'));
    } catch (e) {
      emit(DealsError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onLoadDetail(LoadDealDetailEvent event, Emitter<DealsState> emit) async {
    emit(DealsLoading());
    try {
      final deal = await dealsRepository.getDealById(event.id);
      emit(DealDetailLoaded(deal));
    } catch (e) {
      emit(DealsError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onCreateDeal(CreateDealEvent event, Emitter<DealsState> emit) async {
    emit(DealsLoading());
    try {
      await dealsRepository.createDeal(event.data);
      emit(const DealsActionSuccess('Сделка успешно создана'));
      add(const LoadDealsEvent());
    } catch (e) {
      emit(DealsError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onUpdateStatus(UpdateDealStatusEvent event, Emitter<DealsState> emit) async {
    try {
      await dealsRepository.updateDealStatus(event.dealId, event.status);
      emit(const DealsActionSuccess('Статус сделки обновлён'));
      add(LoadDealDetailEvent(event.dealId));
    } catch (e) {
      emit(DealsError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onAddComment(AddDealCommentEvent event, Emitter<DealsState> emit) async {
    try {
      await dealsRepository.addComment(event.dealId, event.comment);
      emit(const DealsActionSuccess('Комментарий добавлен'));
      add(LoadDealDetailEvent(event.dealId));
    } catch (e) {
      emit(DealsError(e.toString().replaceAll('Exception: ', '')));
    }
  }
}
