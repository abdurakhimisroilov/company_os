import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/network/api_error.dart';
import '../../data/models/report_model.dart';
import '../../data/repositories/reports_repository.dart';

// ─── Events ─────────────────────────────────────────────────────────────────
abstract class ReportsEvent extends Equatable {
  const ReportsEvent();
  @override
  List<Object?> get props => [];
}

class LoadReportEvent extends ReportsEvent {
  final String period; // 'today', 'week', 'month', 'year'
  const LoadReportEvent({this.period = 'month'});
  @override
  List<Object?> get props => [period];
}

/// Re-reads the current period without hiding the report. [done] completes
/// when the server has answered.
class RefreshReportEvent extends ReportsEvent {
  final Completer<void>? done;
  const RefreshReportEvent({this.done});
}

// ─── States ─────────────────────────────────────────────────────────────────
abstract class ReportsState extends Equatable {
  const ReportsState();
  @override
  List<Object?> get props => [];
}

class ReportsInitial extends ReportsState {}

class ReportsLoading extends ReportsState {}

class ReportsLoaded extends ReportsState {
  final ReportModel report;

  /// The period [report] was loaded for.
  final String period;

  /// A failed refresh; the report on screen is the last loaded one.
  final String? notice;
  final int noticeId;
  const ReportsLoaded({required this.report, required this.period, this.notice, this.noticeId = 0});
  @override
  List<Object?> get props => [report, period, notice, noticeId];
}

class ReportsError extends ReportsState {
  final String message;
  const ReportsError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─── BLoC ───────────────────────────────────────────────────────────────────
class ReportsBloc extends Bloc<ReportsEvent, ReportsState> {
  final ReportsRepository reportsRepository;
  String _period = 'month';
  int _request = 0;
  int _noticeId = 0;

  ReportsBloc({required this.reportsRepository}) : super(ReportsInitial()) {
    on<LoadReportEvent>(_onLoadReport);
    on<RefreshReportEvent>(_onRefresh);
  }

  Future<void> _onLoadReport(LoadReportEvent event, Emitter<ReportsState> emit) async {
    _period = event.period;
    final request = ++_request;
    // Figures of another period must not sit under the newly selected chip.
    emit(ReportsLoading());
    try {
      final report = await reportsRepository.getFinancialReport(period: event.period);
      if (request != _request) return;
      emit(ReportsLoaded(report: report, period: event.period, noticeId: _noticeId));
    } catch (e) {
      if (request != _request) return;
      emit(ReportsError(apiErrorMessage(e, fallback: 'Не удалось загрузить отчёт')));
    }
  }

  Future<void> _onRefresh(RefreshReportEvent event, Emitter<ReportsState> emit) async {
    final request = ++_request;
    final period = _period;
    try {
      final report = await reportsRepository.getFinancialReport(period: period);
      if (request != _request) return;
      emit(ReportsLoaded(report: report, period: period, noticeId: _noticeId));
    } catch (e) {
      if (request != _request) return;
      final message = apiErrorMessage(e, fallback: 'Не удалось обновить отчёт');
      final current = state;
      if (current is ReportsLoaded && current.period == period) {
        emit(ReportsLoaded(report: current.report, period: period, notice: message, noticeId: ++_noticeId));
      } else {
        emit(ReportsError(message));
      }
    } finally {
      final done = event.done;
      if (done != null && !done.isCompleted) done.complete();
    }
  }
}
