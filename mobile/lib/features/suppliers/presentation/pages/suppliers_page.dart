import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../bloc/suppliers_bloc.dart';
import '../../data/models/supplier_model.dart';
import '../widgets/supplier_form_sheet.dart';

class SuppliersPage extends StatefulWidget {
  const SuppliersPage({super.key});

  @override
  State<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends State<SuppliersPage> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    context.read<SuppliersBloc>().add(const LoadSuppliersEvent(search: ''));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _reload(search: query);
    });
    setState(() {});
  }

  /// Reloads the list and finishes when the server has answered.
  Future<void> _reload({String? search}) async {
    final completer = Completer<String?>();
    context.read<SuppliersBloc>().add(
          LoadSuppliersEvent(search: search ?? _searchController.text, completer: completer),
        );
    final error = await completer.future;
    if (!mounted || error == null) return;
    if (context.read<SuppliersBloc>().state is SuppliersLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _showAddSupplierDialog() async {
    final created = await showSupplierFormSheet(context);
    if (created == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Поставщик успешно добавлен'), backgroundColor: AppColors.success),
    );
    await _reload();
  }

  Future<void> _openSupplier(SupplierModel s) async {
    await context.push('/suppliers/${s.id}');
    if (mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildHeader(),
              _buildSearchBar(),
              Expanded(
                child: BlocBuilder<SuppliersBloc, SuppliersState>(
                  builder: (context, state) {
                    if (state is SuppliersLoaded) {
                      return _buildList(state.suppliers, state.search);
                    }
                    if (state is SuppliersError) {
                      return _buildErrorState(state.message);
                    }
                    return const LoadingShimmer();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSupplierDialog,
        backgroundColor: AppColors.primaryBlue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Поставщик', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
            onPressed: () => context.pop(),
          ),
          Expanded(
            child: Text(
              'Поставщики',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          onSubmitted: (q) {
            _debounce?.cancel();
            _reload(search: q);
          },
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Поиск поставщика...',
            hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 14),
            prefixIcon: const Icon(Icons.search, color: AppColors.primaryBlue),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    icon: Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                    onPressed: () {
                      _debounce?.cancel();
                      _searchController.clear();
                      setState(() {});
                      _reload(search: '');
                    },
                  ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildList(List<SupplierModel> suppliers, String search) {
    final searching = search.isNotEmpty;
    if (suppliers.isEmpty) {
      return RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 60),
          children: [
            Center(
              child: Column(
                children: [
                  Icon(Icons.inventory_outlined, size: 56, color: AppColors.textTertiary),
                  const SizedBox(height: 12),
                  Text(searching ? 'Ничего не найдено' : 'Данных пока нет', style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary)),
                  const SizedBox(height: 6),
                  Text(
                    searching ? 'Измените запрос и попробуйте снова' : 'Добавьте поставщика товаров и услуг',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  if (!searching)
                  ElevatedButton.icon(
                    onPressed: _showAddSupplierDialog,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Добавить поставщика'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: suppliers.length,
        itemBuilder: (context, index) {
          final s = suppliers[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: GlassCard(
              onTap: () => _openSupplier(s),
              padding: const EdgeInsets.all(16),
              borderRadius: 16,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.iconBgPurple,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.business_outlined, color: AppColors.secondaryLavender),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.name,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        if (s.contactPerson.isNotEmpty || s.phone.isNotEmpty)
                          Text(
                            s.contactPerson.isNotEmpty ? s.contactPerson : s.phone,
                            style: AppTextStyles.caption,
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Закупки', style: AppTextStyles.caption),
                      const SizedBox(height: 2),
                      Text(
                        Formatters.formatUzs(s.totalPurchases),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryBlue),
                      ),
                      if (s.payableBalance > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Долг: ${Formatters.formatUzs(s.payableBalance)}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.error),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(message, style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _reload,
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}
