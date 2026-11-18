import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/network/api_error.dart';
import '../../data/models/employee_model.dart';
import '../../data/repositories/employees_repository.dart';

// ─── Events ─────────────────────────────────────────────────────────────────
abstract class EmployeesEvent extends Equatable {
  const EmployeesEvent();
  @override
  List<Object?> get props => [];
}

/// Loads the list of the current organization. The bloc holds only the list;
/// an employee's profile and the add form talk to the repository themselves
/// and ask for a reload when something changed.
class LoadEmployeesEvent extends EmployeesEvent {
  /// Department id from the server, or null for every department.
  final String? departmentId;

  /// Role id (`MANAGER`, `ACCOUNTANT`…), or null for every role.
  final String? role;
  final String? search;

  /// Completed when the request has finished, successfully or not.
  final Completer<void>? done;

  const LoadEmployeesEvent({this.departmentId, this.role, this.search, this.done});

  @override
  List<Object?> get props => [departmentId, role, search];
}

// ─── States ─────────────────────────────────────────────────────────────────
abstract class EmployeesState extends Equatable {
  const EmployeesState();
  @override
  List<Object?> get props => [];
}

class EmployeesInitial extends EmployeesState {}

class EmployeesLoading extends EmployeesState {}

class EmployeesLoaded extends EmployeesState {
  final List<EmployeeModel> employees;
  final List<DepartmentModel> departments;
  final String? selectedDepartmentId;
  final String? selectedRole;
  final String searchQuery;

  /// A newer list is being fetched; the current one stays on screen.
  final bool isRefreshing;

  /// The last refresh failed; the list shown is the previous one.
  final String? refreshError;
  final int _errorSeq;

  const EmployeesLoaded({
    required this.employees,
    required this.departments,
    this.selectedDepartmentId,
    this.selectedRole,
    this.searchQuery = '',
    this.isRefreshing = false,
    this.refreshError,
    int errorSeq = 0,
  }) : _errorSeq = errorSeq;

  @override
  List<Object?> get props =>
      [employees, departments, selectedDepartmentId, selectedRole, searchQuery, isRefreshing, refreshError, _errorSeq];
}

class EmployeesError extends EmployeesState {
  final String message;
  const EmployeesError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─── BLoC ───────────────────────────────────────────────────────────────────
class EmployeesBloc extends Bloc<EmployeesEvent, EmployeesState> {
  final EmployeesRepository employeesRepository;
  int _requestSeq = 0;
  int _errorSeq = 0;

  EmployeesBloc({required this.employeesRepository}) : super(EmployeesInitial()) {
    on<LoadEmployeesEvent>(_onLoadEmployees);
  }

  Future<void> _onLoadEmployees(LoadEmployeesEvent event, Emitter<EmployeesState> emit) async {
    final request = ++_requestSeq;
    final shown = state;
    final search = event.search?.trim() ?? '';

    if (shown is EmployeesLoaded) {
      emit(EmployeesLoaded(
        employees: shown.employees,
        departments: shown.departments,
        selectedDepartmentId: event.departmentId,
        selectedRole: event.role,
        searchQuery: search,
        isRefreshing: true,
      ));
    } else {
      emit(EmployeesLoading());
    }

    try {
      final results = await Future.wait([
        employeesRepository.getDepartmentList(),
        employeesRepository.getEmployees(departmentId: event.departmentId, role: event.role, search: search),
      ]);
      // A newer request (another filter, another search) owns the screen now.
      if (request != _requestSeq) return;
      emit(EmployeesLoaded(
        employees: results[1] as List<EmployeeModel>,
        departments: results[0] as List<DepartmentModel>,
        selectedDepartmentId: event.departmentId,
        selectedRole: event.role,
        searchQuery: search,
      ));
    } catch (e) {
      if (request != _requestSeq) return;
      final message = apiErrorMessage(e, fallback: 'Не удалось загрузить сотрудников');
      if (shown is EmployeesLoaded) {
        // Keep what was on screen, with the filters it was loaded for.
        emit(EmployeesLoaded(
          employees: shown.employees,
          departments: shown.departments,
          selectedDepartmentId: shown.selectedDepartmentId,
          selectedRole: shown.selectedRole,
          searchQuery: shown.searchQuery,
          refreshError: message,
          errorSeq: ++_errorSeq,
        ));
      } else {
        emit(EmployeesError(message));
      }
    } finally {
      final done = event.done;
      if (done != null && !done.isCompleted) done.complete();
    }
  }
}
