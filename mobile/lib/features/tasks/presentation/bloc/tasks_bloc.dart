import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/network/api_error.dart';
import '../../data/models/task_model.dart';
import '../../data/repositories/tasks_repository.dart';

// ─── Events ─────────────────────────────────────────────────────────────────
abstract class TasksEvent extends Equatable {
  const TasksEvent();
  @override
  List<Object?> get props => [];
}

class LoadTasksEvent extends TasksEvent {
  /// 'all', 'my' (assigned to the current user) or 'created' (set by the current user).
  final String filter;

  /// Needed for the 'created' filter.
  final String currentUserId;

  /// Keeps an already loaded list on screen while the request runs.
  final bool silent;

  /// Completed when the request settles (used by pull-to-refresh).
  final Completer<void>? completer;

  const LoadTasksEvent({this.filter = 'all', this.currentUserId = '', this.silent = false, this.completer});
  @override
  List<Object?> get props => [filter, currentUserId, silent, completer];
}

/// Repeats the last list request without hiding the list (after create/update/delete).
class RefreshTasksEvent extends TasksEvent {
  const RefreshTasksEvent();
}

// ─── States ─────────────────────────────────────────────────────────────────
abstract class TasksState extends Equatable {
  const TasksState();
  @override
  List<Object?> get props => [];
}

class TasksInitial extends TasksState {}

class TasksLoading extends TasksState {}

class TasksLoaded extends TasksState {
  final List<TaskModel> tasks;
  final String currentFilter;

  /// Set when a background refresh failed; the previous list stays visible.
  final String? refreshError;

  const TasksLoaded({required this.tasks, this.currentFilter = 'all', this.refreshError});
  @override
  List<Object?> get props => [tasks, currentFilter, refreshError];
}

class TasksError extends TasksState {
  final String message;
  const TasksError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─── BLoC (task list only; the task card has its own TaskDetailCubit) ───────
class TasksBloc extends Bloc<TasksEvent, TasksState> {
  final TasksRepository tasksRepository;
  String _filter = 'all';
  String _currentUserId = '';
  int _requestSeq = 0;

  TasksBloc({required this.tasksRepository}) : super(TasksInitial()) {
    on<LoadTasksEvent>(_onLoadTasks);
    on<RefreshTasksEvent>(
      (event, emit) => _onLoadTasks(LoadTasksEvent(filter: _filter, currentUserId: _currentUserId, silent: true), emit),
    );
  }

  Future<void> _onLoadTasks(LoadTasksEvent event, Emitter<TasksState> emit) async {
    _filter = event.filter;
    if (event.currentUserId.isNotEmpty) _currentUserId = event.currentUserId;
    final seq = ++_requestSeq;
    final previous = state;
    final kept = event.silent && previous is TasksLoaded ? previous : null;
    if (kept == null) emit(TasksLoading());
    try {
      final tasks = await tasksRepository.getTasks(
        mine: event.filter == 'my',
        createdByMe: event.filter == 'created',
      );
      if (seq == _requestSeq) emit(TasksLoaded(tasks: tasks, currentFilter: event.filter));
    } catch (e) {
      if (seq == _requestSeq) {
        final message = apiErrorMessage(e, fallback: 'Не удалось загрузить задания');
        if (kept != null) {
          emit(TasksLoaded(tasks: kept.tasks, currentFilter: kept.currentFilter, refreshError: message));
        } else {
          emit(TasksError(message));
        }
      }
    } finally {
      event.completer?.complete();
    }
  }
}
