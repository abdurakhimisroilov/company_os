import 'package:flutter/material.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/glass_card.dart';
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

class _CompanySelectorSheetState extends State<CompanySelectorSheet> {
  final _repository = getIt<CompanyRepository>();
  List<CompanyModel> _companies = [];
  bool _isLoading = true;
  String? _error;
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
      if (mounted) {
        setState(() {
          _companies = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Не удалось загрузить компании: $e';
        });
      }
    }
  }

  Future<void> _switchCompany(CompanyModel company) async {
    setState(() => _switchingId = company.id);

    try {
      final switched = await _repository.switchCompany(company.id);
      if (mounted) {
        Navigator.pop(context);
        widget.onCompanySelected(switched);
        ScaffoldMessenger.of(context).showSnackBar(
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
                    'Активная организация: ${switched.name}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _switchingId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка переключения: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showAddCompanyModal() {
    final nameController = TextEditingController();
    final taxIdController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final descController = TextEditingController();
    String selectedCurrency = 'UZS';
    bool isCreating = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
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
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Icon(Icons.add_business_rounded, color: AppColors.primaryBlue, size: 24),
                      SizedBox(width: 10),
                      Text(
                        'Добавить новую организацию',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Создайте вторую или дочернюю компанию для раздельного учета',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),

                  // Название компании
                  Text('Название организации *', style: AppTextStyles.labelMedium),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                      hintText: 'ООО "АгроЭкспорт", ИП "Ибрагимов"...',
                      filled: true,
                      fillColor: AppColors.background.withOpacity(0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.cardBorder),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ИНН и Валюта
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ИНН / Налог. номер', style: AppTextStyles.labelMedium),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: taxIdController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: '123456789',
                                filled: true,
                                fillColor: AppColors.background.withOpacity(0.3),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppColors.cardBorder),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
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
                                  value: selectedCurrency,
                                  isExpanded: true,
                                  items: ['UZS', 'USD', 'RUB', 'EUR'].map((cur) {
                                    return DropdownMenuItem(value: cur, child: Text(cur));
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setModalState(() => selectedCurrency = val);
                                    }
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
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: '+998 90 123-45-67',
                      filled: true,
                      fillColor: AppColors.background.withOpacity(0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.cardBorder),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Адрес
                  Text('Юридический адрес', style: AppTextStyles.labelMedium),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: addressController,
                    decoration: InputDecoration(
                      hintText: 'г. Ташкент, ул. Амира Темура...',
                      filled: true,
                      fillColor: AppColors.background.withOpacity(0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.cardBorder),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Кнопка создания
                  AppButton(
                    label: 'Создать и войти',
                    isLoading: isCreating,
                    onPressed: () async {
                      final name = nameController.text.trim();
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Введите название компании'), backgroundColor: AppColors.error),
                        );
                        return;
                      }

                      setModalState(() => isCreating = true);

                      try {
                        final created = await _repository.createCompany({
                          'name': name,
                          'taxId': taxIdController.text.trim(),
                          'currency': selectedCurrency,
                          'phone': phoneController.text.trim(),
                          'address': addressController.text.trim(),
                          'description': descController.text.trim(),
                        });

                        if (context.mounted) {
                          Navigator.pop(modalCtx);
                          Navigator.pop(context);
                          widget.onCompanySelected(created);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppColors.success,
                              content: Text('Организация "${created.name}" успешно создана!'),
                            ),
                          );
                        }
                      } catch (err) {
                        if (context.mounted) {
                          setModalState(() => isCreating = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Ошибка создания: $err'), backgroundColor: AppColors.error),
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 30),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
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
                    SizedBox(height: 2),
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
                      Text(_error!, style: const TextStyle(color: AppColors.error)),
                      const SizedBox(height: 8),
                      TextButton(onPressed: _loadCompanies, child: const Text('Повторить')),
                    ],
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
                  itemBuilder: (context, i) {
                    final comp = _companies[i];
                    final isCurrent = comp.isCurrent || (widget.currentCompany?.id == comp.id);
                    final isBusy = _switchingId == comp.id;

                    return InkWell(
                      onTap: isBusy || isCurrent ? null : () => _switchCompany(comp),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isCurrent ? AppColors.primaryBlue.withOpacity(0.08) : Colors.white,
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
                                    : const LinearGradient(
                                        colors: [Color(0xFFE2E8F0), Color(0xFFCBD5E1)],
                                      ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.business_rounded,
                                color: isCurrent ? Colors.white : Colors.grey[700],
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
                                  Row(
                                    children: [
                                      Text(
                                        'Валюта: ${comp.currency}',
                                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                      if (comp.taxId != null && comp.taxId!.isNotEmpty) ...[
                                        const Text(' • ', style: TextStyle(color: AppColors.textTertiary)),
                                        Text(
                                          'ИНН: ${comp.taxId}',
                                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (isBusy)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            else if (isCurrent)
                              const Icon(Icons.check_circle_rounded, color: AppColors.primaryBlue, size: 24)
                            else
                              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textTertiary),
                          ],
                        ),
                      ),
                    );
                  },
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
}
