import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/utils/json_helpers.dart';
import '../models/task_model.dart';

class TasksRepository {
  final ApiClient apiClient;

  TasksRepository({required this.apiClient});

  /// Server limit for a single uploaded file.
  static const int maxFileBytes = 25 * 1024 * 1024;

  TaskModel _taskFrom(Response response) {
    final body = response.data;
    return TaskModel.fromJson(JsonHelpers.toMap(body is Map && body.containsKey('data') ? body['data'] : body));
  }

  /// `GET /tasks` — [mine] keeps only tasks assigned to the current user,
  /// [status] is one of todo / in_progress / review / done.
  Future<List<TaskModel>> getTasks({bool mine = false, bool createdByMe = false, String? status, String? search}) async {
    final query = <String, dynamic>{};
    if (mine) query['mine'] = 'true';
    if (createdByMe) query['createdByMe'] = 'true';
    if (status != null && status.isNotEmpty && status != 'all') query['status'] = status;
    if (search != null && search.trim().isNotEmpty) query['search'] = search.trim();

    final response = await apiClient.get(ApiEndpoints.tasks, queryParameters: query);
    return JsonHelpers.toList(response.data).map((e) => TaskModel.fromJson(JsonHelpers.toMap(e))).toList();
  }

  Future<TaskModel> getTaskById(String id) async {
    return _taskFrom(await apiClient.get(ApiEndpoints.task(id)));
  }

  /// Company members a task can be assigned to.
  Future<List<TaskAssignee>> getAssignees() async {
    final response = await apiClient.get(ApiEndpoints.employees);
    return JsonHelpers.toList(response.data)
        .map((e) => TaskAssignee.fromJson(JsonHelpers.toMap(e)))
        .where((e) => e.id.isNotEmpty)
        .toList();
  }

  Future<TaskModel> createTask(Map<String, dynamic> data) async {
    return _taskFrom(await apiClient.post(ApiEndpoints.tasks, data: data));
  }

  /// `PATCH /tasks/:id` — title, description, priority, deadline, progress, assignedToId.
  Future<TaskModel> updateTask(String id, Map<String, dynamic> data) async {
    return _taskFrom(await apiClient.patch(ApiEndpoints.task(id), data: data));
  }

  Future<void> deleteTask(String id) async {
    await apiClient.delete(ApiEndpoints.task(id));
  }

  /// [progress] is a percentage 0–100.
  Future<TaskModel> updateTaskStatus(String taskId, String status, {int? progress}) async {
    final response = await apiClient.put(
      ApiEndpoints.taskStatus(taskId),
      data: {'status': status, if (progress != null) 'progress': progress},
    );
    return _taskFrom(response);
  }

  Future<void> addComment(String taskId, String comment) async {
    await apiClient.post(ApiEndpoints.taskComments(taskId), data: {'content': comment});
  }

  Future<void> uploadTaskAttachment(
    String taskId,
    String filePath, {
    String? fileName,
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    await apiClient.uploadFile(
      filePath,
      customFileName: fileName,
      path: ApiEndpoints.taskAttachments(taskId),
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
  }

  Future<void> deleteTaskAttachment(String taskId, String attachmentId) async {
    await apiClient.delete(ApiEndpoints.taskAttachments(taskId), queryParameters: {'id': attachmentId});
  }
}
