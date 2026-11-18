import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/network/api_error.dart';
import '../../data/models/product_model.dart';
import '../../data/repositories/inventory_repository.dart';

// ─── Events ─────────────────────────────────────────────────────────────────
abstract class InventoryEvent extends Equatable {
  const InventoryEvent();
  @override
  List<Object?> get props => [];
}

/// Loads the product list with the given filters.
class LoadProductsEvent extends InventoryEvent {
  final String search;
  final String? categoryId;
  const LoadProductsEvent({this.search = '', this.categoryId});
  @override
  List<Object?> get props => [search, categoryId];
}

/// Reloads the list with the current filters without hiding what is on screen.
class RefreshProductsEvent extends InventoryEvent {
  final Completer<String?>? completer;
  const RefreshProductsEvent({this.completer});
  @override
  List<Object?> get props => [completer];
}

// ─── States ─────────────────────────────────────────────────────────────────
abstract class InventoryState extends Equatable {
  const InventoryState();
  @override
  List<Object?> get props => [];
}

class InventoryInitial extends InventoryState {}

class InventoryLoading extends InventoryState {}

class InventoryLoaded extends InventoryState {
  final List<ProductModel> products;
  final List<ProductCategoryModel> categories;

  /// Null means "all categories".
  final String? selectedCategoryId;
  final String searchQuery;

  /// A request with new filters is in flight; [products] are still the previous result.
  final bool isLoading;

  const InventoryLoaded({
    required this.products,
    required this.categories,
    this.selectedCategoryId,
    this.searchQuery = '',
    this.isLoading = false,
  });

  @override
  List<Object?> get props => [products, categories, selectedCategoryId, searchQuery, isLoading];
}

class InventoryError extends InventoryState {
  final String message;
  const InventoryError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─── BLoC ───────────────────────────────────────────────────────────────────
/// Holds the product LIST only. Product detail, forms and stock adjustment
/// talk to the repository themselves and ask this bloc to refresh afterwards.
class InventoryBloc extends Bloc<InventoryEvent, InventoryState> {
  final InventoryRepository inventoryRepository;

  String _search = '';
  String? _categoryId;
  int _requestSeq = 0;

  InventoryBloc({required this.inventoryRepository}) : super(InventoryInitial()) {
    on<LoadProductsEvent>(_onLoadProducts);
    on<RefreshProductsEvent>(_onRefreshProducts);
  }

  /// Reloads with the current filters; completes with an error text or null.
  Future<String?> refresh() {
    final completer = Completer<String?>();
    add(RefreshProductsEvent(completer: completer));
    return completer.future;
  }

  Future<void> _onLoadProducts(LoadProductsEvent event, Emitter<InventoryState> emit) async {
    _search = event.search.trim();
    _categoryId = event.categoryId;
    final current = state;
    if (current is InventoryLoaded) {
      emit(InventoryLoaded(
        products: current.products,
        categories: current.categories,
        selectedCategoryId: _categoryId,
        searchQuery: _search,
        isLoading: true,
      ));
    } else {
      emit(InventoryLoading());
    }
    await _fetch(emit, silent: false);
  }

  Future<void> _onRefreshProducts(RefreshProductsEvent event, Emitter<InventoryState> emit) async {
    if (state is! InventoryLoaded) emit(InventoryLoading());
    final error = await _fetch(emit, silent: state is InventoryLoaded);
    event.completer?.complete(error);
  }

  Future<String?> _fetch(Emitter<InventoryState> emit, {required bool silent}) async {
    final seq = ++_requestSeq;
    try {
      final productsFuture = inventoryRepository.getProducts(search: _search, categoryId: _categoryId);
      final categoriesFuture = inventoryRepository.getCategories();
      final products = await productsFuture;
      final categories = await categoriesFuture;
      if (seq != _requestSeq) return null;
      // A category removed on the server must not stay selected invisibly.
      if (_categoryId != null && !categories.any((c) => c.id == _categoryId)) _categoryId = null;
      emit(InventoryLoaded(
        products: products,
        categories: categories,
        selectedCategoryId: _categoryId,
        searchQuery: _search,
      ));
      return null;
    } catch (e) {
      final message = apiErrorMessage(e, fallback: 'Не удалось загрузить товары');
      if (seq != _requestSeq) return message;
      final current = state;
      if (silent && current is InventoryLoaded) {
        // Keep the list the user is looking at; the caller reports the failure.
        if (current.isLoading) {
          emit(InventoryLoaded(
            products: current.products,
            categories: current.categories,
            selectedCategoryId: current.selectedCategoryId,
            searchQuery: current.searchQuery,
          ));
        }
        return message;
      }
      emit(InventoryError(message));
      return message;
    }
  }
}
