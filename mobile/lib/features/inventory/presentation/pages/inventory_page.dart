import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../bloc/inventory_bloc.dart';
import '../../data/models/product_model.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    context.read<InventoryBloc>().add(const LoadProductsEvent());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _load() {
    context.read<InventoryBloc>().add(
          LoadProductsEvent(search: _searchController.text.trim(), categoryId: _selectedCategoryId),
        );
  }

  void _onSearchChanged(String _) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _load();
    });
  }

  void _onSearchSubmitted(String _) {
    _searchDebounce?.cancel();
    _load();
  }

  void _onCategorySelect(String? categoryId) {
    _searchDebounce?.cancel();
    _selectedCategoryId = categoryId;
    _load();
  }

  Future<void> _refresh() async {
    final error = await context.read<InventoryBloc>().refresh();
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.error),
      );
    }
  }

  /// Opens a page that may change products and brings the list up to date afterwards.
  Future<void> _openAndRefresh(String location) async {
    await context.push(location);
    if (!mounted) return;
    context.read<InventoryBloc>().add(const RefreshProductsEvent());
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
                child: BlocConsumer<InventoryBloc, InventoryState>(
                  listener: (context, state) {
                    // The bloc drops a category that no longer exists on the server.
                    if (state is InventoryLoaded && !state.isLoading) {
                      _selectedCategoryId = state.selectedCategoryId;
                    }
                  },
                  builder: (context, state) {
                    if (state is InventoryError) {
                      return _buildErrorState(state.message);
                    }
                    if (state is InventoryLoaded) {
                      return _buildContent(state);
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
        onPressed: () => _openAndRefresh('/inventory/product/add'),
        backgroundColor: AppColors.primaryBlue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Товар', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
              'Склад и товары',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.tune, color: AppColors.primaryBlue),
            tooltip: 'Корректировка остатков',
            onPressed: () => _openAndRefresh('/inventory/adjust'),
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
          onSubmitted: _onSearchSubmitted,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Поиск по названию, артикулу...',
            hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 14),
            prefixIcon: const Icon(Icons.search, color: AppColors.primaryBlue),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                      _onSearchSubmitted('');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(InventoryLoaded state) {
    final isFiltered = state.searchQuery.isNotEmpty || state.selectedCategoryId != null;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Category chips horizontal list
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: state.categories.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = index == 0 ? null : state.categories[index - 1];
                final cat = category?.name ?? 'Все';
                final isSelected = category?.id == state.selectedCategoryId;
                return ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  selectedColor: AppColors.primaryBlue,
                  backgroundColor: AppColors.cardBackground.withOpacity(0.7),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  onSelected: (_) => _onCategorySelect(category?.id),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                );
              },
            ),
          ),
          SizedBox(
            height: 16,
            child: state.isLoading
                ? const Center(child: LinearProgressIndicator(minHeight: 2))
                : null,
          ),

          if (state.products.isEmpty && state.isLoading)
            const SizedBox(height: 120)
          else if (state.products.isEmpty && isFiltered)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.search_off, size: 56, color: AppColors.textTertiary),
                    const SizedBox(height: 12),
                    Text(
                      'Ничего не найдено',
                      style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Измените запрос или выберите другую категорию',
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else if (state.products.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 56, color: AppColors.textTertiary),
                    const SizedBox(height: 12),
                    Text(
                      'Данных пока нет',
                      style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Добавьте первый товар на склад',
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _openAndRefresh('/inventory/product/add'),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Добавить товар'),
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
            )
          else
            ...state.products.map((p) => _buildProductCard(p)),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildProductCard(ProductModel product) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        onTap: () => _openAndRefresh('/inventory/product/${product.id}'),
        padding: const EdgeInsets.all(14),
        borderRadius: 16,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Product image / placeholder
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.iconBgBlue,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: const Icon(Icons.inventory_2_outlined, color: AppColors.primaryBlue),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (product.isLowStock)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.iconBgRed,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Мало',
                            style: TextStyle(
                              color: AppColors.error,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Арт: ${product.sku}  •  ${product.categoryName ?? 'Без категории'}',
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        Formatters.formatUzs(product.sellingPrice),
                        style: const TextStyle(
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Остаток: ${formatQty(product.currentStock)} ${product.unit}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: product.isLowStock ? AppColors.error : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(message, style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _load,
            child: const Text('Повторить'),
          ),
        ],
      ),
    );
  }
}
