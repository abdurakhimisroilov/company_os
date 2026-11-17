import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/models/product_model.dart';
import '../../data/repositories/inventory_repository.dart';

// ─── Events ─────────────────────────────────────────────────────────────────
abstract class InventoryEvent extends Equatable {
  const InventoryEvent();
  @override
  List<Object?> get props => [];
}

class LoadProductsEvent extends InventoryEvent {
  final String? search;
  final String? category;
  const LoadProductsEvent({this.search, this.category});
  @override
  List<Object?> get props => [search, category];
}

class LoadProductDetailEvent extends InventoryEvent {
  final String productId;
  const LoadProductDetailEvent(this.productId);
  @override
  List<Object?> get props => [productId];
}

class CreateProductEvent extends InventoryEvent {
  final Map<String, dynamic> data;
  const CreateProductEvent(this.data);
  @override
  List<Object?> get props => [data];
}

class UpdateProductEvent extends InventoryEvent {
  final String productId;
  final Map<String, dynamic> data;
  const UpdateProductEvent({required this.productId, required this.data});
  @override
  List<Object?> get props => [productId, data];
}

class DeleteProductEvent extends InventoryEvent {
  final String productId;
  const DeleteProductEvent(this.productId);
  @override
  List<Object?> get props => [productId];
}

class AdjustStockEvent extends InventoryEvent {
  final Map<String, dynamic> data;
  const AdjustStockEvent(this.data);
  @override
  List<Object?> get props => [data];
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
  final List<String> categories;
  final String selectedCategory;
  final String searchQuery;

  const InventoryLoaded({
    required this.products,
    required this.categories,
    this.selectedCategory = 'Все',
    this.searchQuery = '',
  });

  @override
  List<Object?> get props => [products, categories, selectedCategory, searchQuery];
}

class ProductDetailLoaded extends InventoryState {
  final ProductModel product;
  final List<StockMovementModel> movements;

  const ProductDetailLoaded({
    required this.product,
    required this.movements,
  });

  @override
  List<Object?> get props => [product, movements];
}

class InventoryActionSuccess extends InventoryState {
  final String message;
  const InventoryActionSuccess(this.message);
  @override
  List<Object?> get props => [message];
}

class InventoryError extends InventoryState {
  final String message;
  const InventoryError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─── BLoC ───────────────────────────────────────────────────────────────────
class InventoryBloc extends Bloc<InventoryEvent, InventoryState> {
  final InventoryRepository inventoryRepository;
  List<String> _cachedCategories = ['Все'];

  InventoryBloc({required this.inventoryRepository}) : super(InventoryInitial()) {
    on<LoadProductsEvent>(_onLoadProducts);
    on<LoadProductDetailEvent>(_onLoadProductDetail);
    on<CreateProductEvent>(_onCreateProduct);
    on<UpdateProductEvent>(_onUpdateProduct);
    on<DeleteProductEvent>(_onDeleteProduct);
    on<AdjustStockEvent>(_onAdjustStock);
  }

  Future<void> _onLoadProducts(LoadProductsEvent event, Emitter<InventoryState> emit) async {
    emit(InventoryLoading());
    try {
      if (_cachedCategories.length <= 1) {
        final cats = await inventoryRepository.getCategories();
        _cachedCategories = ['Все', ...cats.where((c) => c != 'Все')];
      }

      final products = await inventoryRepository.getProducts(
        search: event.search,
        categoryId: event.category == 'Все' ? null : event.category,
      );

      emit(InventoryLoaded(
        products: products,
        categories: _cachedCategories,
        selectedCategory: event.category ?? 'Все',
        searchQuery: event.search ?? '',
      ));
    } catch (e) {
      emit(InventoryError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onLoadProductDetail(LoadProductDetailEvent event, Emitter<InventoryState> emit) async {
    emit(InventoryLoading());
    try {
      final product = await inventoryRepository.getProductById(event.productId);
      final movements = await inventoryRepository.getStockMovements(event.productId);
      emit(ProductDetailLoaded(product: product, movements: movements));
    } catch (e) {
      emit(InventoryError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onCreateProduct(CreateProductEvent event, Emitter<InventoryState> emit) async {
    emit(InventoryLoading());
    try {
      await inventoryRepository.createProduct(event.data);
      emit(const InventoryActionSuccess('Товар успешно добавлен'));
      add(const LoadProductsEvent());
    } catch (e) {
      emit(InventoryError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onUpdateProduct(UpdateProductEvent event, Emitter<InventoryState> emit) async {
    emit(InventoryLoading());
    try {
      await inventoryRepository.updateProduct(event.productId, event.data);
      emit(const InventoryActionSuccess('Товар успешно обновлен'));
      add(LoadProductDetailEvent(event.productId));
    } catch (e) {
      emit(InventoryError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onDeleteProduct(DeleteProductEvent event, Emitter<InventoryState> emit) async {
    emit(InventoryLoading());
    try {
      await inventoryRepository.deleteProduct(event.productId);
      emit(const InventoryActionSuccess('Товар удален'));
      add(const LoadProductsEvent());
    } catch (e) {
      emit(InventoryError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onAdjustStock(AdjustStockEvent event, Emitter<InventoryState> emit) async {
    emit(InventoryLoading());
    try {
      await inventoryRepository.adjustStock(event.data);
      emit(const InventoryActionSuccess('Остаток успешно скорректирован'));
      if (event.data['productId'] != null) {
        add(LoadProductDetailEvent(event.data['productId'].toString()));
      } else {
        add(const LoadProductsEvent());
      }
    } catch (e) {
      emit(InventoryError(e.toString().replaceAll('Exception: ', '')));
    }
  }
}
