import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../bloc/customers_bloc.dart';
import '../../data/models/customer_model.dart';
import '../widgets/customer_form_sheet.dart';

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    context.read<CustomersBloc>().add(const LoadCustomersEvent(search: ''));
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
    context.read<CustomersBloc>().add(
          LoadCustomersEvent(search: search ?? _searchController.text, completer: completer),
        );
    final error = await completer.future;
    if (!mounted || error == null) return;
    if (context.read<CustomersBloc>().state is CustomersLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _showAddCustomerDialog() async {
    final created = await showCustomerFormSheet(context);
    if (created == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Клиент успешно добавлен'), backgroundColor: AppColors.success),
    );
    await _reload();
  }

  Future<void> _openCustomer(CustomerModel c) async {
    await context.push('/customers/${c.id}');
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
                child: BlocBuilder<CustomersBloc, CustomersState>(
                  builder: (context, state) {
                    if (state is CustomersLoaded) {
                      return _buildList(state.customers, state.search);
                    }
                    if (state is CustomersError) {
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
        onPressed: _showAddCustomerDialog,
        backgroundColor: AppColors.primaryBlue,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Клиент', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
              'Клиенты',
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
            hintText: 'Поиск по имени, номеру телефона...',
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

  Widget _buildList(List<CustomerModel> customers, String search) {
    final searching = search.isNotEmpty;
    if (customers.isEmpty) {
      return RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 60),
          children: [
            Center(
              child: Column(
                children: [
                  Icon(Icons.people_outline, size: 56, color: AppColors.textTertiary),
                  const SizedBox(height: 12),
                  Text(searching ? 'Ничего не найдено' : 'Данных пока нет', style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary)),
                  const SizedBox(height: 6),
                  Text(
                    searching ? 'Измените запрос и попробуйте снова' : 'Добавьте первого клиента компании',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  if (!searching)
                  ElevatedButton.icon(
                    onPressed: _showAddCustomerDialog,
                    icon: const Icon(Icons.person_add, size: 18),
                    label: const Text('Добавить клиента'),
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
        itemCount: customers.length,
        itemBuilder: (context, index) {
          final c = customers[index];
          final hasDebt = c.debtAmount > 0;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: GlassCard(
              onTap: () => _openCustomer(c),
              padding: const EdgeInsets.all(16),
              borderRadius: 16,
              borderColor: hasDebt ? AppColors.error.withOpacity(0.3) : null,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: hasDebt ? AppColors.iconBgRed : AppColors.iconBgBlue,
                    child: Text(
                      c.name.isNotEmpty ? c.name.characters.first.toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: hasDebt ? AppColors.error : AppColors.primaryBlue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.name,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                        ),
                        if (c.phone.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(c.phone, style: AppTextStyles.caption),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Покупки', style: AppTextStyles.caption),
                      const SizedBox(height: 2),
                      Text(
                        Formatters.formatUzs(c.totalPurchases),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryBlue),
                      ),
                      if (hasDebt) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Долг: ${Formatters.formatUzs(c.debtAmount)}',
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
