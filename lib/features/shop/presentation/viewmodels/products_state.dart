import '../../data/models/category_model.dart';
import '../../data/models/product_model.dart';

class ProductsState {
  final List<ProductItem> products;
  final Map<String, List<ProductItem>> productsByCatalog;
  final Map<String, bool> hasMoreByCatalog;
  final Map<String, int> pageByCatalog;
  final Map<String, int> totalByCatalog;
  final List<CategoryItem> categories;
  final bool isLoading;
  final bool isLoadingMore;
  final String? errorMessage;
  final int selectedCategoryIndex;
  final String searchQuery;

  const ProductsState({
    this.products = const [],
    this.productsByCatalog = const {},
    this.hasMoreByCatalog = const {},
    this.pageByCatalog = const {},
    this.totalByCatalog = const {},
    this.categories = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.errorMessage,
    this.selectedCategoryIndex = 0,
    this.searchQuery = '',
  });

  factory ProductsState.initial() => ProductsState(
    categories: CategoryItem.defaultProductCategories(),
    isLoading: true,
  );

  String get selectedCategoryId => categoryIdAt(selectedCategoryIndex);

  String categoryIdAt(int index) {
    if (index < 0 || index >= categories.length) return 'all';
    final id = categories[index].id.trim().toLowerCase();
    return id.isEmpty ? 'all' : id;
  }

  String catalogKey(String categoryId, [String? query]) =>
      '${categoryId.trim().toLowerCase()}|${(query ?? searchQuery).trim().toLowerCase()}';

  List<ProductItem> productsFor(String categoryId, [String? query]) =>
      productsByCatalog[catalogKey(categoryId, query)] ??
      (categoryId.trim().toLowerCase() == selectedCategoryId &&
              (query ?? searchQuery).trim() == searchQuery.trim()
          ? products
          : const <ProductItem>[]);

  bool hasMoreFor(String categoryId, [String? query]) =>
      hasMoreByCatalog[catalogKey(categoryId, query)] ?? false;

  int pageFor(String categoryId, [String? query]) =>
      pageByCatalog[catalogKey(categoryId, query)] ?? 0;

  int totalFor(String categoryId, [String? query]) =>
      totalByCatalog[catalogKey(categoryId, query)] ?? 0;

  List<ProductItem> get filteredProducts {
    var list = products;
    final category =
        selectedCategoryIndex >= 0 && selectedCategoryIndex < categories.length
        ? categories[selectedCategoryIndex]
        : null;
    final categoryId = category?.id.toLowerCase() ?? 'all';
    if (categoryId != 'all') {
      final target = _normalize(category?.name ?? categoryId);
      list = list
          .where(
            (product) =>
                _normalize(product.rootCause) == target ||
                _normalize(product.category) == target,
          )
          .toList();
    }

    final query = searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((product) {
        return product.name.toLowerCase().contains(query) ||
            product.subtitle.toLowerCase().contains(query) ||
            product.ingredients.any(
              (ingredient) => ingredient.name.toLowerCase().contains(query),
            );
      }).toList();
    }
    return list;
  }

  String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');

  ProductsState copyWith({
    List<ProductItem>? products,
    Map<String, List<ProductItem>>? productsByCatalog,
    Map<String, bool>? hasMoreByCatalog,
    Map<String, int>? pageByCatalog,
    Map<String, int>? totalByCatalog,
    List<CategoryItem>? categories,
    bool? isLoading,
    bool? isLoadingMore,
    String? errorMessage,
    int? selectedCategoryIndex,
    String? searchQuery,
  }) {
    return ProductsState(
      products: products ?? this.products,
      productsByCatalog: productsByCatalog ?? this.productsByCatalog,
      hasMoreByCatalog: hasMoreByCatalog ?? this.hasMoreByCatalog,
      pageByCatalog: pageByCatalog ?? this.pageByCatalog,
      totalByCatalog: totalByCatalog ?? this.totalByCatalog,
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: errorMessage,
      selectedCategoryIndex:
          selectedCategoryIndex ?? this.selectedCategoryIndex,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}
