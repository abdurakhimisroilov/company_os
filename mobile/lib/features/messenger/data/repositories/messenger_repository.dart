import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/utils/json_helpers.dart';
import '../models/chat_model.dart';

class MessengerRepository {
  final ApiClient apiClient;

  MessengerRepository({required this.apiClient});

  /// Server limit for a single uploaded file.
  static const int maxFileBytes = 25 * 1024 * 1024;

  /// Rooms of the current organization (a default «Общий чат» always exists).
  Future<List<ChatRoomModel>> getChatRooms() async {
    final response = await apiClient.get(ApiEndpoints.chatRooms);
    return JsonHelpers.toList(response.data).map((e) => ChatRoomModel.fromJson(JsonHelpers.toMap(e))).toList();
  }

  Future<List<MessageModel>> getMessages(String roomId) async {
    final response = await apiClient.get(ApiEndpoints.chatMessages(roomId));
    return JsonHelpers.toList(response.data).map((e) => MessageModel.fromJson(JsonHelpers.toMap(e))).toList();
  }

  Future<MessageModel> sendMessage(
    String roomId,
    String text, {
    String? replyTo,
    String? attachmentUrl,
    String? attachmentType,
  }) async {
    final response = await apiClient.post(
      ApiEndpoints.chatMessages(roomId),
      data: {
        'content': text,
        if (replyTo != null && replyTo.isNotEmpty) 'replyToContent': replyTo,
        if (attachmentUrl != null) 'attachmentUrl': attachmentUrl,
        if (attachmentType != null) 'attachmentType': attachmentType,
      },
    );
    final body = response.data;
    return MessageModel.fromJson(JsonHelpers.toMap(body is Map && body.containsKey('data') ? body['data'] : body));
  }

  /// Uploads a file for a message and returns its server URL.
  Future<String> uploadAttachment(
    String filePath, {
    String? fileName,
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final body = await apiClient.uploadFile(filePath, customFileName: fileName, onProgress: onProgress, cancelToken: cancelToken);
    final url = JsonHelpers.toStr(body['url']);
    if (url.isEmpty) throw Exception('Сервер не вернул адрес файла');
    return url;
  }

  Future<void> markAsRead(String roomId) async {
    await apiClient.post(ApiEndpoints.chatMarkRead(roomId));
  }

  /// Reports a message; it is hidden for the reporter from then on.
  Future<void> reportMessage(String messageId, String reason) async {
    await apiClient.post(ApiEndpoints.chatReportMessage(messageId), data: {'reason': reason});
  }

  /// Hides all messages of [userId] for the current user.
  Future<void> blockUser(String userId) async {
    await apiClient.post(ApiEndpoints.chatBlocks, data: {'userId': userId});
  }

  Future<void> unblockUser(String userId) async {
    await apiClient.delete(ApiEndpoints.chatBlock(userId));
  }

  /// Users blocked by the current user: (id, name) pairs.
  Future<List<({String id, String name})>> getBlockedUsers() async {
    final response = await apiClient.get(ApiEndpoints.chatBlocks);
    return JsonHelpers.toList(response.data).map((e) {
      final m = JsonHelpers.toMap(e);
      return (id: JsonHelpers.toStr(m['id']), name: JsonHelpers.toStr(m['fullName'] ?? m['full_name']));
    }).toList();
  }
}
