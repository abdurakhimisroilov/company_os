import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/glass_card.dart';
import '../bloc/auth_bloc.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _companyController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  void _onRegister() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    context.read<AuthBloc>().add(
          RegisterRequested(
            fullName: _nameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
            phone: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
            companyName: _companyController.text.trim().isNotEmpty ? _companyController.text.trim() : null,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) => ModalRoute.of(context)?.isCurrent ?? true,
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          context.go(AppRoutes.dashboard);
        } else if (state is AuthError) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: AppColors.backgroundGradient,
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    // Logo & App Name
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.primaryBlue.withOpacity(0.25),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.person_add_rounded,
                        size: 32,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      AppStrings.appName,
                      style: AppTextStyles.headlineMedium.copyWith(
                        letterSpacing: 2.0,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Создайте учётную запись',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Register Glass Card
                    GlassCard(
                      padding: const EdgeInsets.all(24),
                      borderRadius: 24,
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Регистрация',
                              style: AppTextStyles.titleLarge,
                            ),
                            const SizedBox(height: 18),
                            AppTextField(
                              controller: _nameController,
                              label: 'ФИО',
                              hint: 'Иван Иванов',
                              prefixIcon: Icons.person_outline,
                              textInputAction: TextInputAction.next,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Введите ваше имя';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            AppTextField(
                              controller: _emailController,
                              label: AppStrings.email,
                              hint: 'example@company.com',
                              prefixIcon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              validator: Validators.email,
                            ),
                            const SizedBox(height: 14),
                            AppTextField(
                              controller: _phoneController,
                              label: 'Номер телефона (необязательно)',
                              hint: '+998 90 123-45-67',
                              prefixIcon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 14),
                            AppTextField(
                              controller: _companyController,
                              label: 'Название организации (необязательно)',
                              hint: 'ООО «Моя компания»',
                              prefixIcon: Icons.apartment_rounded,
                              textCapitalization: TextCapitalization.sentences,
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 14),
                            AppTextField(
                              controller: _passwordController,
                              label: AppStrings.password,
                              hint: 'Минимум 6 символов',
                              prefixIcon: Icons.lock_outline_rounded,
                              obscureText: true,
                              textInputAction: TextInputAction.next,
                              validator: Validators.password,
                            ),
                            const SizedBox(height: 14),
                            AppTextField(
                              controller: _confirmPasswordController,
                              label: 'Подтвердите пароль',
                              hint: 'Повторите пароль',
                              prefixIcon: Icons.lock_reset_rounded,
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Повторите пароль';
                                }
                                if (v != _passwordController.text) {
                                  return AppStrings.passwordsDoNotMatch;
                                }
                                return null;
                              },
                              onSubmitted: (_) => _onRegister(),
                            ),
                            const SizedBox(height: 22),
                            BlocBuilder<AuthBloc, AuthState>(
                              builder: (context, state) {
                                return AppButton(
                                  label: 'Зарегистрироваться',
                                  isLoading: state is AuthLoading,
                                  onPressed: _onRegister,
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Уже есть аккаунт? ',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => context.canPop() ? context.pop() : context.go(AppRoutes.login),
                                  child: Text(
                                    'Войти',
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.primaryBlue,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
