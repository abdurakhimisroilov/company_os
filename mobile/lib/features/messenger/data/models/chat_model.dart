import '../../../../core/utils/json_helpers.dart';

class MessageModel {
  final String id;
  final String roomId;
  final String senderId;
  final String senderName;
  final String content;
  final String? attachmentUrl;
  final String? attachmentType; // 'image' or 'file'
  final bool isMine;
  final String? replyToContent;
  final DateTime timestamp;

  const MessageModel({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderName,
    required this.content,
    this.attachmentUrl,
    this.attachmentType,
    required this.isMine,
    this.replyToContent,
    required this.timestamp,
  });

  bool get hasAttachment => attachmentUrl != null && attachmentUrl!.isNotEmpty;

  bool get isImage => hasAttachment && attachmentType == 'image';

  /// Name shown for an attachment: the message text carries the original file
  /// name, the stored URL only a generated one.
  String get attachmentName => content.isNotEmpty ? content : (attachmentUrl ?? '').split('/').last;

  static String? _optional(dynamic value) {
    final text = JsonHelpers.toStr(value).trim();
    return text.isEmpty ? null : text;
  }

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: JsonHelpers.toStr(json['id']),
      roomId: JsonHelpers.toStr(json['roomId'] ?? json['room_id']),
      senderId: JsonHelpers.toStr(json['senderId'] ?? json['sender_id']),
      senderName: JsonHelpers.toStr(json['senderName'] ?? json['sender_name']),
      content: JsonHelpers.toStr(json['content']),
      attachmentUrl: _optional(json['attachmentUrl'] ?? json['attachment_url']),
      attachmentType: _optional(json['attachmentType'] ?? json['attachment_type'])?.toLowerCase(),
      isMine: JsonHelpers.toBool(json['isMine'] ?? json['is_mine']),
      replyToContent: _optional(json['replyToContent'] ?? json['reply_to_content']),
      timestamp: JsonHelpers.toDateTime(json['created_at'] ?? json['createdAt']).toLocal(),
    );
  }
}

class ChatRoomModel {
  final String id;
  final String title;
  final bool isGroup;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;

  const ChatRoomModel({
    required this.id,
    required this.title,
    this.isGroup = true,
    required this.lastMessage,
    required this.lastMessageTime,
    this.unreadCount = 0,
  });

  factory ChatRoomModel.fromJson(Map<String, dynamic> json) {
    return ChatRoomModel(
      id: JsonHelpers.toStr(json['id']),
      title: JsonHelpers.toStr(json['title'] ?? json['name']),
      isGroup: JsonHelpers.toBool(json['isGroup'] ?? json['is_group'], true),
      lastMessage: JsonHelpers.toStr(json['lastMessage'] ?? json['last_message']),
      lastMessageTime: JsonHelpers.toDateTime(json['lastMessageTime'] ?? json['last_message_time'] ?? json['created_at']).toLocal(),
      unreadCount: JsonHelpers.toInt(json['unreadCount'] ?? json['unread_count']),
    );
  }
}
