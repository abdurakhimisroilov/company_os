import '../../../../core/utils/json_helpers.dart';

class MessageModel {
  final String id;
  final String roomId;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final String content;
  final String? attachmentUrl;
  final String? attachmentType; // 'image', 'file', 'voice'
  final bool isMine;
  final bool isRead;
  final String? replyToContent;
  final DateTime timestamp;

  const MessageModel({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    required this.content,
    this.attachmentUrl,
    this.attachmentType,
    required this.isMine,
    this.isRead = true,
    this.replyToContent,
    required this.timestamp,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json, {String currentUserId = ''}) {
    final sId = JsonHelpers.toStr(json['senderId'] ?? json['userId'] ?? json['sender_id']);
    return MessageModel(
      id: JsonHelpers.toStr(json['id']),
      roomId: JsonHelpers.toStr(json['roomId'] ?? json['room_id']),
      senderId: sId,
      senderName: JsonHelpers.extractString(
        json['sender'] ?? json['user'],
        preferredKeys: ['fullName', 'name'],
        fallback: JsonHelpers.toStr(json['senderName'], 'Собеседник'),
      ),
      senderAvatar: JsonHelpers.extractOptionalString(
            json['sender'] ?? json['user'],
            preferredKeys: ['photoUrl', 'avatarUrl', 'avatar'],
          ) ??
          JsonHelpers.extractOptionalString(json['senderAvatar']),
      content: JsonHelpers.toStr(json['content'] ?? json['message'] ?? json['text']),
      attachmentUrl: JsonHelpers.extractOptionalString(json['attachmentUrl'] ?? json['attachment_url']),
      attachmentType: JsonHelpers.extractOptionalString(json['attachmentType'] ?? json['attachment_type']),
      isMine: JsonHelpers.toBool(json['isMine']) || (currentUserId.isNotEmpty && sId == currentUserId),
      isRead: JsonHelpers.toBool(json['isRead'] ?? json['is_read'], true),
      replyToContent: JsonHelpers.extractOptionalString(json['replyToContent'] ?? json['reply_to_content']),
      timestamp: JsonHelpers.toDateTime(json['timestamp'] ?? json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'roomId': roomId,
      'content': content,
      'attachmentUrl': attachmentUrl,
      'attachmentType': attachmentType,
      'replyToContent': replyToContent,
    };
  }
}

class ChatRoomModel {
  final String id;
  final String title;
  final String type; // 'direct', 'group', 'department'
  final String? avatar;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final bool isOnline;

  const ChatRoomModel({
    required this.id,
    required this.title,
    this.type = 'direct',
    this.avatar,
    required this.lastMessage,
    required this.lastMessageTime,
    this.unreadCount = 0,
    this.isOnline = false,
  });

  bool get isGroup => type == 'group' || type == 'department';

  factory ChatRoomModel.fromJson(Map<String, dynamic> json) {
    return ChatRoomModel(
      id: JsonHelpers.toStr(json['id']),
      title: JsonHelpers.toStr(json['title'] ?? json['name'], 'Чат'),
      type: JsonHelpers.toStr(json['type'], 'direct').toLowerCase(),
      avatar: JsonHelpers.extractOptionalString(json['avatar'] ?? json['avatarUrl']),
      lastMessage: JsonHelpers.toStr(json['lastMessage'] ?? json['last_message'] ?? json['lastMessageText']),
      lastMessageTime: JsonHelpers.toDateTime(json['lastMessageTime'] ?? json['updated_at'] ?? json['last_message_time']),
      unreadCount: JsonHelpers.toInt(json['unreadCount'] ?? json['unread_count']),
      isOnline: JsonHelpers.toBool(json['isOnline'] ?? json['is_online']),
    );
  }
}
