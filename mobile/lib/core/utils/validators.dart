import '../constants/app_strings.dart';

class Validators {
  Validators._();

  static String? required(String? value, [String? customMessage]) {
    if (value == null || value.trim().isEmpty) {
      return customMessage ?? AppStrings.fieldRequired;
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppStrings.fieldRequired;
    }
    final emailRegex = RegExp(r'^[\w\.-]+@[\w-]+\.\w{2,}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return AppStrings.invalidEmail;
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return AppStrings.fieldRequired;
    }
    if (value.length < 6) {
      return AppStrings.passwordTooShort;
    }
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppStrings.fieldRequired;
    }
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 9) {
      return AppStrings.invalidPhone;
    }
    return null;
  }

  static String? amount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppStrings.fieldRequired;
    }
    final cleaned = value.replaceAll(' ', '').replaceAll(',', '.');
    final parsed = double.tryParse(cleaned);
    if (parsed == null || parsed <= 0) {
      return AppStrings.invalidAmount;
    }
    return null;
  }

  static String? match(String? value, String? compareWith, [String? message]) {
    if (value != compareWith) {
      return message ?? AppStrings.passwordsDoNotMatch;
    }
    return null;
  }
}
