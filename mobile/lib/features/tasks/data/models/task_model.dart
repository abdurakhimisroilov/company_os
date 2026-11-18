import 'dart:convert';
import '../../../../core/utils/json_helpers.dart';

/// Attachments uploaded before the server decoded multipart names as UTF-8 were
/// stored as mojibake. Restores those when (and only when) the text is valid
/// UTF-8 read as Latin-1; correct names pass through untouched.
String _restoreFileName(String name) {
  if (name.runes.every((r) => r < 0x80)) return name;
  try {
    return utf8.decode(latin1.encode(name));
  } catch (_) {
    return name;
  }
}

String formatFileSize(int bytes) {
  if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} КБ';
  return '$bytes Б';
}

class TaskCommentModel {
  final String id;
  final String authorName;
  final String content;
  final DateTime createdAt;

  const TaskCommentModel({
    required this.id,
    required this.authorName,
    required this.content,
    required this.createdAt,
  });

  factory TaskCommentModel.fromJson(Map<String, dynamic> json) {
    return TaskCommentModel(
      id: JsonHelpers.toStr(json['id']),
      authorName: JsonHelpers.toStr(json['authorName'] ?? json['author_name']),
      content: JsonHelpers.toStr(json['content'] ?? json['text'] ?? json['comment']),
      createdAt: JsonHelpers.toDateTime(json['created_at'] ?? json['createdAt']).toLocal(),
    );
  }
}

class TaskAttachmentModel {
  final String id;
  final String name;
  final String url;
  final int sizeBytes;

  const TaskAttachmentModel({required this.id, required this.name, required this.url, this.sizeBytes = 0});

  String get extension => name.contains('.') ? name.split('.').last.toLowerCase() : '';

  factory TaskAttachmentModel.fromJson(Map<String, dynamic> json) {
    final url = JsonHelpers.toStr(json['url']);
    final rawName = JsonHelpers.toStr(json['name'] ?? json['fileName']);
    return TaskAttachmentModel(
      id: JsonHelpers.toStr(json['id']),
      name: rawName.isNotEmpty ? _restoreFileName(rawName) : url.split('/').last,
      url: url,
      sizeBytes: JsonHelpers.toInt(json['size']),
    );
  }
}

/// A company member that a task can be assigned to (`GET /employees`).
class TaskAssignee {
  final String id;
  final String fullName;
  final String position;

  const TaskAssignee({required this.id, required this.fullName, this.position = ''});

  factory TaskAssignee.fromJson(Map<String, dynamic> json) {
    return TaskAssignee(
      id: JsonHelpers.toStr(json['id']),
      fullName: JsonHelpers.toStr(json['fullName'] ?? json['full_name']),
      position: JsonHelpers.toStr(json['position']),
    );
  }
}

class TaskModel {
  final String id;
  final String title;
  final String description;
  final String assignedToId;
  final String assignedToName;
  final String createdById;
  final String createdByName;
  final String priority; // 'low', 'medium', 'high', 'urgent'
  final String status; // 'todo', 'in_progress', 'review', 'done'
  final DateTime? deadline;
  final double progress; // 0.0 - 1.0
  final List<TaskAttachmentModel> attachments;
  final List<TaskCommentModel> comments;

  const TaskModel({
    required this.id,
    required this.title,
    required this.description,
    this.assignedToId = '',
    this.assignedToName = '',
    this.createdById = '',
    this.createdByName = '',
    required this.priority,
    required this.status,
    this.deadline,
    this.progress = 0.0,
    this.attachments = const [],
    this.comments = const [],
  });

  bool get isOverdue => deadline != null && DateTime.now().isAfter(deadline!) && status != 'done';

  int get progressPercent => (progress * 100).round();

  static String priorityLabel(String priority) {
    switch (priority) {
      case 'urgent':
        return 'Срочный';
      case 'high':
        return 'Высокий';
      case 'low':
        return 'Низкий';
      default:
        return 'Средний';
    }
  }

  static String statusLabel(String status) {
    switch (status) {
      case 'in_progress':
        return 'В работе';
      case 'review':
        return 'На проверке';
      case 'done':
        return 'Завершено';
      default:
        return 'К выполнению';
    }
  }

  String get priorityDisplay => priorityLabel(priority);

  String get statusDisplay => statusLabel(status);

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    final comments = JsonHelpers.toList(json['comments'])
        .map((e) => TaskCommentModel.fromJson(JsonHelpers.toMap(e)))
        .toList();
    final attachments = JsonHelpers.toList(json['attachmentFiles'])
        .map((e) => TaskAttachmentModel.fromJson(JsonHelpers.toMap(e)))
        .where((a) => a.url.isNotEmpty)
        .toList();

    // The server stores progress as an integer percentage (0–100).
    final progress = (JsonHelpers.toDouble(json['progress']) / 100).clamp(0.0, 1.0).toDouble();
    final assignedTo = json['assignedTo'] ?? json['assigned_to'];
    final createdBy = json['createdBy'] ?? json['created_by'];

    return TaskModel(
      id: JsonHelpers.toStr(json['id']),
      title: JsonHelpers.toStr(json['title']),
      description: JsonHelpers.toStr(json['description']),
      assignedToId: assignedTo is String ? assignedTo : '',
      assignedToName: JsonHelpers.toStr(json['assignedToName'] ?? json['assigned_to_name']),
      createdById: createdBy is String ? createdBy : '',
      createdByName: JsonHelpers.toStr(json['createdByName'] ?? json['created_by_name']),
      priority: JsonHelpers.toStr(json['priority'], 'medium').toLowerCase(),
      status: JsonHelpers.toStr(json['status'], 'todo').toLowerCase(),
      deadline: JsonHelpers.toOptionalDateTime(json['deadline'] ?? json['due_date'])?.toLocal(),
      progress: progress,
      attachments: attachments,
      comments: comments,
    );
  }
}
