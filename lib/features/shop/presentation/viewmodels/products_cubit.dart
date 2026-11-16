import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/storage/app_local_cache.dart';
import '../../data/models/category_model.dart';
import '../../data/models/product_model.dart';
import '../../data/repositories/product_repository_impl.dart';
import '../../domain/repositories/product_repository.dart';
import 'products_state.dart';

class ProductsCubit extends Cubit<ProductsState> {
  static const _productsCacheKey = 'cache_products_catalog_v1';
  static const _categoriesCacheKey = 'cache_product_categories_v1';

  final ProductRepository _repository;

  ProductsCubit({ProductRepository? repository, ProductsState? initialState})
    : _repository = repository ?? ProductRepositoryImpl(),
      super(initialState ?? ProductsState.initial());

  String? _rootCauseForIndex(int index) {
    if (state.categories.isNotEmpty &&
        index >= 0 &&
        index < state.categories.length) {
      final id = state.categories[index].id.toLowerCase();
      if (id == 'all') return null;
      return id;
    }
    return null;
  }

  Future<void> loadProducts({bool refresh = false, int limit = 20}) async {
    final isDefaultCatalog =
        state.selectedCategoryIndex == 0 && state.searchQuery.isEmpty;

    // 1. Instant zero-wait cache emission for default catalog
    if (isDefaultCatalog && !refresh) {
      final cachedProductsRaw = AppLocalCache.instance.getJson(
        _productsCacheKey,
      );
      final cachedCategoriesRaw = AppLocalCache.instance.getJson(
        _categoriesCacheKey,
      );

      List<ProductItem>? cachedProducts;
      List<CategoryItem>? cachedCategories;

      if (cachedProductsRaw is List) {
        try {
          cachedProducts = cachedProductsRaw
              .map(
                (e) =>
                    ProductItem.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        } catch (_) {}
      }

      if (cachedCategoriesRaw is List) {
        try {
          cachedCategories = cachedCategoriesRaw
              .map(
                (e) =>
                    CategoryItem.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        } catch (_) {}
      }

      if (cachedProducts != null && cachedProducts.isNotEmpty) {
        ProductItem.cacheProducts(cachedProducts);
        emit(
          state.copyWith(
            products: cachedProducts,
            categories: cachedCategories != null && cachedCategories.isNotEmpty
                ? cachedCategories
                : state.categories,
            isLoading: false,
          ),
        );
      } else {
        emit(state.copyWith(isLoading: true, errorMessage: null));
      }
    } else {
      emit(state.copyWith(isLoading: true, errorMessage: null));
    }

    // 2. Silent background fetch and refresh
    try {
      final categoriesFuture = _repository.getCategories();
      final productsFuture = _repository.getProducts(
        rootCause: _rootCauseForIndex(state.selectedCategoryIndex),
        query: state.searchQuery,
        limit: limit,
      );

      final (categories, result) = await (
        categoriesFuture,
        productsFuture,
      ).wait;
      ProductItem.cacheProducts(result.items);

      if (isDefaultCatalog && result.items.isNotEmpty) {
        await AppLocalCache.instance.putJson(
          _productsCacheKey,
          result.items.map((e) => e.toJson()).toList(),
        );
        if (categories.isNotEmpty) {
          await AppLocalCache.instance.putJson(
            _categoriesCacheKey,
            categories.map((e) => e.toJson()).toList(),
          );
        }
      }

      emit(
        state.copyWith(
          categories: categories.isNotEmpty ? categories : state.categories,
          products: result.items,
          isLoading: false,
        ),
      );
    } catch (e) {
      if (state.products.isNotEmpty) {
        emit(state.copyWith(isLoading: false));
      } else {
        emit(
          state.copyWith(
            isLoading: false,
            errorMessage:
                'Unable to load products. Please check your connection.',
          ),
        );
      }
    }
  }

  Future<void> selectCategory(int index) async {
    if (index >= 0 && index != state.selectedCategoryIndex) {
      emit(state.copyWith(selectedCategoryIndex: index));
      await loadProducts(refresh: true);
    }
  }

  Future<void> search(String query) async {
    emit(state.copyWith(searchQuery: query));
    await loadProducts(refresh: true);
  }

  Future<void> clearSearch() async {
    emit(state.copyWith(searchQuery: ''));
    await loadProducts(refresh: true);
  }
}
