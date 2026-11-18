import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/api_error.dart';
import '../../data/models/chat_model.dart';
import '../../data/repositories/messenger_repository.dart';

class ChatState extends Equatable {
  /// Null until the first successful load.
  final List<MessageModel>? messages;
  final String? error;

  const ChatState({this.messages, this.error});

  @override
  List<Object?> get props => [messages, error];
}

/// Messages of one open room. Kept apart from [MessengerBloc] so opening a
/// chat never replaces the room list.
class ChatCubit extends Cubit<ChatState> {
  final MessengerRepository repository;
  final String roomId;
  bool _fetching = false;
  // Bumped by every send so a history request that started earlier (and may
  // not contain the new message) is not applied over it.
  int _sendVersion = 0;

  ChatCubit({required this.repository, required this.roomId}) : super(const ChatState());

  void _emit(ChatState next) {
    if (!isClosed) emit(next);
  }

  /// First load (and retry after an error).
  Future<void> load() async {
    _emit(const ChatState());
    await _fetch(reportError: true);
  }

  /// Periodic refresh: keeps the history on screen and stays quiet on a
  /// network hiccup; the next tick tries again.
  Future<void> poll() => _fetch(reportError: state.messages == null);

  Future<void> _fetch({required bool reportError}) async {
    if (_fetching) return;
    _fetching = true;
    final version = _sendVersion;
    try {
      final messages = await repository.getMessages(roomId);
      if (version != _sendVersion) return;
      final current = state.messages;
      final hasNewIncoming = current == null || messages.any((m) => !m.isMine && !current.any((c) => c.id == m.id));
      if (current == null || !_sameIds(current, messages)) _emit(ChatState(messages: messages));
      if (hasNewIncoming) markRead();
    } catch (e) {
      if (reportError) _emit(ChatState(error: apiErrorMessage(e, fallback: 'Не удалось загрузить сообщения')));
    } finally {
      _fetching = false;
    }
  }

  bool _sameIds(List<MessageModel> a, List<MessageModel> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  /// Unread counters are informational, so a failure here is not surfaced.
  Future<void> markRead() async {
    try {
      await repository.markAsRead(roomId);
    } catch (_) {}
  }

  /// Throws when the server rejects the message; the caller keeps the draft.
  Future<void> send(String text, {String? replyTo, String? attachmentUrl, String? attachmentType}) async {
    final sent = await repository.sendMessage(
      roomId,
      text,
      replyTo: replyTo,
      attachmentUrl: attachmentUrl,
      attachmentType: attachmentType,
    );
    _sendVersion++;
    final current = state.messages ?? const <MessageModel>[];
    if (!current.any((m) => m.id == sent.id)) _emit(ChatState(messages: [...current, sent]));
  }
}
