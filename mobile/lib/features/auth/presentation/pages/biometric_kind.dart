import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

/// Icon matching the unlock method the device really has: a face on Face ID
/// devices, a fingerprint everywhere else.
Future<IconData> biometricIcon() async {
  try {
    final types = await LocalAuthentication().getAvailableBiometrics();
    if (types.contains(BiometricType.face) && !types.contains(BiometricType.fingerprint)) {
      return Icons.face_unlock_outlined;
    }
  } catch (_) {}
  return Icons.fingerprint_rounded;
}
