import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/models/dashboard_stats_model.dart';
import '../../data/repositories/dashboard_repository.dart';

// ─── Events ─────────────────────────────────────────────────────────────────
abstract class DashboardEvent extends Equatable {
  const DashboardEvent();
  @override
  List<Object?> get props => [];
}

class LoadDashboardStats extends DashboardEvent {
  final String period;
  const LoadDashboardStats({this.period = 'month'});
  @override
  List<Object?> get props => [period];
}

class RefreshDashboardStats extends DashboardEvent {
  final String period;
  const RefreshDashboardStats({this.period = 'month'});
  @override
  List<Object?> get props => [period];
}

// ─── States ─────────────────────────────────────────────────────────────────
abstract class DashboardState extends Equatable {
  const DashboardState();
  @override
  List<Object?> get props => [];
}

class DashboardInitial extends DashboardState {}

class DashboardLoading extends DashboardState {}

class DashboardLoaded extends DashboardState {
  final DashboardStatsModel stats;
  final String activePeriod;
  const DashboardLoaded({required this.stats, required this.activePeriod});
  @override
  List<Object?> get props => [stats, activePeriod];
}

class DashboardError extends DashboardState {
  final String message;
  const DashboardError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─── BLoC ───────────────────────────────────────────────────────────────────
class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final DashboardRepository dashboardRepository;
  String _currentPeriod = 'month';

  DashboardBloc({required this.dashboardRepository}) : super(DashboardInitial()) {
    on<LoadDashboardStats>(_onLoadStats);
    on<RefreshDashboardStats>(_onRefreshStats);
  }

  Future<void> _onLoadStats(
    LoadDashboardStats event,
    Emitter<DashboardState> emit,
  ) async {
    emit(DashboardLoading());
    _currentPeriod = event.period;
    try {
      final stats = await dashboardRepository.fetchDashboardStats(period: event.period);
      emit(DashboardLoaded(stats: stats, activePeriod: event.period));
    } catch (e) {
      emit(DashboardError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onRefreshStats(
    RefreshDashboardStats event,
    Emitter<DashboardState> emit,
  ) async {
    _currentPeriod = event.period;
    try {
      final stats = await dashboardRepository.fetchDashboardStats(period: event.period);
      emit(DashboardLoaded(stats: stats, activePeriod: event.period));
    } catch (e) {
      emit(DashboardError(e.toString().replaceAll('Exception: ', '')));
    }
  }
}
