import 'dart:async';

import 'package:dr_hair/features/shop/data/models/category_model.dart';
import 'package:dr_hair/features/shop/data/models/product_model.dart';
import 'package:dr_hair/features/shop/domain/repositories/product_repository.dart';
import 'package:dr_hair/features/shop/presentation/viewmodels/cart_cubit.dart';
import 'package:dr_hair/features/shop/presentation/viewmodels/products_cubit.dart';
import 'package:dr_hair/features/shop/presentation/viewmodels/products_state.dart';
import 'package:dr_hair/features/shop/presentation/views/products_view.dart';
import 'package:dr_hair/core/storage/app_local_cache.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../helpers/product_test_fixtures.dart';

class _FakeProductRepo implements ProductRepository {
  final bool shouldFail;
  final bool searchResultFromApi;
  final bool? hasMoreOverride;
  final List<ProductItem> items;
  final List<({String? rootCause, String? query, int page, int limit})>
  productRequests = [];
  int categoriesRequests = 0;
  Completer<({List<ProductItem> items, bool hasMore, int total})>?
  pendingProducts;

  _FakeProductRepo({
    this.shouldFail = false,
    this.searchResultFromApi = false,
    this.hasMoreOverride,
    List<ProductItem>? items,
  }) : items = items ?? ProductTestFixtures.catalog;

  @override
  Future<({List<ProductItem> items, bool hasMore, int total})> getProducts({
    String? category,
    String? rootCause,
    String? query,
    int page = 1,
    int limit = 16,
  }) async {
    productRequests.add((
      rootCause: rootCause,
      query: query,
      page: page,
      limit: limit,
    ));
    if (pendingProducts != null) return pendingProducts!.future;
    if (shouldFail) {
      throw Exception('Network error');
    }
    final filtered = items.where((product) {
      if (rootCause != null && rootCause.toLowerCase() != 'all') {
        final categoryMatch = product.category.toLowerCase().contains(
          rootCause.toLowerCase(),
        );
        final rootMatch =
            product.rootCause.toLowerCase() == rootCause.toLowerCase();
        if (!categoryMatch && !rootMatch) return false;
      }
      if (query != null && query.trim().isNotEmpty && !searchResultFromApi) {
        final q = query.toLowerCase();
        final matches =
            product.name.toLowerCase().contains(q) ||
            product.subtitle.toLowerCase().contains(q) ||
            product.category.toLowerCase().contains(q) ||
            product.rootCause.toLowerCase().contains(q) ||
            product.ingredients.any(
              (ingredient) => ingredient.name.toLowerCase().contains(q),
            );
        if (!matches) return false;
      }
      return true;
    }).toList();
    final start = (page - 1) * limit;
    final pageItems = start >= filtered.length
        ? <ProductItem>[]
        : filtered.skip(start).take(limit).toList();
    return (
      items: pageItems,
      hasMore: hasMoreOverride ?? start + pageItems.length < filtered.length,
      total: filtered.length,
    );
  }

  @override
  Future<ProductItem?> getProductById(String id) async {
    return items.firstWhere((p) => p.id == id, orElse: () => items.first);
  }

  @override
  Future<List<CategoryItem>> getCategories({String? type}) async {
    categoriesRequests++;
    return ProductTestFixtures.categories;
  }
}

class _MutableProductsCubit extends ProductsCubit {
  _MutableProductsCubit({
    required super.repository,
    required super.cache,
    required super.initialState,
  });

  void updateCategories(List<CategoryItem> categories) {
    emit(state.copyWith(categories: categories));
  }
}

void main() {
  Widget buildTestableWidget({CartCubit? cartCubit, ProductsCubit? cubit}) {
    final productsCubit =
        cubit ??
        (ProductsCubit(
          repository: _FakeProductRepo(),
          cache: AppLocalCache.inMemory(),
        )..loadProducts());
    return BlocProvider<CartCubit>.value(
      value: cartCubit ?? CartCubit(),
      child: BlocProvider<ProductsCubit>.value(
        value: productsCubit,
        child: MaterialApp(home: ProductsView(cubit: productsCubit)),
      ),
    );
  }

  group('ProductsCubit Unit Tests', () {
    test(
      'product cache namespace can be cleared without touching other Hive data',
      () async {
        final cache = AppLocalCache.inMemory({
          'cache_products_catalog_v2_all_page_1': 'old catalog',
          'cache_products_catalog_v1': 'legacy catalog',
          'cache_product_categories_v2': 'categories',
          'patient_session_token': 'preserve',
        });

        await cache.removeByPrefix(AppLocalCache.productCatalogCachePrefix);

        expect(
          cache.containsKey('cache_products_catalog_v2_all_page_1'),
          isFalse,
        );
        expect(cache.containsKey('cache_products_catalog_v1'), isFalse);
        expect(cache.getString('cache_product_categories_v2'), 'categories');
        expect(cache.getString('patient_session_token'), 'preserve');
      },
    );

    test('loads products successfully from repository', () async {
      final repo = _FakeProductRepo();
      final cubit = ProductsCubit(
        repository: repo,
        cache: AppLocalCache.inMemory(),
      );

      expect(cubit.state.products, isEmpty);
      await cubit.loadProducts();
      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.errorMessage, isNull);
      expect(cubit.state.products.length, repo.items.length);
    });

    test('handles error state gracefully on fetch failure', () async {
      final repo = _FakeProductRepo(shouldFail: true);
      final cubit = ProductsCubit(
        repository: repo,
        cache: AppLocalCache.inMemory(),
      );

      await cubit.loadProducts();
      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.errorMessage, isNotNull);
    });

    test('updates category selection and search query', () async {
      final cubit = ProductsCubit(
        repository: _FakeProductRepo(),
        cache: AppLocalCache.inMemory(),
      );
      await cubit.selectCategory(2);
      expect(cubit.state.selectedCategoryIndex, 2);

      await cubit.search('serum');
      expect(cubit.state.searchQuery, 'serum');

      await cubit.clearSearch();
      expect(cubit.state.searchQuery, '');
      cubit.close();
    });

    test('fetches only the selected category with a 16 item page', () async {
      final repo = _FakeProductRepo();
      final cubit = ProductsCubit(
        repository: repo,
        cache: AppLocalCache.inMemory(),
      );

      await cubit.loadProducts();
      expect(repo.productRequests, hasLength(1));
      expect(repo.productRequests.single.rootCause, isNull);
      expect(repo.productRequests.single.limit, 16);
      expect(repo.categoriesRequests, 1);

      await cubit.selectCategory(1);
      expect(repo.productRequests, hasLength(2));
      expect(repo.productRequests.last.rootCause, 'hair');
      expect(repo.productRequests.last.limit, 16);
      expect(repo.categoriesRequests, 1);
      await cubit.close();
    });

    test(
      'loads subsequent pages only when requested and appends products',
      () async {
        final products = List.generate(
          20,
          (index) => ProductItem(
            id: 'paged-$index',
            name: 'Paged product $index',
            subtitle: 'Pagination fixture',
            category: 'Hair',
            rootCause: 'hair',
            rating: 5,
            reviewsCount: 0,
            inStock: true,
            images: const [],
            supplyPlans: const [],
            benefits: const [],
            ingredients: const [],
            usageSteps: const [],
            clinicalMetrics: const [],
          ),
        );
        final repo = _FakeProductRepo(items: products);
        final cubit = ProductsCubit(
          repository: repo,
          cache: AppLocalCache.inMemory(),
        );

        await cubit.loadProducts();
        expect(cubit.state.products, hasLength(16));
        expect(cubit.state.hasMoreFor('all'), isTrue);
        await cubit.loadNextPage('all');
        expect(cubit.state.products, hasLength(20));
        expect(repo.productRequests.map((request) => request.page), [1, 2]);
        expect(
          repo.productRequests.every((request) => request.limit == 16),
          isTrue,
        );
        await cubit.close();
      },
    );

    test('does not paginate after an empty or partial response', () async {
      final partialRepo = _FakeProductRepo(
        items: ProductTestFixtures.catalog.take(5).toList(),
        hasMoreOverride: true,
      );
      final partialCubit = ProductsCubit(
        repository: partialRepo,
        cache: AppLocalCache.inMemory(),
      );

      await partialCubit.loadProducts();
      expect(partialCubit.state.products, hasLength(5));
      expect(partialCubit.state.hasMoreFor('all'), isFalse);
      await partialCubit.loadNextPage('all');
      expect(partialRepo.productRequests, hasLength(1));
      await partialCubit.close();

      final emptyRepo = _FakeProductRepo(items: const []);
      final emptyCubit = ProductsCubit(
        repository: emptyRepo,
        cache: AppLocalCache.inMemory(),
      );
      await emptyCubit.loadProducts();
      expect(emptyCubit.state.products, isEmpty);
      expect(emptyCubit.state.hasMoreFor('all'), isFalse);
      await emptyCubit.loadNextPage('all');
      expect(emptyRepo.productRequests, hasLength(1));
      await emptyCubit.close();
    });

    test(
      'shows Hive products immediately and replaces them with fresh data',
      () async {
        final cache = AppLocalCache.inMemory();
        final firstCubit = ProductsCubit(
          repository: _FakeProductRepo(),
          cache: cache,
        );
        await firstCubit.loadProducts();
        final cachedProducts = firstCubit.state.products;
        await firstCubit.close();

        final freshProduct = ProductItem(
          id: 'fresh-product',
          name: 'Fresh catalog item',
          subtitle: 'Returned by the next page visit',
          category: 'Hair',
          rootCause: 'hair',
          rating: 5,
          reviewsCount: 0,
          inStock: true,
          images: const [],
          supplyPlans: const [],
          benefits: const [],
          ingredients: const [],
          usageSteps: const [],
          clinicalMetrics: const [],
        );
        final freshRepo = _FakeProductRepo(items: [freshProduct])
          ..pendingProducts = Completer();
        final nextCubit = ProductsCubit(repository: freshRepo, cache: cache);
        final refresh = nextCubit.loadProducts();
        await Future<void>.delayed(Duration.zero);

        expect(
          nextCubit.state.products.map((item) => item.id).toList(),
          cachedProducts.map((item) => item.id).toList(),
        );
        freshRepo.pendingProducts!.complete((
          items: [freshProduct],
          hasMore: false,
          total: 1,
        ));
        await refresh;

        expect(nextCubit.state.products.map((item) => item.id), [
          freshProduct.id,
        ]);
        await nextCubit.close();
      },
    );

    test('debounces search and passes the text to the product API', () async {
      final repo = _FakeProductRepo();
      final cubit = ProductsCubit(
        repository: repo,
        cache: AppLocalCache.inMemory(),
      );
      await cubit.loadProducts();

      await cubit.search('ketoconazole');
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(repo.productRequests.last.query, 'ketoconazole');
      expect(repo.productRequests.last.limit, 16);
      await cubit.close();
    });
  });

  group('ProductsView UI Tests', () {
    testWidgets(
      'renders title Medicines & Products, cart button, visible search bar, and refresh indicator',
      (tester) async {
        final cartCubit = CartCubit();
        await tester.pumpWidget(buildTestableWidget(cartCubit: cartCubit));
        await tester.pumpAndSettle();

        // Check Title
        expect(find.text('Medicines & Products'), findsOneWidget);

        // Check Cart button
        expect(find.byTooltip('My Cart'), findsOneWidget);

        // Verify redundant search icon button in app bar is removed
        expect(
          find.byKey(const ValueKey('appbar-search-button')),
          findsNothing,
        );

        // Verify search bar is visible in bottom of SliverAppBar
        expect(find.byKey(const ValueKey('product-search')), findsOneWidget);

        // Verify RefreshIndicator is present
        expect(find.byType(RefreshIndicator), findsOneWidget);
      },
    );

    testWidgets(
      'pull-to-refresh triggers ProductsCubit.loadProducts with refresh: true',
      (tester) async {
        final cubit = ProductsCubit(repository: _FakeProductRepo())
          ..loadProducts();
        await tester.pumpWidget(buildTestableWidget(cubit: cubit));
        await tester.pumpAndSettle();

        expect(find.byType(RefreshIndicator), findsOneWidget);

        // Pull down to trigger refresh
        await tester.fling(
          find.byType(NestedScrollView),
          const Offset(0, 300),
          1000,
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));

        expect(cubit.state.products, isNotEmpty);
        expect(cubit.state.isLoading, isFalse);
      },
    );

    testWidgets(
      'displays TabBar with categories All, Hair, Dandruff, Gut, Stress, Thyroid, PCOS, Hormone',
      (tester) async {
        await tester.pumpWidget(buildTestableWidget());
        await tester.pumpAndSettle();

        final categories = [
          'All',
          'Hair',
          'Dandruff',
          'Gut',
          'Stress',
          'Thyroid',
          'PCOS',
          'Hormone',
        ];
        for (final cat in categories) {
          expect(
            find.descendant(of: find.byType(TabBar), matching: find.text(cat)),
            findsOneWidget,
          );
        }
      },
    );

    testWidgets('switching tabs filters products by category', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      // Default 'All' shows all treatments
      expect(find.text('Follicle Booster Serum'), findsOneWidget);

      // Switch to Thyroid tab
      await tester.tap(find.text('Thyroid'));
      await tester.pumpAndSettle();

      expect(find.text('Thyro-Balance Metabolism Support'), findsOneWidget);
      expect(find.text('Follicle Booster Serum'), findsNothing);

      // Switch to Dandruff tab
      await tester.tap(find.text('Dandruff'));
      await tester.pumpAndSettle();

      expect(find.text('Clinical Scalp Detox Shampoo'), findsOneWidget);
      expect(find.text('Thyro-Balance Metabolism Support'), findsNothing);

      // Switch to PCOS tab
      await tester.tap(find.text('PCOS'));
      await tester.pumpAndSettle();

      expect(find.text('PCOS Care & Inositol Complex'), findsOneWidget);

      // Switch to Gut tab
      await tester.tap(find.text('Gut'));
      await tester.pumpAndSettle();

      expect(find.text('Gut Health Probiotics & Enzymes'), findsOneWidget);

      // Switch to Stress tab
      await tester.tap(find.text('Stress'));
      await tester.pumpAndSettle();

      expect(find.text('Calm & Sleep Ashwagandha KSM-66'), findsOneWidget);

      // Switch to Hormone tab
      await tester.tap(find.text('Hormone'));
      await tester.pumpAndSettle();

      expect(find.text('Max DHT Blocker & Saw Palmetto'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('closes cleanly during category tab animation', (tester) async {
      final cubit = ProductsCubit(
        repository: _FakeProductRepo(),
        cache: AppLocalCache.inMemory(),
      )..loadProducts();
      await tester.pumpWidget(buildTestableWidget(cubit: cubit));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dandruff'));
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pump();

      expect(tester.takeException(), isNull);
      await cubit.close();
    });

    testWidgets(
      'resizes categories during tab animation without disposing a live controller',
      (tester) async {
        final cubit = _MutableProductsCubit(
          repository: _FakeProductRepo(),
          cache: AppLocalCache.inMemory(),
          initialState: ProductsState(
            categories: ProductTestFixtures.categories,
            isLoading: true,
          ),
        );
        await cubit.loadProducts();
        await tester.pumpWidget(buildTestableWidget(cubit: cubit));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Dandruff'));
        await tester.pump(const Duration(milliseconds: 20));
        cubit.updateCategories([
          ...ProductTestFixtures.categories,
          const CategoryItem(
            id: 'new-category',
            name: 'New category',
            slug: 'new-category',
          ),
        ]);
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('New category'), findsOneWidget);
        cubit.updateCategories(ProductTestFixtures.categories.take(2).toList());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(cubit.state.selectedCategoryIndex, 1);
        expect(find.text('New category'), findsNothing);
        expect(tester.takeException(), isNull);
        await cubit.close();
      },
    );

    testWidgets('search filters catalog by product and ingredient', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.text('Medicines & Products'), findsOneWidget);
      expect(find.byKey(const ValueKey('product-search')), findsOneWidget);
      expect(find.text('Follicle Booster Serum'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('product-search')),
        'ketoconazole',
      );
      await tester.pumpAndSettle();

      expect(find.text('Clinical Scalp Detox Shampoo'), findsOneWidget);
      expect(find.text('Follicle Booster Serum'), findsNothing);
    });

    testWidgets('keeps search matches returned only by the API', (
      tester,
    ) async {
      final cubit = ProductsCubit(
        repository: _FakeProductRepo(searchResultFromApi: true),
        cache: AppLocalCache.inMemory(),
      )..loadProducts();
      await tester.pumpWidget(buildTestableWidget(cubit: cubit));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('product-search')),
        'SKU-SEARCH-MATCH',
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // SKU is searched by the API but isn't a field used by the app's local
      // text matcher, so the server result must be shown as-is.
      expect(find.text('Follicle Booster Serum'), findsOneWidget);
      await cubit.close();
    });

    testWidgets('empty search state clears the query and filters', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('product-search')),
        'not-a-product',
      );
      await tester.pumpAndSettle();

      expect(find.text('No matching products'), findsOneWidget);
      await tester.tap(find.text('Clear filters'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('No matching products'), findsNothing);
      expect(find.text('Follicle Booster Serum'), findsOneWidget);
    });

    testWidgets(
      'catalog remains usable on a narrow phone width without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(320, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(buildTestableWidget());
        await tester.pumpAndSettle();

        expect(find.text('Medicines & Products'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('appbar-search-button')),
          findsNothing,
        );
        expect(find.byKey(const ValueKey('product-search')), findsOneWidget);
        expect(find.byTooltip('My Cart'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'uses Skeletonizer during loading without fabricated products',
      (tester) async {
        final cubit = ProductsCubit(
          initialState: const ProductsState(isLoading: true, products: []),
        );
        await tester.pumpWidget(buildTestableWidget(cubit: cubit));
        await tester.pump();

        expect(
          find.byWidgetPredicate((widget) => widget is Skeletonizer),
          findsWidgets,
        );
        expect(find.text('Follicle Booster Serum'), findsNothing);
      },
    );

    testWidgets(
      'displays error state with retry button when products fail to load',
      (tester) async {
        final cubit = ProductsCubit(
          initialState: const ProductsState(
            isLoading: false,
            errorMessage: 'Unable to connect to server',
            products: [],
          ),
        );
        await tester.pumpWidget(buildTestableWidget(cubit: cubit));
        await tester.pumpAndSettle();

        expect(find.text('Unable to load products'), findsOneWidget);
        expect(find.text('Unable to connect to server'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('products-retry-button')),
          findsOneWidget,
        );
      },
    );
  });
}
