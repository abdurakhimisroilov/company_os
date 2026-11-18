import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/services/security_service.dart';

class PinSetupPage extends StatefulWidget {
  final bool isChangeMode;

  const PinSetupPage({
    super.key,
    this.isChangeMode = false,
  });

  @override
  State<PinSetupPage> createState() => _PinSetupPageState();
}

class _PinSetupPageState extends State<PinSetupPage> {
  final _securityService = getIt<SecurityService>();

  String _firstPin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  String? _errorMessage;

  // Changing the PIN starts by proving the current one.
  late bool _isVerifyingCurrent = widget.isChangeMode;
  String _currentPin = '';
  bool _isBusy = false;

  Future<void> _checkCurrentPin() async {
    _isBusy = true;
    final result = await _securityService.verifyPin(_currentPin);
    _isBusy = false;
    if (!mounted) return;
    setState(() {
      _currentPin = '';
      if (result.isSuccess) {
        _isVerifyingCurrent = false;
        _errorMessage = null;
      } else {
        _errorMessage = result.message ?? 'Неверный PIN-код';
      }
    });
  }

  void _onDigitPress(String digit) {
    if (_isBusy) return;
    if (_isVerifyingCurrent) {
      if (_currentPin.length < 4) {
        setState(() {
          _currentPin += digit;
          _errorMessage = null;
        });
        if (_currentPin.length == 4) _checkCurrentPin();
      }
      return;
    }
    if (_isConfirming) {
      if (_confirmPin.length < 4) {
        setState(() {
          _confirmPin += digit;
          _errorMessage = null;
        });
        if (_confirmPin.length == 4) {
          _onPinsComplete();
        }
      }
    } else {
      if (_firstPin.length < 4) {
        setState(() {
          _firstPin += digit;
          _errorMessage = null;
        });
        if (_firstPin.length == 4) {
          // Short pause so the fourth dot is seen before the step changes.
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) setState(() => _isConfirming = true);
          });
        }
      }
    }
  }

  void _onBackspace() {
    if (_isBusy) return;
    setState(() {
      _errorMessage = null;
      if (_isVerifyingCurrent) {
        if (_currentPin.isNotEmpty) {
          _currentPin = _currentPin.substring(0, _currentPin.length - 1);
        }
      } else if (_isConfirming) {
        if (_confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        } else {
          _isConfirming = false;
          _firstPin = '';
        }
      } else {
        if (_firstPin.isNotEmpty) {
          _firstPin = _firstPin.substring(0, _firstPin.length - 1);
        }
      }
    });
  }

  Future<void> _onPinsComplete() async {
    if (_firstPin == _confirmPin) {
      _isBusy = true;
      await _securityService.savePin(_firstPin);
      _isBusy = false;

      if (!mounted) return;

      if (widget.isChangeMode) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PIN-код успешно изменен'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
        return;
      }

      // Check if biometric authentication is available on device
      final canBiometric = await _securityService.isBiometricsSupported();
      if (canBiometric && mounted) {
        final enableBio = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Вход по биометрии'),
            content: const Text(
              'Хотите включить быстрый вход с помощью биометрии (Face ID или отпечаток пальца)?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Позже'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Включить'),
              ),
            ],
          ),
        );

        if (enableBio == true) {
          await _securityService.setBiometricEnabled(true);
        }
      }

      if (mounted) {
        context.go(AppRoutes.dashboard);
      }
    } else {
      setState(() {
        _errorMessage = 'PIN-коды не совпадают. Попробуйте снова';
        _firstPin = '';
        _confirmPin = '';
        _isConfirming = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPin = _isVerifyingCurrent ? _currentPin : (_isConfirming ? _confirmPin : _firstPin);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: widget.isChangeMode
            ? IconButton(
                icon: Icon(Icons.arrow_back_ios_new,
                    color: AppColors.textPrimary, size: 20),
                onPressed: () => context.pop(),
              )
            : null,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 1),
              // App Logo
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withOpacity(0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.lock_outline_rounded,
                    size: 32,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _isVerifyingCurrent
                    ? 'Введите текущий PIN-код'
                    : widget.isChangeMode
                        ? (_isConfirming ? 'Повторите новый PIN-код' : 'Введите новый PIN-код')
                        : (_isConfirming ? 'Повторите PIN-код' : 'Создайте 4-значный PIN-код'),
                style: AppTextStyles.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _isVerifyingCurrent
                    ? 'Подтвердите, что это вы, прежде чем задать новый PIN'
                    : _isConfirming
                        ? 'Введите PIN ещё раз для подтверждения'
                        : 'PIN-код используется для быстрого входа в систему',
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
                  final isFilled = index < currentPin.length;
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

              // Numeric Keypad
              _buildKeypad(),
              const SizedBox(height: 32),
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
      onTap: () => _onDigitPress(digit),
      borderRadius: BorderRadius.circular(36),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: AppColors.cardBackground.withOpacity(0.85),
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
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionKey({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
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
            size: 24,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
