import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/models/notification_model.dart';
import '../../data/repositories/notifications_repository.dart';

// ─── Events ─────────────────────────────────────────────────────────────────
abstract class NotificationsEvent extends Equatable {
  const NotificationsEvent();
  @override
  List<Object?> get props => [];
}

class LoadNotificationsEvent extends NotificationsEvent {}

class MarkAllNotificationsReadEvent extends NotificationsEvent {}

class MarkNotificationReadEvent extends NotificationsEvent {
  final String id;
  const MarkNotificationReadEvent(this.id);
  @override
  List<Object?> get props => [id];
}

class DeleteNotificationEvent extends NotificationsEvent {
  final String id;
  const DeleteNotificationEvent(this.id);
  @override
  List<Object?> get props => [id];
}

// ─── States ─────────────────────────────────────────────────────────────────
abstract class NotificationsState extends Equatable {
  const NotificationsState();
  @override
  List<Object?> get props => [];
}

class NotificationsInitial extends NotificationsState {}

class NotificationsLoading extends NotificationsState {}

class NotificationsLoaded extends NotificationsState {
  final List<AppNotificationModel> notifications;
  const NotificationsLoaded(this.notifications);
  @override
  List<Object?> get props => [notifications];
}

class NotificationsError extends NotificationsState {
  final String message;
  const NotificationsError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─── BLoC ───────────────────────────────────────────────────────────────────
class NotificationsBloc extends Bloc<NotificationsEvent, NotificationsState> {
  final NotificationsRepository notificationsRepository;

  NotificationsBloc({required this.notificationsRepository}) : super(NotificationsInitial()) {
    on<LoadNotificationsEvent>(_onLoad);
    on<MarkAllNotificationsReadEvent>(_onMarkAllRead);
    on<MarkNotificationReadEvent>(_onMarkRead);
    on<DeleteNotificationEvent>(_onDelete);
  }

  Future<void> _onLoad(LoadNotificationsEvent event, Emitter<NotificationsState> emit) async {
    emit(NotificationsLoading());
    try {
      final list = await notificationsRepository.getNotifications();
      emit(NotificationsLoaded(list));
    } catch (e) {
      emit(NotificationsError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onMarkAllRead(MarkAllNotificationsReadEvent event, Emitter<NotificationsState> emit) async {
    try {
      await notificationsRepository.markAllAsRead();
      add(LoadNotificationsEvent());
    } catch (e) {
      emit(NotificationsError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onMarkRead(MarkNotificationReadEvent event, Emitter<NotificationsState> emit) async {
    try {
      await notificationsRepository.markAsRead(event.id);
      add(LoadNotificationsEvent());
    } catch (e) {
      emit(NotificationsError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onDelete(DeleteNotificationEvent event, Emitter<NotificationsState> emit) async {
    try {
      await notificationsRepository.deleteNotification(event.id);
      add(LoadNotificationsEvent());
    } catch (e) {
      emit(NotificationsError(e.toString().replaceAll('Exception: ', '')));
    }
  }
}
