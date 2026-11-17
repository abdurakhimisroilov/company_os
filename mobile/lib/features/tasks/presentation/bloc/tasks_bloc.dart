import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/models/task_model.dart';
import '../../data/repositories/tasks_repository.dart';

// ─── Events ─────────────────────────────────────────────────────────────────
abstract class TasksEvent extends Equatable {
  const TasksEvent();
  @override
  List<Object?> get props => [];
}

class LoadTasksEvent extends TasksEvent {
  final String filter; // 'all', 'my', 'created'
  const LoadTasksEvent({this.filter = 'all'});
  @override
  List<Object?> get props => [filter];
}

class LoadTaskDetailEvent extends TasksEvent {
  final String id;
  const LoadTaskDetailEvent(this.id);
  @override
  List<Object?> get props => [id];
}

class CreateTaskEvent extends TasksEvent {
  final Map<String, dynamic> data;
  const CreateTaskEvent(this.data);
  @override
  List<Object?> get props => [data];
}

class UpdateTaskStatusEvent extends TasksEvent {
  final String taskId;
  final String status;
  const UpdateTaskStatusEvent({required this.taskId, required this.status});
  @override
  List<Object?> get props => [taskId, status];
}

class AddTaskCommentEvent extends TasksEvent {
  final String taskId;
  final String comment;
  const AddTaskCommentEvent({required this.taskId, required this.comment});
  @override
  List<Object?> get props => [taskId, comment];
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
  const TasksLoaded({required this.tasks, this.currentFilter = 'all'});
  @override
  List<Object?> get props => [tasks, currentFilter];
}

class TaskDetailLoaded extends TasksState {
  final TaskModel task;
  const TaskDetailLoaded(this.task);
  @override
  List<Object?> get props => [task];
}

class TasksActionSuccess extends TasksState {
  final String message;
  const TasksActionSuccess(this.message);
  @override
  List<Object?> get props => [message];
}

class TasksError extends TasksState {
  final String message;
  const TasksError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─── BLoC ───────────────────────────────────────────────────────────────────
class TasksBloc extends Bloc<TasksEvent, TasksState> {
  final TasksRepository tasksRepository;

  TasksBloc({required this.tasksRepository}) : super(TasksInitial()) {
    on<LoadTasksEvent>(_onLoadTasks);
    on<LoadTaskDetailEvent>(_onLoadDetail);
    on<CreateTaskEvent>(_onCreateTask);
    on<UpdateTaskStatusEvent>(_onUpdateStatus);
    on<AddTaskCommentEvent>(_onAddComment);
  }

  Future<void> _onLoadTasks(LoadTasksEvent event, Emitter<TasksState> emit) async {
    emit(TasksLoading());
    try {
      final tasks = await tasksRepository.getTasks(filter: event.filter);
      emit(TasksLoaded(tasks: tasks, currentFilter: event.filter));
    } catch (e) {
      emit(TasksError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onLoadDetail(LoadTaskDetailEvent event, Emitter<TasksState> emit) async {
    emit(TasksLoading());
    try {
      final task = await tasksRepository.getTaskById(event.id);
      emit(TaskDetailLoaded(task));
    } catch (e) {
      emit(TasksError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onCreateTask(CreateTaskEvent event, Emitter<TasksState> emit) async {
    emit(TasksLoading());
    try {
      await tasksRepository.createTask(event.data);
      emit(const TasksActionSuccess('Задача успешно создана'));
      add(const LoadTasksEvent());
    } catch (e) {
      emit(TasksError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onUpdateStatus(UpdateTaskStatusEvent event, Emitter<TasksState> emit) async {
    try {
      await tasksRepository.updateTaskStatus(event.taskId, event.status);
      emit(const TasksActionSuccess('Статус задачи изменен'));
      add(LoadTaskDetailEvent(event.taskId));
    } catch (e) {
      emit(TasksError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onAddComment(AddTaskCommentEvent event, Emitter<TasksState> emit) async {
    try {
      await tasksRepository.addComment(event.taskId, event.comment);
      emit(const TasksActionSuccess('Комментарий добавлен'));
      add(LoadTaskDetailEvent(event.taskId));
    } catch (e) {
      emit(TasksError(e.toString().replaceAll('Exception: ', '')));
    }
  }
}
