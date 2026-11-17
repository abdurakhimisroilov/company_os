import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
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
  final String type; // 'financial', 'sales', 'inventory'
  const LoadReportEvent({this.period = 'month', this.type = 'financial'});
  @override
  List<Object?> get props => [period, type];
}

class ExportReportEvent extends ReportsEvent {
  final String format; // 'pdf', 'excel'
  final String period;
  const ExportReportEvent({required this.format, this.period = 'month'});
  @override
  List<Object?> get props => [format, period];
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
  final String period;
  final String reportType;
  const ReportsLoaded({required this.report, required this.period, required this.reportType});
  @override
  List<Object?> get props => [report, period, reportType];
}

class ReportsExportSuccess extends ReportsState {
  final String message;
  const ReportsExportSuccess(this.message);
  @override
  List<Object?> get props => [message];
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

  ReportsBloc({required this.reportsRepository}) : super(ReportsInitial()) {
    on<LoadReportEvent>(_onLoadReport);
    on<ExportReportEvent>(_onExportReport);
  }

  Future<void> _onLoadReport(LoadReportEvent event, Emitter<ReportsState> emit) async {
    emit(ReportsLoading());
    try {
      final report = await reportsRepository.getFinancialReport(period: event.period, type: event.type);
      emit(ReportsLoaded(report: report, period: event.period, reportType: event.type));
    } catch (e) {
      emit(ReportsError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onExportReport(ExportReportEvent event, Emitter<ReportsState> emit) async {
    try {
      if (event.format == 'pdf') {
        final url = await reportsRepository.exportPdf(period: event.period);
        emit(ReportsExportSuccess('PDF отчёт успешно сформирован: $url'));
      } else {
        final url = await reportsRepository.exportExcel(period: event.period);
        emit(ReportsExportSuccess('Excel отчёт успешно сформирован: $url'));
      }
    } catch (e) {
      emit(ReportsError(e.toString().replaceAll('Exception: ', '')));
    }
  }
}
