import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/network/api_error.dart';
import '../../data/models/notification_model.dart';
import '../../data/repositories/notifications_repository.dart';

// ─── Events ─────────────────────────────────────────────────────────────────
abstract class NotificationsEvent extends Equatable {
  const NotificationsEvent();
  @override
  List<Object?> get props => [];
}

class LoadNotificationsEvent extends NotificationsEvent {
  /// Completed when the request has finished, successfully or not
  /// (pull-to-refresh waits on it).
  final Completer<void>? done;
  const LoadNotificationsEvent({this.done});
}

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

  /// A change that the server refused; the list is already back as it was.
  final String? actionError;
  final int _errorSeq;

  const NotificationsLoaded(this.notifications, {this.actionError, int errorSeq = 0}) : _errorSeq = errorSeq;

  int get unreadCount => notifications.where((n) => !n.isRead).length;

  @override
  List<Object?> get props => [notifications, actionError, _errorSeq];
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
  int _errorSeq = 0;

  NotificationsBloc({required this.notificationsRepository}) : super(NotificationsInitial()) {
    on<LoadNotificationsEvent>(_onLoad);
    on<MarkAllNotificationsReadEvent>(_onMarkAllRead);
    on<MarkNotificationReadEvent>(_onMarkRead);
    on<DeleteNotificationEvent>(_onDelete);
  }

  List<AppNotificationModel>? get _current {
    final s = state;
    return s is NotificationsLoaded ? s.notifications : null;
  }

  NotificationsLoaded _failed(List<AppNotificationModel> list, Object error, String fallback) {
    return NotificationsLoaded(list, actionError: apiErrorMessage(error, fallback: fallback), errorSeq: ++_errorSeq);
  }

  Future<void> _onLoad(LoadNotificationsEvent event, Emitter<NotificationsState> emit) async {
    // A list that is already on screen stays there while it is refreshed.
    final shown = _current;
    if (shown == null) emit(NotificationsLoading());
    try {
      final list = await notificationsRepository.getNotifications();
      emit(NotificationsLoaded(list));
    } catch (e) {
      if (shown != null) {
        emit(_failed(_current ?? shown, e, 'Не удалось обновить уведомления'));
      } else {
        emit(NotificationsError(apiErrorMessage(e, fallback: 'Не удалось загрузить уведомления')));
      }
    } finally {
      final done = event.done;
      if (done != null && !done.isCompleted) done.complete();
    }
  }

  Future<void> _onMarkAllRead(MarkAllNotificationsReadEvent event, Emitter<NotificationsState> emit) async {
    final before = _current;
    if (before == null || before.every((n) => n.isRead)) return;
    emit(NotificationsLoaded(before.map((n) => n.copyWith(isRead: true)).toList()));
    try {
      await notificationsRepository.markAllAsRead();
    } catch (e) {
      emit(_failed(before, e, 'Не удалось отметить уведомления прочитанными'));
    }
  }

  Future<void> _onMarkRead(MarkNotificationReadEvent event, Emitter<NotificationsState> emit) async {
    final before = _current;
    if (before == null) return;
    if (!before.any((n) => n.id == event.id && !n.isRead)) return;
    emit(NotificationsLoaded(before.map((n) => n.id == event.id ? n.copyWith(isRead: true) : n).toList()));
    try {
      await notificationsRepository.markAsRead(event.id);
    } catch (e) {
      final now = _current ?? before;
      emit(_failed(
        now.map((n) => n.id == event.id ? n.copyWith(isRead: false) : n).toList(),
        e,
        'Не удалось отметить уведомление прочитанным',
      ));
    }
  }

  Future<void> _onDelete(DeleteNotificationEvent event, Emitter<NotificationsState> emit) async {
    final before = _current;
    if (before == null) return;
    final index = before.indexWhere((n) => n.id == event.id);
    if (index < 0) return;
    final removed = before[index];
    emit(NotificationsLoaded(before.where((n) => n.id != event.id).toList()));
    try {
      await notificationsRepository.deleteNotification(event.id);
    } catch (e) {
      // Put the notification back where it was.
      final now = List<AppNotificationModel>.of(_current ?? const []);
      if (!now.any((n) => n.id == removed.id)) {
        now.insert(index.clamp(0, now.length), removed);
      }
      emit(_failed(now, e, 'Не удалось удалить уведомление'));
    }
  }
}
