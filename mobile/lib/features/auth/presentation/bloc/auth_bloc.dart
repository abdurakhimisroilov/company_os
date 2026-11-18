import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/services/app_session.dart';
import '../../../../core/services/security_service.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';

// ─── Events ─────────────────────────────────────────────────────────────────
abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class CheckAuthStatus extends AuthEvent {}

class LoginRequested extends AuthEvent {
  final String email;
  final String password;
  const LoginRequested({required this.email, required this.password});
  @override
  List<Object?> get props => [email, password];
}

class RegisterRequested extends AuthEvent {
  final String email;
  final String password;
  final String fullName;
  final String? phone;
  final String? companyName;

  const RegisterRequested({
    required this.email,
    required this.password,
    required this.fullName,
    this.phone,
    this.companyName,
  });

  @override
  List<Object?> get props => [email, password, fullName, phone, companyName];
}

class LogoutRequested extends AuthEvent {}

/// The server no longer accepts this session (expired, revoked, account removed).
class SessionExpired extends AuthEvent {}

/// The profile changed on this device (edit profile, role change) or should be re-read.
class UserUpdated extends AuthEvent {
  final UserModel user;
  const UserUpdated(this.user);
  @override
  List<Object?> get props => [user];
}

// ─── States ─────────────────────────────────────────────────────────────────
abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final UserModel user;
  const AuthAuthenticated(this.user);
  @override
  List<Object?> get props => [user];
}

class AuthUnauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─── BLoC ───────────────────────────────────────────────────────────────────
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;

  AuthBloc({required this.authRepository}) : super(AuthInitial()) {
    on<CheckAuthStatus>(_onCheckAuthStatus);
    on<LoginRequested>(_onLoginRequested);
    on<RegisterRequested>(_onRegisterRequested);
    on<LogoutRequested>(_onLogoutRequested);
    on<SessionExpired>(_onSessionExpired);
    on<UserUpdated>((event, emit) => emit(AuthAuthenticated(event.user)));
  }

  Future<void> _onCheckAuthStatus(
    CheckAuthStatus event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    if (!await authRepository.isAuthenticated()) {
      emit(AuthUnauthenticated());
      return;
    }
    try {
      emit(AuthAuthenticated(await authRepository.fetchCurrentUser()));
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 403 || status == 404) {
        await _endSession();
        emit(AuthUnauthenticated());
        return;
      }
      // Offline or server down: keep the saved session and the last known profile.
      final cached = await authRepository.getCachedUser();
      emit(cached != null ? AuthAuthenticated(cached) : AuthUnauthenticated());
    } catch (_) {
      final cached = await authRepository.getCachedUser();
      emit(cached != null ? AuthAuthenticated(cached) : AuthUnauthenticated());
    }
  }

  Future<void> _onLoginRequested(
    LoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final user = await authRepository.login(email: event.email, password: event.password);
      AppSession.instance.restart();
      emit(AuthAuthenticated(user));
    } catch (e) {
      emit(AuthError(apiErrorMessage(e, fallback: 'Не удалось войти. Попробуйте ещё раз')));
    }
  }

  Future<void> _onRegisterRequested(
    RegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final user = await authRepository.register(
        email: event.email,
        password: event.password,
        fullName: event.fullName,
        phone: event.phone,
        companyName: event.companyName,
      );
      AppSession.instance.restart();
      emit(AuthAuthenticated(user));
    } catch (e) {
      emit(AuthError(apiErrorMessage(e, fallback: 'Не удалось зарегистрироваться. Попробуйте ещё раз')));
    }
  }

  // PIN and biometric unlock belong to the account that set them up.
  Future<void> _endSession() async {
    await authRepository.logout();
    try {
      await getIt<SecurityService>().clearAllSecurity();
    } catch (_) {}
  }

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _endSession();
    emit(AuthUnauthenticated());
  }

  Future<void> _onSessionExpired(
    SessionExpired event,
    Emitter<AuthState> emit,
  ) async {
    if (state is AuthUnauthenticated) return;
    await _endSession();
    emit(AuthUnauthenticated());
  }
}
