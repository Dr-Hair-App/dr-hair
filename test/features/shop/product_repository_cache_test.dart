import 'package:dio/dio.dart';
import 'package:dr_hair/features/shop/data/datasources/product_remote_data_source.dart';
import 'package:dr_hair/features/shop/data/models/category_model.dart';
import 'package:dr_hair/features/shop/data/models/product_model.dart';
import 'package:dr_hair/features/shop/data/repositories/product_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

ProductItem _createProduct(String id, String category) {
  return ProductItem(
    id: id,
    name: 'Product $id',
    subtitle: 'Herbal cleanser',
    category: category,
    rootCause: 'hair',
    rating: 5,
    reviewsCount: 10,
    inStock: true,
    images: const [],
    supplyPlans: const [],
    benefits: const [],
    ingredients: const [],
    usageSteps: const [],
    clinicalMetrics: const [],
  );
}

class _CountingRemoteDataSource extends ProductRemoteDataSource {
  int fetchProductsCalls = 0;
  int fetchCategoriesCalls = 0;
  int fetchProductByIdCalls = 0;

  _CountingRemoteDataSource() : super(dio: Dio());

  @override
  Future<({List<ProductItem> items, bool hasMore, int total})> fetchProducts({
    String? category,
    String? rootCause,
    String? query,
    int page = 1,
    int limit = 16,
  }) async {
    fetchProductsCalls++;
    return (
      items: [
        _createProduct('prod-1', category ?? 'Hair'),
      ],
      hasMore: false,
      total: 1,
    );
  }

  @override
  Future<List<CategoryItem>> fetchCategories({String? type}) async {
    fetchCategoriesCalls++;
    return const [
      CategoryItem(id: 'hair', name: 'Hair Care', slug: 'hair-care'),
      CategoryItem(id: 'dandruff', name: 'Dandruff Control', slug: 'dandruff'),
    ];
  }

  @override
  Future<ProductItem?> fetchProductById(String id) async {
    fetchProductByIdCalls++;
    return _createProduct(id, 'Hair');
  }
}

void main() {
  setUp(() {
    ProductRepositoryImpl.clearCache();
  });

  tearDown(() {
    ProductRepositoryImpl.clearCache();
  });

  group('ProductRepositoryImpl TTL Caching', () {
    test('getCategories caches result and does not re-fetch from network', () async {
      final remote = _CountingRemoteDataSource();
      final repo = ProductRepositoryImpl(remoteDataSource: remote);

      final first = await repo.getCategories();
      expect(first.length, 2);
      expect(remote.fetchCategoriesCalls, 1);

      // Second call must return cached result
      final second = await repo.getCategories();
      expect(second.length, 2);
      expect(remote.fetchCategoriesCalls, 1); // No new network call
    });

    test('getProducts caches catalog pages by key (category, query, page)', () async {
      final remote = _CountingRemoteDataSource();
      final repo = ProductRepositoryImpl(remoteDataSource: remote);

      final page1 = await repo.getProducts(category: 'hair', page: 1);
      expect(page1.items.length, 1);
      expect(remote.fetchProductsCalls, 1);

      // Same category + page must hit cache
      final page1Cached = await repo.getProducts(category: 'hair', page: 1);
      expect(page1Cached.items.length, 1);
      expect(remote.fetchProductsCalls, 1);

      // Different category triggers new fetch
      final pageDandruff = await repo.getProducts(category: 'dandruff', page: 1);
      expect(pageDandruff.items.length, 1);
      expect(remote.fetchProductsCalls, 2);
    });

    test('getProductById caches product detail and clearCache invalidates', () async {
      final remote = _CountingRemoteDataSource();
      final repo = ProductRepositoryImpl(remoteDataSource: remote);

      final p1 = await repo.getProductById('prod-1');
      expect(p1?.name, 'Product prod-1');
      expect(remote.fetchProductByIdCalls, 1);

      final p1Cached = await repo.getProductById('prod-1');
      expect(p1Cached?.name, 'Product prod-1');
      expect(remote.fetchProductByIdCalls, 1);

      // Clearing cache forces a fresh fetch
      ProductRepositoryImpl.clearCache();
      final p1AfterClear = await repo.getProductById('prod-1');
      expect(p1AfterClear?.name, 'Product prod-1');
      expect(remote.fetchProductByIdCalls, 2);
    });
  });
}
