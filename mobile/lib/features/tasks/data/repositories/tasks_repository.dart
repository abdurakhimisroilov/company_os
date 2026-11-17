import 'dart:io';
import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/utils/json_helpers.dart';
import '../models/task_model.dart';

class TasksRepository {
  final ApiClient apiClient;

  TasksRepository({required this.apiClient});

  Future<List<TaskModel>> getTasks({String? filter, int page = 1, int limit = 50}) async {
    final query = <String, dynamic>{'page': page, 'limit': limit};
    if (filter != null && filter.isNotEmpty && filter != 'all') {
      query['filter'] = filter; // 'all', 'my', 'created_by_me'
    }

    final response = await apiClient.get(
      ApiEndpoints.tasks,
      queryParameters: query,
    );

    if (response.statusCode == 200) {
      final list = JsonHelpers.toList(response.data);
      return list.map((e) => TaskModel.fromJson(JsonHelpers.toMap(e))).toList();
    }
    throw Exception('Не удалось загрузить задания');
  }

  Future<TaskModel> getTaskById(String id) async {
    final response = await apiClient.get(ApiEndpoints.task(id));
    if (response.statusCode == 200) {
      final map = JsonHelpers.toMap(
        response.data is Map && (response.data as Map).containsKey('data')
            ? (response.data as Map)['data']
            : response.data,
      );
      return TaskModel.fromJson(map);
    }
    throw Exception('Не удалось загрузить задачу');
  }

  Future<TaskModel> createTask(Map<String, dynamic> data) async {
    final response = await apiClient.post(ApiEndpoints.tasks, data: data);
    if (response.statusCode == 200 || response.statusCode == 201) {
      final map = JsonHelpers.toMap(
        response.data is Map && (response.data as Map).containsKey('data')
            ? (response.data as Map)['data']
            : response.data,
      );
      return TaskModel.fromJson(map);
    }
    throw Exception('Не удалось создать задачу');
  }

  Future<void> updateTaskStatus(String taskId, String status, {double? progress}) async {
    final response = await apiClient.put(
      ApiEndpoints.taskStatus(taskId),
      data: {
        'status': status,
        if (progress != null) 'progress': progress,
      },
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Не удалось обновить статус задачи');
    }
  }

  Future<void> addComment(String taskId, String comment) async {
    final response = await apiClient.post(
      ApiEndpoints.taskComments(taskId),
      data: {'content': comment},
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Не удалось отправить комментарий');
    }
  }

  Future<String> uploadTaskAttachment(String taskId, File file) async {
    final fileName = file.path.split(Platform.pathSeparator).last;
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path, filename: fileName),
      'taskId': taskId,
    });

    final response = await apiClient.post(
      '${ApiEndpoints.tasks}/$taskId/attachments',
      data: formData,
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final map = JsonHelpers.toMap(response.data);
      return JsonHelpers.toStr(map['url'] ?? map['fileUrl'] ?? fileName);
    }
    throw Exception('Ошибка при загрузке файла к задаче');
  }
}
