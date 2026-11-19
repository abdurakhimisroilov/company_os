import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/services/security_service.dart';
import '../bloc/auth_bloc.dart';
import 'biometric_kind.dart';

class PinLockPage extends StatefulWidget {
  const PinLockPage({super.key});

  @override
  State<PinLockPage> createState() => _PinLockPageState();
}

class _PinLockPageState extends State<PinLockPage> {
  final _securityService = getIt<SecurityService>();

  String _pin = '';
  String? _errorMessage;
  bool _isLockedOut = false;
  int _lockoutSecondsLeft = 0;
  Timer? _lockoutTimer;
  bool _isBiometricEnabled = false;
  bool _isCheckingBiometrics = false;
  bool _isVerifying = false;
  IconData _biometricIcon = Icons.fingerprint_rounded;

  // After this many lockouts in a row the PIN is no longer accepted and the
  // user has to sign in with the password again.
  static const int _maxLockoutRounds = 3;
  static const String _lockoutRoundsKey = 'user_pin_lockout_rounds';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _checkInitialState();
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkInitialState() async {
    final lockoutRemaining = await _securityService.getLockoutSecondsRemaining();
    if (!mounted) return;
    if (lockoutRemaining > 0) {
      _startLockoutCountdown(lockoutRemaining);
      return;
    }

    final bioEnabled = await _securityService.isBiometricEnabled();
    final icon = bioEnabled ? await biometricIcon() : _biometricIcon;
    if (!mounted) return;
    setState(() {
      _isBiometricEnabled = bioEnabled;
      _biometricIcon = icon;
    });

    // Auto-prompt biometrics if enabled
    if (bioEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _authenticateBiometric();
      });
    }
  }

  void _startLockoutCountdown(int seconds) {
    setState(() {
      _isLockedOut = true;
      _lockoutSecondsLeft = seconds;
      _errorMessage = 'Слишком много попыток. Подождите $seconds сек.';
    });

    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _lockoutSecondsLeft--;
        if (_lockoutSecondsLeft <= 0) {
          _isLockedOut = false;
          _errorMessage = null;
          timer.cancel();
        } else {
          _errorMessage = 'Слишком много попыток. Подождите $_lockoutSecondsLeft сек.';
        }
      });
    });
  }

  Future<void> _authenticateBiometric() async {
    if (_isCheckingBiometrics || _isLockedOut) return;
    _isCheckingBiometrics = true;

    final success = await _securityService.authenticateWithBiometrics(
      reason: 'Войдите в Opero с помощью биометрии',
    );

    _isCheckingBiometrics = false;

    if (success) {
      await _storage.delete(key: _lockoutRoundsKey);
      if (mounted) context.go(AppRoutes.dashboard);
    }
  }

  void _onDigitPress(String digit) {
    if (_isLockedOut || _isVerifying) return;

    if (_pin.length < 4) {
      setState(() {
        _pin += digit;
        _errorMessage = null;
      });

      if (_pin.length == 4) {
        _verifyPin();
      }
    }
  }

  void _onBackspace() {
    if (_isLockedOut) return;
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
        _errorMessage = null;
      });
    }
  }

  Future<void> _verifyPin() async {
    _isVerifying = true;
    final result = await _securityService.verifyPin(_pin);
    _isVerifying = false;

    if (result.isSuccess) {
      await _storage.delete(key: _lockoutRoundsKey);
      if (mounted) context.go(AppRoutes.dashboard);
      return;
    }
    if (!mounted) return;

    setState(() {
      _pin = '';
      _errorMessage = result.message;
    });

    if (result.isLockedOut) {
      final rounds = (int.tryParse(await _storage.read(key: _lockoutRoundsKey) ?? '') ?? 0) + 1;
      if (rounds >= _maxLockoutRounds) {
        await _storage.delete(key: _lockoutRoundsKey);
        if (!mounted) return;
        setState(() {
          _isLockedOut = true;
          _errorMessage = 'PIN-код введён неверно слишком много раз. Войдите по паролю';
        });
        // Signing out clears the PIN; the app then opens the login screen.
        context.read<AuthBloc>().add(LogoutRequested());
        return;
      }
      await _storage.write(key: _lockoutRoundsKey, value: rounds.toString());
      if (mounted) _startLockoutCountdown(result.lockoutSecondsRemaining);
    }
  }

  void _switchToPasswordLogin() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Войти по паролю'),
        content: const Text(
          'Вы выйдете из учётной записи на этом устройстве. PIN-код будет сброшен, для входа потребуются электронная почта и пароль.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // The app opens the login screen itself once the session is closed.
              context.read<AuthBloc>().add(LogoutRequested());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Перейти ко входу'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 1),
              // Logo
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withOpacity(0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.business_center_rounded,
                    size: 38,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                AppStrings.appName,
                style: AppTextStyles.headlineLarge.copyWith(
                  letterSpacing: 2.0,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _isBiometricEnabled
                    ? 'Войдите с помощью биометрии или PIN-кода'
                    : 'Введите PIN-код для входа',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // 4 PIN Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final isFilled = index < _pin.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isFilled
                          ? AppColors.primaryBlue
                          : AppColors.cardBorder,
                      border: Border.all(
                        color: isFilled
                            ? AppColors.primaryBlue
                            : AppColors.textTertiary.withOpacity(0.4),
                        width: 1.5,
                      ),
                      boxShadow: isFilled
                          ? [
                              BoxShadow(
                                color: AppColors.primaryBlue.withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                  );
                }),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],

              const Spacer(flex: 2),

              // Keypad
              _buildKeypad(),
              const SizedBox(height: 20),

              // Alternative Login Option
              TextButton.icon(
                onPressed: _switchToPasswordLogin,
                icon: const Icon(Icons.lock_open_rounded, size: 16, color: AppColors.primaryBlue),
                label: Text(
                  'Войти другим способом',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildKey('1'),
              _buildKey('2'),
              _buildKey('3'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildKey('4'),
              _buildKey('5'),
              _buildKey('6'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildKey('7'),
              _buildKey('8'),
              _buildKey('9'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Biometric or empty
              if (_isBiometricEnabled)
                _buildActionKey(
                  icon: _biometricIcon,
                  iconColor: AppColors.primaryBlue,
                  onTap: _authenticateBiometric,
                )
              else
                const SizedBox(width: 72, height: 72),
              _buildKey('0'),
              _buildActionKey(
                icon: Icons.backspace_outlined,
                onTap: _onBackspace,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKey(String digit) {
    return InkWell(
      onTap: _isLockedOut ? null : () => _onDigitPress(digit),
      borderRadius: BorderRadius.circular(36),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: _isLockedOut
              ? AppColors.cardBackground.withOpacity(0.4)
              : AppColors.cardBackground.withOpacity(0.85),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            digit,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              color: _isLockedOut ? AppColors.textTertiary : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionKey({
    required IconData icon,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: _isLockedOut ? null : onTap,
      borderRadius: BorderRadius.circular(36),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: AppColors.cardBackground.withOpacity(0.5),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(
            icon,
            size: 26,
            color: _isLockedOut
                ? AppColors.textTertiary
                : (iconColor ?? AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}
