import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/models/employee_model.dart';
import '../../data/repositories/employees_repository.dart';

// ─── Events ─────────────────────────────────────────────────────────────────
abstract class EmployeesEvent extends Equatable {
  const EmployeesEvent();
  @override
  List<Object?> get props => [];
}

class LoadEmployeesEvent extends EmployeesEvent {
  final String? department;
  final String? search;
  const LoadEmployeesEvent({this.department, this.search});
  @override
  List<Object?> get props => [department, search];
}

class LoadEmployeeDetailEvent extends EmployeesEvent {
  final String id;
  const LoadEmployeeDetailEvent(this.id);
  @override
  List<Object?> get props => [id];
}

class CreateEmployeeEvent extends EmployeesEvent {
  final Map<String, dynamic> data;
  const CreateEmployeeEvent(this.data);
  @override
  List<Object?> get props => [data];
}

class UpdateEmployeeRoleEvent extends EmployeesEvent {
  final String employeeId;
  final String role;
  const UpdateEmployeeRoleEvent({required this.employeeId, required this.role});
  @override
  List<Object?> get props => [employeeId, role];
}

class UpdateEmployeeEvent extends EmployeesEvent {
  final String employeeId;
  final Map<String, dynamic> data;
  const UpdateEmployeeEvent({required this.employeeId, required this.data});
  @override
  List<Object?> get props => [employeeId, data];
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
  final List<String> departments;
  final String selectedDepartment;
  final String searchQuery;

  const EmployeesLoaded({
    required this.employees,
    required this.departments,
    this.selectedDepartment = 'Все',
    this.searchQuery = '',
  });

  @override
  List<Object?> get props => [employees, departments, selectedDepartment, searchQuery];
}

class EmployeeDetailLoaded extends EmployeesState {
  final EmployeeModel employee;
  const EmployeeDetailLoaded(this.employee);
  @override
  List<Object?> get props => [employee];
}

class EmployeesActionSuccess extends EmployeesState {
  final String message;
  const EmployeesActionSuccess(this.message);
  @override
  List<Object?> get props => [message];
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
  List<String> _cachedDepts = ['Все'];

  EmployeesBloc({required this.employeesRepository}) : super(EmployeesInitial()) {
    on<LoadEmployeesEvent>(_onLoadEmployees);
    on<LoadEmployeeDetailEvent>(_onLoadDetail);
    on<CreateEmployeeEvent>(_onCreateEmployee);
    on<UpdateEmployeeRoleEvent>(_onUpdateRole);
    on<UpdateEmployeeEvent>(_onUpdateEmployee);
  }

  Future<void> _onLoadEmployees(LoadEmployeesEvent event, Emitter<EmployeesState> emit) async {
    emit(EmployeesLoading());
    try {
      if (_cachedDepts.length <= 1) {
        final depts = await employeesRepository.getDepartments();
        _cachedDepts = ['Все', ...depts.where((d) => d != 'Все')];
      }

      final employees = await employeesRepository.getEmployees(
        departmentId: event.department == 'Все' ? null : event.department,
        search: event.search,
      );

      emit(EmployeesLoaded(
        employees: employees,
        departments: _cachedDepts,
        selectedDepartment: event.department ?? 'Все',
        searchQuery: event.search ?? '',
      ));
    } catch (e) {
      emit(EmployeesError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onLoadDetail(LoadEmployeeDetailEvent event, Emitter<EmployeesState> emit) async {
    emit(EmployeesLoading());
    try {
      final employee = await employeesRepository.getEmployeeById(event.id);
      emit(EmployeeDetailLoaded(employee));
    } catch (e) {
      emit(EmployeesError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onCreateEmployee(CreateEmployeeEvent event, Emitter<EmployeesState> emit) async {
    emit(EmployeesLoading());
    try {
      await employeesRepository.createEmployee(event.data);
      emit(const EmployeesActionSuccess('Сотрудник успешно добавлен'));
      add(const LoadEmployeesEvent());
    } catch (e) {
      emit(EmployeesError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onUpdateRole(UpdateEmployeeRoleEvent event, Emitter<EmployeesState> emit) async {
    emit(EmployeesLoading());
    try {
      final updated = await employeesRepository.updateEmployeeRole(event.employeeId, event.role);
      emit(EmployeeDetailLoaded(updated));
      emit(const EmployeesActionSuccess('Роль успешно назначена'));
    } catch (e) {
      emit(EmployeesError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onUpdateEmployee(UpdateEmployeeEvent event, Emitter<EmployeesState> emit) async {
    emit(EmployeesLoading());
    try {
      final updated = await employeesRepository.updateEmployee(event.employeeId, event.data);
      emit(EmployeeDetailLoaded(updated));
      emit(const EmployeesActionSuccess('Данные сотрудника обновлены'));
    } catch (e) {
      emit(EmployeesError(e.toString().replaceAll('Exception: ', '')));
    }
  }
}
