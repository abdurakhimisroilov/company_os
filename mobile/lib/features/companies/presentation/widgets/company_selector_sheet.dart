import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/app_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../data/models/company_model.dart';
import '../../data/repositories/company_repository.dart';

class CompanySelectorSheet extends StatefulWidget {
  final CompanyModel? currentCompany;
  final ValueChanged<CompanyModel> onCompanySelected;

  const CompanySelectorSheet({
    super.key,
    this.currentCompany,
    required this.onCompanySelected,
  });

  static Future<void> show(
    BuildContext context, {
    CompanyModel? currentCompany,
    required ValueChanged<CompanyModel> onCompanySelected,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CompanySelectorSheet(
        currentCompany: currentCompany,
        onCompanySelected: onCompanySelected,
      ),
    );
  }

  @override
  State<CompanySelectorSheet> createState() => _CompanySelectorSheetState();
}

enum _CompanyAction { edit, delete }

class _CompanySelectorSheetState extends State<CompanySelectorSheet> {
  final _repository = getIt<CompanyRepository>();
  List<CompanyModel> _companies = [];
  bool _isLoading = true;
  String? _error;
  String? _actionError;
  String? _switchingId;

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  Future<void> _loadCompanies() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final list = await _repository.getCompanies();
      if (!mounted) return;
      setState(() {
        _companies = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = apiErrorMessage(e, fallback: 'Не удалось загрузить организации');
      });
    }
  }

  /// Closes the sheet and reopens the app on the dashboard of [company], with
  /// every screen reloaded for it.
  void _enterCompany(CompanyModel company, String message) {
    final router = GoRouter.of(context);
    Navigator.pop(context);
    widget.onCompanySelected(company);
    AppSession.instance.restart();
    router.go(AppRoutes.dashboard);
    // The app is rebuilt for the new organization; report once it is on screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = rootNavigatorKey.currentContext;
      if (ctx == null) return;
      ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
        SnackBar(
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Future<void> _switchCompany(CompanyModel company) async {
    if (_switchingId != null) return;
    setState(() {
      _switchingId = company.id;
      _actionError = null;
    });

    try {
      final switched = await _repository.switchCompany(company.id);
      if (!mounted) return;
      _enterCompany(switched, 'Активная организация: ${switched.name}');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _switchingId = null;
        _actionError = apiErrorMessage(e, fallback: 'Не удалось переключить организацию');
      });
    }
  }

  Future<void> _showAddCompanyModal() async {
    setState(() => _actionError = null);
    final created = await showModalBottomSheet<CompanyModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CompanyFormSheet(repository: _repository),
    );
    if (created == null || !mounted) return;
    // The server makes a new organization the active one.
    _enterCompany(created, 'Организация «${created.name}» создана');
  }

  Future<void> _editCompany(CompanyModel company, bool isCurrent) async {
    setState(() => _actionError = null);
    final updated = await showModalBottomSheet<CompanyModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CompanyFormSheet(repository: _repository, company: company),
    );
    if (updated == null || !mounted) return;
    setState(() {
      _companies = _companies.map((c) => c.id == updated.id ? updated.copyWith(isCurrent: c.isCurrent) : c).toList();
    });
    // The header of the screen underneath shows the active organization's name.
    if (isCurrent) widget.onCompanySelected(updated.copyWith(isCurrent: true));
  }

  Future<void> _deleteCompany(CompanyModel company, bool isCurrent) async {
    setState(() => _actionError = null);
    final result = await showDialog<_DeleteResult>(
      context: context,
      builder: (_) => _DeleteCompanyDialog(repository: _repository, company: company),
    );
    if (result == null || !mounted) return;

    if (!isCurrent) {
      setState(() => _companies = _companies.where((c) => c.id != company.id).toList());
      return;
    }

    // The active organization is gone: the server has moved the user to another one.
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final list = await _repository.getCompanies();
      if (!mounted) return;
      final next = list.where((c) => c.isCurrent || c.id == result.currentCompanyId).toList();
      if (next.isEmpty) {
        setState(() {
          _companies = list;
          _isLoading = false;
        });
        return;
      }
      _enterCompany(next.first, 'Организация удалена. Активная организация: ${next.first.name}');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = apiErrorMessage(e, fallback: 'Не удалось загрузить организации');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 30),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.neutral300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Мои организации',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Выберите рабочую компанию',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: _showAddCompanyModal,
                  icon: const Icon(Icons.add_circle_outline, size: 18, color: AppColors.primaryBlue),
                  label: const Text(
                    'Добавить',
                    style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_actionError != null) ...[
              _ErrorBanner(message: _actionError!),
              const SizedBox(height: 12),
            ],

            // Список компаний
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Column(
                    children: [
                      Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.error)),
                      const SizedBox(height: 8),
                      TextButton(onPressed: _loadCompanies, child: const Text('Повторить')),
                    ],
                  ),
                ),
              )
            else if (_companies.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: Text(
                    'У вас пока нет организаций. Создайте первую, чтобы начать работу',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.45,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _companies.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _buildCompanyTile(_companies[i]),
                ),
              ),
            const SizedBox(height: 16),

            // Кнопка добавления новой компании
            OutlinedButton.icon(
              onPressed: _showAddCompanyModal,
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Добавить другую организацию', style: TextStyle(fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                foregroundColor: AppColors.primaryBlue,
                side: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanyTile(CompanyModel comp) {
    final isCurrent = comp.isCurrent;
    final isBusy = _switchingId == comp.id;
    final description = comp.description?.trim() ?? '';

    return InkWell(
      onTap: _switchingId != null || isCurrent ? null : () => _switchCompany(comp),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.only(left: 14, top: 14, bottom: 14, right: 4),
        decoration: BoxDecoration(
          color: isCurrent ? AppColors.primaryBlue.withOpacity(0.08) : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCurrent ? AppColors.primaryBlue : AppColors.cardBorder,
            width: isCurrent ? 1.8 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: isCurrent
                    ? AppColors.primaryGradient
                    : LinearGradient(
                        colors: AppColors.isDark
                            ? const [Color(0xFF2C3058), Color(0xFF3A3F6B)]
                            : const [Color(0xFFE2E8F0), Color(0xFFCBD5E1)],
                      ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.business_rounded,
                color: isCurrent ? Colors.white : AppColors.neutral700,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          comp.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isCurrent ? AppColors.primaryBlue : AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCurrent) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Активна',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      'Валюта: ${comp.currency}',
                      if (comp.taxId != null && comp.taxId!.isNotEmpty) 'ИНН: ${comp.taxId}',
                    ].join(' • '),
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (isBusy)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else ...[
              if (isCurrent)
                const Icon(Icons.check_circle_rounded, color: AppColors.primaryBlue, size: 24)
              else
                Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textTertiary),
              if (comp.canEdit)
                PopupMenuButton<_CompanyAction>(
                  tooltip: 'Действия',
                  enabled: _switchingId == null,
                  icon: Icon(Icons.more_vert, color: AppColors.textSecondary, size: 20),
                  onSelected: (action) {
                    if (action == _CompanyAction.edit) {
                      _editCompany(comp, isCurrent);
                    } else {
                      _deleteCompany(comp, isCurrent);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: _CompanyAction.edit, child: Text('Изменить')),
                    if (comp.isOwner)
                      const PopupMenuItem(
                        value: _CompanyAction.delete,
                        child: Text('Удалить', style: TextStyle(color: AppColors.error)),
                      ),
                  ],
                )
              else
                const SizedBox(width: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: const TextStyle(color: AppColors.error, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

/// Create (no [company]) or edit form. Pops with the saved organization.
class _CompanyFormSheet extends StatefulWidget {
  final CompanyRepository repository;
  final CompanyModel? company;

  const _CompanyFormSheet({required this.repository, this.company});

  @override
  State<_CompanyFormSheet> createState() => _CompanyFormSheetState();
}

class _CompanyFormSheetState extends State<_CompanyFormSheet> {
  static const _currencies = ['UZS', 'USD', 'RUB', 'EUR'];

  late final _nameController = TextEditingController(text: widget.company?.name ?? '');
  late final _taxIdController = TextEditingController(text: widget.company?.taxId ?? '');
  late final _phoneController = TextEditingController(text: widget.company?.phone ?? '');
  late final _addressController = TextEditingController(text: widget.company?.address ?? '');
  late final _descController = TextEditingController(text: widget.company?.description ?? '');
  String _currency = 'UZS';
  bool _isSaving = false;
  String? _error;

  bool get _isEdit => widget.company != null;

  @override
  void dispose() {
    _nameController.dispose();
    _taxIdController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Введите название организации');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    final taxId = _taxIdController.text.trim();
    try {
      final CompanyModel saved;
      if (_isEdit) {
        saved = await widget.repository.updateCompany(widget.company!.id, {
          'name': name,
          if (taxId.isNotEmpty) 'taxId': taxId,
          'phone': _phoneController.text.trim(),
          'address': _addressController.text.trim(),
          'description': _descController.text.trim(),
        });
      } else {
        saved = await widget.repository.createCompany({
          'name': name,
          if (taxId.isNotEmpty) 'taxId': taxId,
          'currency': _currency,
          'phone': _phoneController.text.trim(),
          'address': _addressController.text.trim(),
          'description': _descController.text.trim(),
        });
      }
      if (!mounted) return;
      Navigator.pop(context, saved);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = apiErrorMessage(
          e,
          fallback: _isEdit ? 'Не удалось сохранить изменения' : 'Не удалось создать организацию',
        );
      });
    }
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: AppColors.background.withOpacity(0.3),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.cardBorder),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    final taxIdField = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ИНН / Налог. номер', style: AppTextStyles.labelMedium),
        const SizedBox(height: 6),
        TextFormField(
          controller: _taxIdController,
          enabled: !_isSaving,
          keyboardType: TextInputType.number,
          decoration: _decoration('123456789'),
        ),
      ],
    );

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 20,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.neutral300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    _isEdit ? Icons.edit_outlined : Icons.add_business_rounded,
                    color: AppColors.primaryBlue,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _isEdit ? 'Изменить организацию' : 'Добавить новую организацию',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _isEdit
                    ? 'Название и реквизиты видят все сотрудники организации'
                    : 'Создайте вторую или дочернюю компанию для раздельного учета',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),

              // Название компании
              Text('Название организации *', style: AppTextStyles.labelMedium),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameController,
                enabled: !_isSaving,
                textCapitalization: TextCapitalization.sentences,
                decoration: _decoration('ООО "АгроЭкспорт", ИП "Ибрагимов"...'),
              ),
              const SizedBox(height: 12),

              // ИНН и Валюта (валюта задаётся при создании)
              if (_isEdit)
                taxIdField
              else
                Row(
                  children: [
                    Expanded(child: taxIdField),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Валюта учета', style: AppTextStyles.labelMedium),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppColors.background.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.cardBorder),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _currency,
                                isExpanded: true,
                                items: _currencies.map((cur) => DropdownMenuItem(value: cur, child: Text(cur))).toList(),
                                onChanged: _isSaving
                                    ? null
                                    : (val) {
                                        if (val != null) setState(() => _currency = val);
                                      },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 12),

              // Телефон
              Text('Контактный телефон', style: AppTextStyles.labelMedium),
              const SizedBox(height: 6),
              TextFormField(
                controller: _phoneController,
                enabled: !_isSaving,
                keyboardType: TextInputType.phone,
                decoration: _decoration('+998 90 123-45-67'),
              ),
              const SizedBox(height: 12),

              // Адрес
              Text('Юридический адрес', style: AppTextStyles.labelMedium),
              const SizedBox(height: 6),
              TextFormField(
                controller: _addressController,
                enabled: !_isSaving,
                decoration: _decoration('г. Ташкент, ул. Амира Темура...'),
              ),
              const SizedBox(height: 12),

              // Описание
              Text('Описание', style: AppTextStyles.labelMedium),
              const SizedBox(height: 6),
              TextFormField(
                controller: _descController,
                enabled: !_isSaving,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: _decoration('Чем занимается организация'),
              ),
              const SizedBox(height: 20),

              if (_error != null) ...[
                _ErrorBanner(message: _error!),
                const SizedBox(height: 12),
              ],

              AppButton(
                label: _isEdit ? 'Сохранить' : 'Создать и войти',
                isLoading: _isSaving,
                onPressed: _isSaving ? null : _save,
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeleteResult {
  final String? currentCompanyId;
  const _DeleteResult(this.currentCompanyId);
}

class _DeleteCompanyDialog extends StatefulWidget {
  final CompanyRepository repository;
  final CompanyModel company;

  const _DeleteCompanyDialog({required this.repository, required this.company});

  @override
  State<_DeleteCompanyDialog> createState() => _DeleteCompanyDialogState();
}

class _DeleteCompanyDialogState extends State<_DeleteCompanyDialog> {
  bool _isDeleting = false;
  String? _error;

  Future<void> _delete() async {
    setState(() {
      _isDeleting = true;
      _error = null;
    });
    try {
      final currentId = await widget.repository.deleteCompany(widget.company.id);
      if (!mounted) return;
      Navigator.pop(context, _DeleteResult(currentId));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDeleting = false;
        _error = apiErrorMessage(e, fallback: 'Не удалось удалить организацию');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isDeleting,
      child: AlertDialog(
        title: const Text(
          'Удалить организацию?',
          style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Организация «${widget.company.name}» и все её данные — финансы, склад, продажи, сделки, задачи, документы и переписка — будут удалены безвозвратно для всех сотрудников. Отменить это действие нельзя.',
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _ErrorBanner(message: _error!),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: _isDeleting ? null : () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
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
