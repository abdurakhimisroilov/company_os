import '../../../../core/utils/json_helpers.dart';

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
      authorName: JsonHelpers.extractString(
        json['author'] ?? json['user'],
        preferredKeys: ['fullName', 'name'],
        fallback: JsonHelpers.toStr(json['authorName'], 'Сотрудник'),
      ),
      content: JsonHelpers.toStr(json['content'] ?? json['text'] ?? json['comment']),
      createdAt: JsonHelpers.toDateTime(json['createdAt'] ?? json['created_at']),
    );
  }
}

class TaskModel {
  final String id;
  final String title;
  final String description;
  final String assignedToName;
  final String? assignedToAvatar;
  final String createdByName;
  final String priority; // 'high' (Высокий), 'medium' (Средний), 'low' (Низкий)
  final String status; // 'todo' (К выполнению), 'in_progress' (В работе), 'review' (На проверке), 'done' (Завершено)
  final DateTime deadline;
  final double progress; // 0.0 - 1.0
  final List<String> attachments;
  final List<TaskCommentModel> comments;

  const TaskModel({
    required this.id,
    required this.title,
    required this.description,
    required this.assignedToName,
    this.assignedToAvatar,
    required this.createdByName,
    required this.priority,
    required this.status,
    required this.deadline,
    this.progress = 0.0,
    this.attachments = const [],
    this.comments = const [],
  });

  bool get isOverdue => DateTime.now().isAfter(deadline) && status != 'done';

  String get priorityDisplay {
    switch (priority.toLowerCase()) {
      case 'high':
        return 'Высокий';
      case 'medium':
        return 'Средний';
      case 'low':
        return 'Низкий';
      default:
        return 'Средний';
    }
  }

  String get statusDisplay {
    switch (status.toLowerCase()) {
      case 'todo':
        return 'К выполнению';
      case 'in_progress':
        return 'В работе';
      case 'review':
        return 'На проверке';
      case 'done':
        return 'Завершено';
      default:
        return 'В работе';
    }
  }

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    final commentsList = JsonHelpers.toList(json['comments'])
        .map((e) => TaskCommentModel.fromJson(JsonHelpers.toMap(e)))
        .toList();

    final attachList = JsonHelpers.toList(json['attachments'])
        .map((e) => JsonHelpers.extractString(e, preferredKeys: ['url', 'name'], fallback: e.toString()))
        .toList();

    double prog = JsonHelpers.toDouble(json['progress']);
    if (prog > 1.0) prog = prog / 100.0;

    return TaskModel(
      id: JsonHelpers.toStr(json['id']),
      title: JsonHelpers.toStr(json['title'], 'Задача'),
      description: JsonHelpers.toStr(json['description']),
      assignedToName: JsonHelpers.extractString(
        json['assignedTo'] ?? json['assignee'] ?? json['employee'],
        preferredKeys: ['fullName', 'name'],
        fallback: JsonHelpers.toStr(json['assignedToName'], 'Сотрудник'),
      ),
      assignedToAvatar: JsonHelpers.extractOptionalString(
            json['assignedTo'] ?? json['assignee'],
            preferredKeys: ['photoUrl', 'avatarUrl', 'avatar'],
          ) ??
          JsonHelpers.extractOptionalString(json['assignedToAvatar']),
      createdByName: JsonHelpers.extractString(
        json['createdBy'] ?? json['creator'] ?? json['author'],
        preferredKeys: ['fullName', 'name'],
        fallback: JsonHelpers.toStr(json['createdByName'], 'Руководитель'),
      ),
      priority: JsonHelpers.toStr(json['priority'], 'medium').toLowerCase(),
      status: JsonHelpers.toStr(json['status'], 'todo').toLowerCase(),
      deadline: JsonHelpers.toDateTime(
        json['deadline'] ?? json['due_date'],
        DateTime.now().add(const Duration(days: 3)),
      ),
      progress: prog,
      attachments: attachList,
      comments: commentsList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'assignedToName': assignedToName,
      'priority': priority,
      'status': status,
      'deadline': deadline.toIso8601String(),
      'progress': progress,
    };
  }
}
