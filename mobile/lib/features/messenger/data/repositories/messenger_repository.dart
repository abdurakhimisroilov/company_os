import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/utils/json_helpers.dart';
import '../models/chat_model.dart';

class MessengerRepository {
  final ApiClient apiClient;

  MessengerRepository({required this.apiClient});

  Future<List<ChatRoomModel>> getChatRooms({String? search}) async {
    final query = <String, dynamic>{};
    if (search != null && search.isNotEmpty) query['search'] = search;

    final response = await apiClient.get(
      ApiEndpoints.chatRooms,
      queryParameters: query,
    );

    if (response.statusCode == 200) {
      final list = JsonHelpers.toList(response.data);
      return list.map((e) => ChatRoomModel.fromJson(JsonHelpers.toMap(e))).toList();
    }
    throw Exception('Не удалось загрузить список чатов');
  }

  Future<List<MessageModel>> getMessages(String roomId) async {
    final response = await apiClient.get(ApiEndpoints.chatMessages(roomId));
    if (response.statusCode == 200) {
      final list = JsonHelpers.toList(response.data);
      return list.map((e) => MessageModel.fromJson(JsonHelpers.toMap(e))).toList();
    }
    throw Exception('Не удалось загрузить сообщения');
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
        'replyToContent': replyTo,
        if (attachmentUrl != null) 'attachmentUrl': attachmentUrl,
        if (attachmentType != null) 'attachmentType': attachmentType,
      },
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final map = JsonHelpers.toMap(
        response.data is Map && (response.data as Map).containsKey('data')
            ? (response.data as Map)['data']
            : response.data,
      );
      return MessageModel.fromJson(map);
    }
    throw Exception('Не удалось отправить сообщение');
  }

  Future<void> markAsRead(String roomId) async {
    try {
      await apiClient.post(ApiEndpoints.chatMarkRead(roomId));
    } catch (_) {}
  }
}
