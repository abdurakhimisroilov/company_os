import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/models/chat_model.dart';
import '../../data/repositories/messenger_repository.dart';

// ─── Events ─────────────────────────────────────────────────────────────────
abstract class MessengerEvent extends Equatable {
  const MessengerEvent();
  @override
  List<Object?> get props => [];
}

class LoadChatRoomsEvent extends MessengerEvent {
  final String? search;
  const LoadChatRoomsEvent({this.search});
  @override
  List<Object?> get props => [search];
}

class LoadMessagesEvent extends MessengerEvent {
  final String roomId;
  const LoadMessagesEvent(this.roomId);
  @override
  List<Object?> get props => [roomId];
}

class SendMessageEvent extends MessengerEvent {
  final String roomId;
  final String text;
  final String? replyTo;
  const SendMessageEvent({required this.roomId, required this.text, this.replyTo});
  @override
  List<Object?> get props => [roomId, text, replyTo];
}

// ─── States ─────────────────────────────────────────────────────────────────
abstract class MessengerState extends Equatable {
  const MessengerState();
  @override
  List<Object?> get props => [];
}

class MessengerInitial extends MessengerState {}

class MessengerLoading extends MessengerState {}

class ChatRoomsLoaded extends MessengerState {
  final List<ChatRoomModel> rooms;
  final String search;
  const ChatRoomsLoaded({required this.rooms, this.search = ''});
  @override
  List<Object?> get props => [rooms, search];
}

class MessagesLoaded extends MessengerState {
  final String roomId;
  final List<MessageModel> messages;
  const MessagesLoaded({required this.roomId, required this.messages});
  @override
  List<Object?> get props => [roomId, messages];
}

class MessengerError extends MessengerState {
  final String message;
  const MessengerError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─── BLoC ───────────────────────────────────────────────────────────────────
class MessengerBloc extends Bloc<MessengerEvent, MessengerState> {
  final MessengerRepository messengerRepository;
  List<MessageModel> _currentMessages = [];

  MessengerBloc({required this.messengerRepository}) : super(MessengerInitial()) {
    on<LoadChatRoomsEvent>(_onLoadRooms);
    on<LoadMessagesEvent>(_onLoadMessages);
    on<SendMessageEvent>(_onSendMessage);
  }

  Future<void> _onLoadRooms(LoadChatRoomsEvent event, Emitter<MessengerState> emit) async {
    emit(MessengerLoading());
    try {
      final rooms = await messengerRepository.getChatRooms(search: event.search);
      emit(ChatRoomsLoaded(rooms: rooms, search: event.search ?? ''));
    } catch (e) {
      emit(MessengerError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onLoadMessages(LoadMessagesEvent event, Emitter<MessengerState> emit) async {
    emit(MessengerLoading());
    try {
      final messages = await messengerRepository.getMessages(event.roomId);
      _currentMessages = messages;
      emit(MessagesLoaded(roomId: event.roomId, messages: messages));
      messengerRepository.markAsRead(event.roomId);
    } catch (e) {
      emit(MessengerError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onSendMessage(SendMessageEvent event, Emitter<MessengerState> emit) async {
    try {
      final sent = await messengerRepository.sendMessage(event.roomId, event.text, replyTo: event.replyTo);
      _currentMessages = [..._currentMessages, sent];
      emit(MessagesLoaded(roomId: event.roomId, messages: _currentMessages));
    } catch (e) {
      emit(MessengerError(e.toString().replaceAll('Exception: ', '')));
    }
  }
}
