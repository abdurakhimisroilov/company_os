import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/network/api_error.dart';
import '../../data/models/chat_model.dart';
import '../../data/repositories/messenger_repository.dart';

// ─── Events ─────────────────────────────────────────────────────────────────
abstract class MessengerEvent extends Equatable {
  const MessengerEvent();
  @override
  List<Object?> get props => [];
}

class LoadChatRoomsEvent extends MessengerEvent {
  /// Keeps the loaded list on screen while the request runs.
  final bool silent;

  /// Completed when the request settles (used by pull-to-refresh).
  final Completer<void>? completer;

  const LoadChatRoomsEvent({this.silent = false, this.completer});
  @override
  List<Object?> get props => [silent, completer];
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

  /// Set when a background refresh failed; the previous list stays visible.
  final String? refreshError;

  const ChatRoomsLoaded({required this.rooms, this.refreshError});
  @override
  List<Object?> get props => [rooms, refreshError];
}

class MessengerError extends MessengerState {
  final String message;
  const MessengerError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─── BLoC (room list only; an open chat has its own ChatCubit) ──────────────
class MessengerBloc extends Bloc<MessengerEvent, MessengerState> {
  final MessengerRepository messengerRepository;

  MessengerBloc({required this.messengerRepository}) : super(MessengerInitial()) {
    on<LoadChatRoomsEvent>(_onLoadRooms);
  }

  Future<void> _onLoadRooms(LoadChatRoomsEvent event, Emitter<MessengerState> emit) async {
    final previous = state;
    final kept = event.silent && previous is ChatRoomsLoaded ? previous : null;
    if (kept == null) emit(MessengerLoading());
    try {
      emit(ChatRoomsLoaded(rooms: await messengerRepository.getChatRooms()));
    } catch (e) {
      final message = apiErrorMessage(e, fallback: 'Не удалось загрузить список чатов');
      emit(kept != null ? ChatRoomsLoaded(rooms: kept.rooms, refreshError: message) : MessengerError(message));
    } finally {
      event.completer?.complete();
    }
  }
}
