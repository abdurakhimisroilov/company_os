import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/services/security_service.dart';
import '../../../../core/services/app_update_service.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/pages/biometric_kind.dart';
import '../../../employees/data/models/employee_model.dart';
import '../../../companies/presentation/widgets/company_selector_sheet.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const String _privacyUrl = 'https://abdurakhimisroilov.github.io/company_os/privacy.html';

  final _securityService = getIt<SecurityService>();
  bool _isBiometricSupported = false;
  bool _isBiometricEnabled = false;
  bool _isBiometricBusy = false;
  IconData _biometricIcon = Icons.fingerprint_rounded;
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    _loadSecuritySettings();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _packageInfo = info);
    }).catchError((_) {});
  }

  Future<void> _loadSecuritySettings() async {
    final supported = await _securityService.isBiometricsSupported();
    final enabled = await _securityService.isBiometricEnabled();
    final icon = supported ? await biometricIcon() : _biometricIcon;
    if (mounted) {
      setState(() {
        _isBiometricSupported = supported;
        _isBiometricEnabled = enabled;
        _biometricIcon = icon;
      });
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), backgroundColor: isError ? AppColors.error : AppColors.success),
      );
  }

  Future<void> _toggleBiometric(bool value) async {
    if (_isBiometricBusy) return;
    _isBiometricBusy = true;
    try {
      if (value) {
        final ok = await _securityService.authenticateWithBiometrics(
          reason: 'Подтвердите биометрию для включения',
        );
        if (!ok) {
          if (mounted) _showSnack('Биометрия не подтверждена. Вход по биометрии не включён', isError: true);
          return;
        }
      }
      await _securityService.setBiometricEnabled(value);
      if (mounted) setState(() => _isBiometricEnabled = value);
    } finally {
      _isBiometricBusy = false;
    }
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Выход из системы'),
        content: const Text('Вы уверены, что хотите выйти из учетной записи?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // The app opens the login screen itself once the session is closed.
              context.read<AuthBloc>().add(LogoutRequested());
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccountDialog() async {
    final deleted = await showDialog<bool>(
      context: context,
      builder: (_) => const _DeleteAccountDialog(),
    );
    if (deleted != true || !mounted) return;
    // The account no longer exists; closing the session clears the PIN and
    // sends the app to the login screen.
    context.read<AuthBloc>().add(LogoutRequested());
  }

  Future<void> _changePasswordDialog() async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ChangePasswordSheet(),
    );
    if (changed == true && mounted) _showSnack('Пароль успешно обновлён');
  }

  Future<void> _editProfile(UserModel user) async {
    final updated = await showModalBottomSheet<UserModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditProfileSheet(user: user),
    );
    if (updated == null || !mounted) return;
    context.read<AuthBloc>().add(UserUpdated(updated));
    _showSnack('Профиль обновлён');
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (ctx) {
        bool copied = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('Политика конфиденциальности'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Opero использует ваши персональные данные, операции и документы только для работы функций бизнес-системы. Мы не передаём и не продаём ваши данные третьим лицам.\n\nУдалить учётную запись вместе с данными можно в любой момент: «Настройки» → «Удалить аккаунт».\n\nПолная версия политики:',
                  ),
                  const SizedBox(height: 8),
                  const SelectableText(
                    _privacyUrl,
                    style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  TextButton.icon(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    onPressed: () async {
                      await Clipboard.setData(const ClipboardData(text: _privacyUrl));
                      if (ctx.mounted) setDialogState(() => copied = true);
                    },
                    icon: Icon(copied ? Icons.check_rounded : Icons.copy_rounded, size: 16),
                    label: Text(copied ? 'Ссылка скопирована' : 'Скопировать ссылку'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Понятно')),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Настройки'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // User profile card
            BlocBuilder<AuthBloc, AuthState>(
              builder: (context, state) {
                // Settings are reachable only while signed in; during sign-out
                // there is no profile to show.
                if (state is! AuthAuthenticated) return const SizedBox.shrink();
                final user = state.user;
                final name = user.fullName;
                final email = user.email;
                final phone = user.phone ?? '';

                final roleInfo = EmployeeRoleInfo.fromId(user.role);

                return GlassCard(
                  padding: const EdgeInsets.all(18),
                  borderRadius: 20,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: roleInfo.bgColor,
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: roleInfo.color),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 2),
                            Text(email, style: AppTextStyles.caption),
                            if (phone.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(phone, style: AppTextStyles.caption),
                            ],
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: roleInfo.bgColor,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: roleInfo.color.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(roleInfo.icon, size: 12, color: roleInfo.color),
                                  const SizedBox(width: 4),
                                  Text(
                                    roleInfo.title,
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: roleInfo.color),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Изменить профиль',
                        icon: const Icon(Icons.edit_outlined, color: AppColors.primaryBlue, size: 20),
                        onPressed: () => _editProfile(user),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // Personnel & Roles
            Text('Компания и персонал', style: AppTextStyles.titleMedium),
            const SizedBox(height: 8),
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              borderRadius: 16,
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.apartment_rounded, color: AppColors.primaryBlue, size: 20),
                    ),
                    title: const Text('Организации и филиалы', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Смена активной организации, создание и изменение', style: TextStyle(fontSize: 12)),
                    trailing: Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textTertiary),
                    onTap: () => CompanySelectorSheet.show(
                      context,
                      // The sheet itself reopens the app on the selected organization.
                      onCompanySelected: (_) {},
                    ),
                  ),
                  const Divider(height: 1, thickness: 0.5),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.people_outline_rounded, color: AppColors.primaryBlue, size: 20),
                    ),
                    title: const Text('Сотрудники и роли', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Состав организации, доступ и роли', style: TextStyle(fontSize: 12)),
                    trailing: Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textTertiary),
                    onTap: () => context.push(AppRoutes.employees),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Interface & Theme
            Text('Интерфейс', style: AppTextStyles.titleMedium),
            const SizedBox(height: 8),
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              borderRadius: 16,
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Тёмная тема', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    secondary: const Icon(Icons.dark_mode_outlined, color: AppColors.primaryBlue),
                    value: ThemeController.instance.isDark,
                    activeColor: AppColors.primaryBlue,
                    onChanged: (v) => ThemeController.instance.setDark(v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Security & App info
            Text('Безопасность и авторизация', style: AppTextStyles.titleMedium),
            const SizedBox(height: 8),
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              borderRadius: 16,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.pin_outlined, color: AppColors.primaryBlue),
                    title: const Text('Изменить PIN-код', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    trailing: Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textTertiary),
                    subtitle: const Text('Потребуется текущий PIN-код'),
                    onTap: () => context.push('${AppRoutes.pinSetup}?mode=change'),
                  ),
                  if (_isBiometricSupported) ...[
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('Вход по биометрии', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: const Text('Face ID или отпечаток пальца'),
                      secondary: Icon(_biometricIcon, color: AppColors.primaryBlue),
                      value: _isBiometricEnabled,
                      activeColor: AppColors.primaryBlue,
                      onChanged: _toggleBiometric,
                    ),
                  ],
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.lock_outline, color: AppColors.primaryBlue),
                    title: const Text('Изменить пароль', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    trailing: Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textTertiary),
                    onTap: _changePasswordDialog,
                  ),
                  // Self-update exists only for the Android build distributed outside a store.
                  if (AppUpdateService.isSupported) ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.system_update_rounded, color: AppColors.primaryBlue),
                      title: const Text('Проверить обновления', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: const Text('Загрузка с корпоративного сервера'),
                      trailing: Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textTertiary),
                      onTap: () async {
                        await getIt<AppUpdateService>().showUpdatePrompt(context, isManualCheck: true);
                      },
                    ),
                  ],
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined, color: AppColors.primaryBlue),
                    title: const Text('Политика конфиденциальности', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Защита данных пользователей'),
                    trailing: Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textTertiary),
                    onTap: _showPrivacyPolicy,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.info_outline, color: AppColors.primaryBlue),
                    title: const Text('О приложении', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(
                      _packageInfo == null
                          ? 'Opero (Enterprise Edition)'
                          : 'Opero (Enterprise Edition) • v${_packageInfo!.version}',
                    ),
                    onTap: () {
                      final info = _packageInfo;
                      showAboutDialog(
                        context: context,
                        applicationName: 'Opero',
                        applicationVersion: info == null ? null : '${info.version} (${info.buildNumber})',
                        applicationLegalese: '© 2026 Все права защищены',
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Logout button
            ElevatedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout, color: Colors.white),
              label: const Text('Выйти из аккаунта', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 12),

            // Delete Account button (Mandatory Apple Guideline 5.1.1(v))
            OutlinedButton.icon(
              onPressed: _deleteAccountDialog,
              icon: const Icon(Icons.delete_forever_rounded, color: AppColors.error, size: 20),
              label: const Text('Удалить аккаунт', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.errorLight, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

Widget _sheetHandle() {
  return Center(
    child: Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: AppColors.neutral300, borderRadius: BorderRadius.circular(2)),
    ),
  );
}

Widget _inlineError(String message) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(color: AppColors.errorLight, borderRadius: BorderRadius.circular(12)),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: AppColors.error, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: const TextStyle(color: AppColors.error, fontSize: 13))),
      ],
    ),
  );
}

InputDecoration _fieldDecoration(String label, {String? helper}) {
  return InputDecoration(
    labelText: label,
    helperText: helper,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  );
}

/// Name and phone of the signed-in user. Pops with the saved profile.
class _EditProfileSheet extends StatefulWidget {
  final UserModel user;
  const _EditProfileSheet({required this.user});

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.user.fullName);
  late final _phoneController = TextEditingController(text: widget.user.phone ?? '');
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final updated = await getIt<AuthRepository>().updateProfile({
        'fullName': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
      });
      if (mounted) Navigator.pop(context, updated);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = apiErrorMessage(e, fallback: 'Не удалось сохранить профиль');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 20,
        top: 20,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sheetHandle(),
            Text('Профиль', style: AppTextStyles.titleMedium),
            const SizedBox(height: 4),
            Text(widget.user.email, style: AppTextStyles.caption),
            const SizedBox(height: 14),
            TextFormField(
              controller: _nameController,
              enabled: !_isSaving,
              textCapitalization: TextCapitalization.words,
              decoration: _fieldDecoration('ФИО'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Укажите имя' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              enabled: !_isSaving,
              keyboardType: TextInputType.phone,
              decoration: _fieldDecoration('Телефон'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _inlineError(_error!),
            ],
            const SizedBox(height: 20),
            AppButton(label: 'Сохранить', isLoading: _isSaving, onPressed: _isSaving ? null : _save),
          ],
        ),
      ),
    );
  }
}

/// Pops with `true` once the server has accepted the new password.
class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await getIt<AuthRepository>().changePassword(
        currentPassword: _currentController.text,
        newPassword: _newController.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = apiErrorMessage(e, fallback: 'Не удалось изменить пароль');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 20,
        top: 20,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sheetHandle(),
              Text('Смена пароля', style: AppTextStyles.titleMedium),
              const SizedBox(height: 14),
              TextFormField(
                controller: _currentController,
                enabled: !_isSaving,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: _fieldDecoration('Текущий пароль'),
                validator: (v) => (v == null || v.isEmpty) ? 'Введите текущий пароль' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _newController,
                enabled: !_isSaving,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: _fieldDecoration('Новый пароль', helper: 'Не менее 6 символов'),
                validator: (v) {
                  if (v == null || v.length < 6) return 'Не менее 6 символов';
                  if (v == _currentController.text) return 'Новый пароль совпадает с текущим';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmController,
                enabled: !_isSaving,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: _fieldDecoration('Повторите новый пароль'),
                validator: (v) => v != _newController.text ? 'Пароли не совпадают' : null,
              ),
              const SizedBox(height: 8),
              Text(
                'После смены пароля другие устройства выйдут из учётной записи.',
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                _inlineError(_error!),
              ],
              const SizedBox(height: 20),
              AppButton(
                label: 'Сохранить новый пароль',
                isLoading: _isSaving,
                onPressed: _isSaving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Asks for the password and deletes the account on the server.
/// Pops with `true` when the account no longer exists.
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _passwordController = TextEditingController();
  bool _isDeleting = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() => _error = 'Введите пароль для подтверждения');
      return;
    }
    setState(() {
      _isDeleting = true;
      _error = null;
    });
    try {
      await getIt<AuthRepository>().deleteAccount(password: password);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDeleting = false;
        _error = apiErrorMessage(e, fallback: 'Не удалось удалить аккаунт');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isDeleting,
      child: AlertDialog(
        title: const Text('Удаление аккаунта', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Будут безвозвратно удалены: ваш аккаунт, организации, в которых вы единственный владелец, и все данные этих организаций — финансы, склад, продажи, сделки, задачи, документы и переписка. В остальных организациях вы потеряете доступ. Восстановить аккаунт и данные будет невозможно.',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _passwordController,
                enabled: !_isDeleting,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: _fieldDecoration('Пароль от аккаунта'),
                onSubmitted: (_) => _delete(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                _inlineError(_error!),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: _isDeleting ? null : () => Navigator.pop(context), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: _isDeleting ? null : _delete,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: _isDeleting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Удалить навсегда'),
          ),
        ],
      ),
    );
  }
}

