import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/api_error.dart';
import '../../data/models/task_model.dart';
import '../../data/repositories/tasks_repository.dart';

class TaskDetailState extends Equatable {
  final TaskModel? task;
  final bool isLoading;
  final String? error;

  const TaskDetailState({this.task, this.isLoading = false, this.error});

  @override
  List<Object?> get props => [task, isLoading, error];
}

/// State of one open task card. Kept apart from [TasksBloc] so opening a task
/// never replaces the task list. Mutations throw; the page shows the message
/// and keeps what the user typed.
class TaskDetailCubit extends Cubit<TaskDetailState> {
  final TasksRepository repository;
  final String taskId;

  TaskDetailCubit({required this.repository, required this.taskId}) : super(const TaskDetailState(isLoading: true));

  void _emit(TaskDetailState next) {
    if (!isClosed) emit(next);
  }

  Future<void> load() async {
    _emit(TaskDetailState(task: state.task, isLoading: true));
    try {
      _emit(TaskDetailState(task: await repository.getTaskById(taskId)));
    } catch (e) {
      _emit(TaskDetailState(error: apiErrorMessage(e, fallback: 'Не удалось загрузить задачу')));
    }
  }

  /// Re-reads the task after a change without hiding the card.
  Future<void> reload() async {
    _emit(TaskDetailState(task: await repository.getTaskById(taskId)));
  }

  void setTask(TaskModel task) => _emit(TaskDetailState(task: task));

  Future<void> changeStatus(String status, {int? progress}) async {
    _emit(TaskDetailState(task: await repository.updateTaskStatus(taskId, status, progress: progress)));
  }

  Future<void> addComment(String text) async {
    await repository.addComment(taskId, text);
    await reload();
  }

  Future<void> uploadAttachment(
    String filePath, {
    String? fileName,
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) {
    return repository.uploadTaskAttachment(taskId, filePath, fileName: fileName, onProgress: onProgress, cancelToken: cancelToken);
  }

  Future<void> deleteAttachment(String attachmentId) async {
    await repository.deleteTaskAttachment(taskId, attachmentId);
    await reload();
  }

  Future<void> deleteTask() => repository.deleteTask(taskId);
}
