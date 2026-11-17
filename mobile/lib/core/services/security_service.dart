import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import '../constants/app_constants.dart';

class PinVerificationResult {
  final bool isSuccess;
  final bool isLockedOut;
  final int lockoutSecondsRemaining;
  final int attemptsRemaining;
  final String? message;

  const PinVerificationResult({
    required this.isSuccess,
    this.isLockedOut = false,
    this.lockoutSecondsRemaining = 0,
    this.attemptsRemaining = 5,
    this.message,
  });
}

class SecurityService {
  final FlutterSecureStorage _storage;
  final LocalAuthentication _localAuth;

  static const int maxAttempts = 5;
  static const int lockoutSeconds = 30;

  SecurityService({
    FlutterSecureStorage? storage,
    LocalAuthentication? localAuth,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _localAuth = localAuth ?? LocalAuthentication();

  // ─── PIN METHODS ────────────────────────────────────────────────────────────

  Future<bool> isPinSet() async {
    final hash = await _storage.read(key: AppConstants.pinHashKey);
    return hash != null && hash.isNotEmpty;
  }

  Future<void> savePin(String pin) async {
    final random = Random.secure();
    final saltBytes = List<int>.generate(16, (_) => random.nextInt(256));
    final salt = base64UrlEncode(saltBytes);

    final hash = _hashPinWithSalt(pin, salt);

    await _storage.write(key: AppConstants.pinSaltKey, value: salt);
    await _storage.write(key: AppConstants.pinHashKey, value: hash);
    await resetLockout();
  }

  Future<PinVerificationResult> verifyPin(String enteredPin) async {
    final lockoutSecondsLeft = await getLockoutSecondsRemaining();
    if (lockoutSecondsLeft > 0) {
      return PinVerificationResult(
        isSuccess: false,
        isLockedOut: true,
        lockoutSecondsRemaining: lockoutSecondsLeft,
        attemptsRemaining: 0,
        message: 'Превышено число попыток. Подождите $lockoutSecondsLeft сек.',
      );
    }

    final storedHash = await _storage.read(key: AppConstants.pinHashKey);
    final storedSalt = await _storage.read(key: AppConstants.pinSaltKey);

    if (storedHash == null || storedSalt == null) {
      return const PinVerificationResult(
        isSuccess: false,
        message: 'PIN-код не установлен',
      );
    }

    final computedHash = _hashPinWithSalt(enteredPin, storedSalt);

    if (computedHash == storedHash) {
      await resetLockout();
      return const PinVerificationResult(
        isSuccess: true,
        attemptsRemaining: maxAttempts,
      );
    } else {
      final currentAttempts = await _getFailedAttempts() + 1;
      await _storage.write(
        key: AppConstants.pinFailedAttemptsKey,
        value: currentAttempts.toString(),
      );

      if (currentAttempts >= maxAttempts) {
        final lockoutUntil =
            DateTime.now().millisecondsSinceEpoch + (lockoutSeconds * 1000);
        await _storage.write(
          key: AppConstants.pinLockoutUntilKey,
          value: lockoutUntil.toString(),
        );
        return const PinVerificationResult(
          isSuccess: false,
          isLockedOut: true,
          lockoutSecondsRemaining: lockoutSeconds,
          attemptsRemaining: 0,
          message: 'Неверный PIN. Приложение заблокировано на $lockoutSeconds сек.',
        );
      } else {
        final remaining = maxAttempts - currentAttempts;
        return PinVerificationResult(
          isSuccess: false,
          attemptsRemaining: remaining,
          message: 'Неверный PIN. Осталось попыток: $remaining',
        );
      }
    }
  }

  Future<int> getLockoutSecondsRemaining() async {
    final lockoutUntilStr =
        await _storage.read(key: AppConstants.pinLockoutUntilKey);
    if (lockoutUntilStr == null) return 0;

    final lockoutUntil = int.tryParse(lockoutUntilStr) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (now >= lockoutUntil) {
      await _storage.delete(key: AppConstants.pinLockoutUntilKey);
      await _storage.delete(key: AppConstants.pinFailedAttemptsKey);
      return 0;
    }

    return ((lockoutUntil - now) / 1000).ceil();
  }

  Future<int> _getFailedAttempts() async {
    final attemptsStr =
        await _storage.read(key: AppConstants.pinFailedAttemptsKey);
    return int.tryParse(attemptsStr ?? '') ?? 0;
  }

  Future<void> resetLockout() async {
    await _storage.delete(key: AppConstants.pinFailedAttemptsKey);
    await _storage.delete(key: AppConstants.pinLockoutUntilKey);
  }

  Future<void> clearPin() async {
    await _storage.delete(key: AppConstants.pinHashKey);
    await _storage.delete(key: AppConstants.pinSaltKey);
    await resetLockout();
  }

  String _hashPinWithSalt(String pin, String salt) {
    final bytes = utf8.encode('$salt:$pin:$salt');
    return sha256.convert(bytes).toString();
  }

  // ─── BIOMETRIC METHODS ──────────────────────────────────────────────────────

  Future<bool> isBiometricsSupported() async {
    try {
      final isSupported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      return isSupported && canCheck;
    } catch (e) {
      debugPrint('Biometrics check error: $e');
      return false;
    }
  }

  Future<bool> isBiometricEnabled() async {
    final enabledStr =
        await _storage.read(key: AppConstants.biometricEnabledKey);
    if (enabledStr != 'true') return false;

    // Double check hardware support
    return await isBiometricsSupported();
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(
      key: AppConstants.biometricEnabledKey,
      value: enabled ? 'true' : 'false',
    );
  }

  Future<bool> authenticateWithBiometrics({
    String reason = 'Войдите в COMPANY OS с помощью биометрии',
  }) async {
    try {
      final supported = await isBiometricsSupported();
      if (!supported) return false;

      return await _localAuth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (e) {
      debugPrint('Biometric auth error: $e');
      return false;
    }
  }

  // ─── RESET ALL ──────────────────────────────────────────────────────────────

  Future<void> clearAllSecurity() async {
    await clearPin();
    await _storage.delete(key: AppConstants.biometricEnabledKey);
  }
}
