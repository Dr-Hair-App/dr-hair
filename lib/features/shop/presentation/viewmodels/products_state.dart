import '../../data/models/category_model.dart';
import '../../data/models/product_model.dart';

class ProductsState {
  final List<ProductItem> products;
  final List<CategoryItem> categories;
  final bool isLoading;
  final String? errorMessage;
  final int selectedCategoryIndex;
  final String searchQuery;

  const ProductsState({
    this.products = const [],
    this.categories = const [],
    this.isLoading = false,
    this.errorMessage,
    this.selectedCategoryIndex = 0,
    this.searchQuery = '',
  });

  factory ProductsState.initial() => ProductsState(
    products: const [],
    categories: CategoryItem.defaultProductCategories(),
    isLoading: true,
    selectedCategoryIndex: 0,
    searchQuery: '',
  );

  List<ProductItem> get filteredProducts {
    var list = products;

    final category =
        selectedCategoryIndex >= 0 && selectedCategoryIndex < categories.length
        ? categories[selectedCategoryIndex]
        : null;
    final categoryId = category?.id.toLowerCase() ?? 'all';
    if (categoryId != 'all') {
      final target = _normalize(category?.name ?? categoryId);
      list = list.where((product) {
        return _normalize(product.rootCause) == target ||
            _normalize(product.category) == target;
      }).toList();
    }

    // Filter by search query across name, subtitle, and ingredients
    if (searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      list = list.where((p) {
        final name = p.name.toLowerCase();
        final sub = p.subtitle.toLowerCase();
        final ing = p.ingredients.any((i) => i.name.toLowerCase().contains(q));
        return name.contains(q) || sub.contains(q) || ing;
      }).toList();
    }

    return list;
  }

  String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');

  ProductsState copyWith({
    List<ProductItem>? products,
    List<CategoryItem>? categories,
    bool? isLoading,
    String? errorMessage,
    int? selectedCategoryIndex,
    String? searchQuery,
  }) {
    return ProductsState(
      products: products ?? this.products,
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      selectedCategoryIndex:
          selectedCategoryIndex ?? this.selectedCategoryIndex,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}
