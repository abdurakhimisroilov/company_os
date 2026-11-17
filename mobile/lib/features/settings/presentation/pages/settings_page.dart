import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/services/security_service.dart';
import '../../../../core/services/app_update_service.dart';
import '../../../../core/router/app_router.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../employees/data/models/employee_model.dart';
import '../../../companies/presentation/widgets/company_selector_sheet.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _securityService = getIt<SecurityService>();
  bool _isDarkMode = false;
  String _selectedLanguage = 'Русский';
  bool _notificationsPush = true;
  bool _notificationsEmail = false;
  bool _isBiometricSupported = false;
  bool _isBiometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSecuritySettings();
  }

  Future<void> _loadSecuritySettings() async {
    final supported = await _securityService.isBiometricsSupported();
    final enabled = await _securityService.isBiometricEnabled();
    if (mounted) {
      setState(() {
        _isBiometricSupported = supported;
        _isBiometricEnabled = enabled;
      });
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
              context.read<AuthBloc>().add(LogoutRequested());
              context.go('/login');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
  }

  void _changePasswordDialog() {
    final oldPassController = TextEditingController();
    final newPassController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          top: 20,
          left: 20,
          right: 20,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Смена пароля', style: AppTextStyles.titleMedium),
            const SizedBox(height: 14),
            TextField(
              controller: oldPassController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Текущий пароль',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPassController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Новый пароль',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Пароль успешно обновлён'), backgroundColor: AppColors.success),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Сохранить новый пароль'),
            ),
          ],
        ),
      ),
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
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // User profile card
            BlocBuilder<AuthBloc, AuthState>(
              builder: (context, state) {
                String name = 'Администратор';
                String email = 'admin@company.uz';
                String role = 'SUPER_ADMIN';

                if (state is AuthAuthenticated) {
                  name = state.user.fullName;
                  email = state.user.email;
                  role = state.user.role;
                }

                final roleInfo = EmployeeRoleInfo.fromId(role);

                return GlassCard(
                  padding: const EdgeInsets.all(18),
                  borderRadius: 20,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: roleInfo.bgColor,
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'A',
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
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 2),
                            Text(email, style: AppTextStyles.caption),
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
                    subtitle: const Text('Смена активной организации или создание новой', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textTertiary),
                    onTap: () => CompanySelectorSheet.show(
                      context,
                      onCompanySelected: (_) {
                        setState(() {});
                      },
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
                    subtitle: const Text('Управление доступом и назначение ролей', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textTertiary),
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
                    value: _isDarkMode,
                    activeColor: AppColors.primaryBlue,
                    onChanged: (v) => setState(() => _isDarkMode = v),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.language, color: AppColors.primaryBlue),
                    title: const Text('Язык приложения', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    trailing: DropdownButton<String>(
                      value: _selectedLanguage,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(value: 'Русский', child: Text('Русский')),
                        DropdownMenuItem(value: 'O\'zbek', child: Text('O\'zbek')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedLanguage = v);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Notifications Settings
            Text('Уведомления', style: AppTextStyles.titleMedium),
            const SizedBox(height: 8),
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              borderRadius: 16,
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Push-уведомления', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    secondary: const Icon(Icons.notifications_active_outlined, color: AppColors.secondaryLavender),
                    value: _notificationsPush,
                    activeColor: AppColors.primaryBlue,
                    onChanged: (v) => setState(() => _notificationsPush = v),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Email-оповещения', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    secondary: const Icon(Icons.mail_outline, color: AppColors.secondaryLavender),
                    value: _notificationsEmail,
                    activeColor: AppColors.primaryBlue,
                    onChanged: (v) => setState(() => _notificationsEmail = v),
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
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textTertiary),
                    onTap: () async {
                      await context.push('${AppRoutes.pinSetup}?mode=change');
                    },
                  ),
                  if (_isBiometricSupported) ...[
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('Вход по отпечатку пальца', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      secondary: const Icon(Icons.fingerprint_rounded, color: AppColors.primaryBlue),
                      value: _isBiometricEnabled,
                      activeColor: AppColors.primaryBlue,
                      onChanged: (val) async {
                        if (val) {
                          final ok = await _securityService.authenticateWithBiometrics(
                            reason: 'Подтвердите биометрию для включения',
                          );
                          if (ok) {
                            await _securityService.setBiometricEnabled(true);
                            setState(() => _isBiometricEnabled = true);
                          }
                        } else {
                          await _securityService.setBiometricEnabled(false);
                          setState(() => _isBiometricEnabled = false);
                        }
                      },
                    ),
                  ],
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.lock_outline, color: AppColors.primaryBlue),
                    title: const Text('Изменить пароль', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textTertiary),
                    onTap: _changePasswordDialog,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.system_update_rounded, color: AppColors.primaryBlue),
                    title: const Text('Проверить обновления', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Загрузка с корпоративного сервера'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textTertiary),
                    onTap: () async {
                      await getIt<AppUpdateService>().showUpdatePrompt(context, isManualCheck: true);
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.info_outline, color: AppColors.primaryBlue),
                    title: const Text('О приложении', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('COMPANY OS (Enterprise Edition)'),
                    onTap: () {
                      showAboutDialog(
                        context: context,
                        applicationName: 'COMPANY OS',
                        applicationVersion: '1.0.1',
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
                backgroundColor: AppColors.error,
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
