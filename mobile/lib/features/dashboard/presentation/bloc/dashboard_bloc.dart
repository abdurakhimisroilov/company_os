import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/network/api_error.dart';
import '../../data/models/dashboard_stats_model.dart';
import '../../data/repositories/dashboard_repository.dart';

// ─── Events ─────────────────────────────────────────────────────────────────
abstract class DashboardEvent extends Equatable {
  const DashboardEvent();
  @override
  List<Object?> get props => [];
}

/// Loads the figures for [period]; used on first open, on retry and when the
/// period chip changes.
class LoadDashboardStats extends DashboardEvent {
  final String period;
  const LoadDashboardStats({this.period = 'month'});
  @override
  List<Object?> get props => [period];
}

/// Re-reads the figures without hiding what is on screen. Without [period] the
/// current one is kept. [done] completes when the server has answered.
class RefreshDashboardStats extends DashboardEvent {
  final String? period;
  final Completer<void>? done;
  const RefreshDashboardStats({this.period, this.done});
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

  /// Figures for another period are on their way; the shown ones are the previous period's.
  final bool isUpdating;

  /// A background refresh failed; the figures on screen are the last loaded ones.
  final String? notice;
  final int noticeId;

  const DashboardLoaded({
    required this.stats,
    required this.activePeriod,
    this.isUpdating = false,
    this.notice,
    this.noticeId = 0,
  });

  @override
  List<Object?> get props => [stats, activePeriod, isUpdating, notice, noticeId];
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
  DashboardStatsModel? _stats;
  String _statsPeriod = 'month';
  int _request = 0;
  int _noticeId = 0;

  DashboardBloc({required this.dashboardRepository}) : super(DashboardInitial()) {
    on<LoadDashboardStats>(_onLoadStats);
    on<RefreshDashboardStats>(_onRefreshStats);
  }

  String get currentPeriod => _currentPeriod;

  Future<void> _onLoadStats(
    LoadDashboardStats event,
    Emitter<DashboardState> emit,
  ) async {
    _currentPeriod = event.period;
    final request = ++_request;
    final shown = _stats;
    emit(shown == null ? DashboardLoading() : DashboardLoaded(stats: shown, activePeriod: _statsPeriod, isUpdating: true, noticeId: _noticeId));
    try {
      final stats = await dashboardRepository.fetchDashboardStats(period: event.period);
      if (request != _request) return;
      _stats = stats;
      _statsPeriod = event.period;
      emit(DashboardLoaded(stats: stats, activePeriod: event.period, noticeId: _noticeId));
    } catch (e) {
      if (request != _request) return;
      // Figures of another period must not stay under the newly selected chip.
      _stats = null;
      emit(DashboardError(apiErrorMessage(e, fallback: 'Не удалось загрузить показатели')));
    }
  }

  Future<void> _onRefreshStats(
    RefreshDashboardStats event,
    Emitter<DashboardState> emit,
  ) async {
    final period = event.period ?? _currentPeriod;
    _currentPeriod = period;
    final request = ++_request;
    try {
      final stats = await dashboardRepository.fetchDashboardStats(period: period);
      if (request != _request) return;
      _stats = stats;
      _statsPeriod = period;
      emit(DashboardLoaded(stats: stats, activePeriod: period, noticeId: _noticeId));
    } catch (e) {
      if (request != _request) return;
      final message = apiErrorMessage(e, fallback: 'Не удалось обновить показатели');
      final shown = _stats;
      if (shown != null && _statsPeriod == period) {
        emit(DashboardLoaded(stats: shown, activePeriod: period, notice: message, noticeId: ++_noticeId));
      } else {
        _stats = null;
        emit(DashboardError(message));
      }
    } finally {
      final done = event.done;
      if (done != null && !done.isCompleted) done.complete();
    }
  }
}
