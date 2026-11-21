import 'dart:async';

import '../../helpers/product_test_fixtures.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:dr_hair/features/care/presentation/viewmodels/care_cubit.dart';
import 'package:dr_hair/features/app_config/data/app_config_repository.dart';
import 'package:dr_hair/features/app_config/presentation/viewmodels/app_config_cubit.dart';
import 'package:dr_hair/features/app_config/presentation/viewmodels/app_config_state.dart';
import 'package:dr_hair/features/hair_test/presentation/viewmodels/hair_test_cubit.dart';
import 'package:dr_hair/features/home/domain/models/home_action_card.dart';
import 'package:dr_hair/features/home/presentation/viewmodels/home_summary_cubit.dart';
import 'package:dr_hair/features/home/presentation/viewmodels/home_summary_state.dart';
import 'package:dr_hair/features/home/presentation/views/home_view.dart';
import 'package:dr_hair/core/theme/app_theme.dart';
import 'package:dr_hair/features/shop/data/models/category_model.dart';
import 'package:dr_hair/features/shop/data/models/product_model.dart';
import 'package:dr_hair/features/shop/domain/repositories/product_repository.dart';
import 'package:dr_hair/features/reviews/data/datasources/review_remote_data_source.dart';
import 'package:dr_hair/features/reviews/data/models/review_model.dart';
import 'package:dr_hair/features/videos/domain/models/video_story_model.dart';
import 'package:dr_hair/features/videos/domain/repositories/video_repository.dart';

import '../../helpers/video_test_fixtures.dart';

class _FakeReviewRemoteDataSource extends Fake
    implements ReviewRemoteDataSource {
  @override
  Future<List<ReviewModel>> getReviews({String? category, int? page}) async {
    return const [
      ReviewModel(
        id: 'rev-1',
        name: 'Rahul Sharma',
        rating: 5,
        category: 'Hair Fall',
        comment: 'Great clinical progress in 3 months with verified treatment.',
      ),
    ];
  }
}

class _FakeHomeProductRepository implements ProductRepository {
  @override
  Future<({List<ProductItem> items, bool hasMore, int total})> getProducts({
    String? category,
    String? rootCause,
    String? query,
    int page = 1,
    int limit = 20,
  }) async {
    final items = ProductTestFixtures.catalog.take(limit).toList();
    return (items: items, hasMore: false, total: items.length);
  }

  @override
  Future<ProductItem?> getProductById(String id) async {
    for (final product in ProductTestFixtures.catalog) {
      if (product.id == id) return product;
    }
    return null;
  }

  @override
  Future<List<CategoryItem>> getCategories({String? type}) async {
    return ProductTestFixtures.categories;
  }
}

class _PendingProductRepository implements ProductRepository {
  final Future<({List<ProductItem> items, bool hasMore, int total})>
  pendingFuture;

  _PendingProductRepository(this.pendingFuture);

  @override
  Future<({List<ProductItem> items, bool hasMore, int total})> getProducts({
    String? category,
    String? rootCause,
    String? query,
    int page = 1,
    int limit = 20,
  }) => pendingFuture;

  @override
  Future<ProductItem?> getProductById(String id) async => null;

  @override
  Future<List<CategoryItem>> getCategories({String? type}) async => [];
}

class _FakeHomeVideoRepository implements VideoRepository {
  @override
  Future<({List<VideoStoryModel> items, bool hasMore, int total, int page})>
  getVideos({
    int page = 1,
    int limit = 10,
    String? category,
    String? placement = 'reels',
  }) async {
    final items = VideoTestFixtures.testStories.take(limit).toList();
    return (items: items, hasMore: false, total: items.length, page: 1);
  }

  @override
  Future<List<String>> getVideoCategories() async {
    return const ['All', 'Hair Fall', 'Regrowth', 'Dandruff', 'Doctor Advice'];
  }
}

class _EmptyHomeVideoRepository implements VideoRepository {
  @override
  Future<({List<VideoStoryModel> items, bool hasMore, int total, int page})>
  getVideos({
    int page = 1,
    int limit = 10,
    String? category,
    String? placement = 'reels',
  }) async {
    return (
      items: const <VideoStoryModel>[],
      hasMore: false,
      total: 0,
      page: 1,
    );
  }

  @override
  Future<List<String>> getVideoCategories() async => const [];
}

class _CountingProductRepository extends _FakeHomeProductRepository {
  int calls = 0;

  @override
  Future<({List<ProductItem> items, bool hasMore, int total})> getProducts({
    String? category,
    String? rootCause,
    String? query,
    int page = 1,
    int limit = 20,
  }) {
    calls++;
    return super.getProducts(
      category: category,
      rootCause: rootCause,
      query: query,
      page: page,
      limit: limit,
    );
  }
}

class _CountingHomeVideoRepository extends _EmptyHomeVideoRepository {
  int calls = 0;

  @override
  Future<({List<VideoStoryModel> items, bool hasMore, int total, int page})>
  getVideos({
    int page = 1,
    int limit = 10,
    String? category,
    String? placement = 'reels',
  }) {
    calls++;
    return super.getVideos(
      page: page,
      limit: limit,
      category: category,
      placement: placement,
    );
  }
}

class _CountingReviewDataSource extends _FakeReviewRemoteDataSource {
  int calls = 0;

  @override
  Future<List<ReviewModel>> getReviews({String? category, int? page}) {
    calls++;
    return super.getReviews(category: category, page: page);
  }
}

class _StaticFeatureRepository extends AppConfigRepository {
  final Map<String, bool> flags;

  _StaticFeatureRepository(this.flags);

  @override
  bool get hasFreshCache => true;

  @override
  Map<String, bool> getCachedFeatures() => flags;

  @override
  AppointmentBillingConfig getCachedBillingConfig() =>
      const AppointmentBillingConfig();
}

Future<void> _scrollHomeUntil(WidgetTester tester, Finder target) async {
  final homeScroll = find.byType(CustomScrollView).first;
  for (var attempt = 0; attempt < 12 && target.evaluate().isEmpty; attempt++) {
    await tester.drag(homeScroll, const Offset(0, -520));
    await tester.pumpAndSettle();
  }
}

void main() {
  Widget buildHomeView({
    VoidCallback? onStartHairTest,
    ReviewRemoteDataSource? reviewDataSource,
  }) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<CareCubit>(create: (_) => CareCubit()),
        BlocProvider<HairTestCubit>(create: (_) => HairTestCubit()),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: HomeView(
            onStartHairTest: onStartHairTest ?? () {},
            productRepository: _FakeHomeProductRepository(),
            videoRepository: _FakeHomeVideoRepository(),
            reviewDataSource: reviewDataSource ?? _FakeReviewRemoteDataSource(),
          ),
        ),
      ),
    );
  }

  testWidgets('Home skips network fetches for disabled optional sections', (
    tester,
  ) async {
    final configCubit = AppConfigCubit(
      repository: _StaticFeatureRepository(const {
        'shop': false,
        'reviews': false,
        'videos': false,
      }),
    );
    addTearDown(configCubit.close);
    final products = _CountingProductRepository();
    final videos = _CountingHomeVideoRepository();
    final reviews = _CountingReviewDataSource();

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<AppConfigCubit>.value(value: configCubit),
          BlocProvider<CareCubit>(create: (_) => CareCubit()),
          BlocProvider<HairTestCubit>(create: (_) => HairTestCubit()),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: HomeView(
              onStartHairTest: () {},
              productRepository: products,
              videoRepository: videos,
              reviewDataSource: reviews,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(products.calls, 0);
    expect(videos.calls, 0);
    expect(reviews.calls, 0);
    expect(find.text('Essential Products'), findsNothing);
    expect(find.text('Voices of Success'), findsNothing);
    expect(find.text('Real Patient Stories'), findsNothing);
  });

  testWidgets(
    'HomeView prioritizes products and care access before optional information',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildHomeView());
      await tester.pumpAndSettle();

      // Verify the home screen and its first patient action.
      expect(find.byType(HomeView), findsOneWidget);
      await _scrollHomeUntil(tester, find.text('Essential Products'));
      expect(find.text('Essential Products'), findsOneWidget);
      await _scrollHomeUntil(tester, find.text('URGENT CARE'));
      expect(find.text('Clinic Consultation'), findsOneWidget);
      expect(find.text('URGENT CARE'), findsOneWidget);
      await _scrollHomeUntil(tester, find.text('Voices of Success'));
      expect(find.text('Voices of Success'), findsOneWidget);
      expect(find.text('50M+'), findsNothing);
      expect(find.text('20,000+'), findsNothing);
      expect(find.text('18,000+'), findsNothing);
      expect(find.text('Trusted by Thousands'), findsNothing);
    },
  );

  testWidgets('HomeView scrolls to reveal Reviews and Video Stories below', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildHomeView());
    await tester.pumpAndSettle();

    await _scrollHomeUntil(tester, find.text('Voices of Success'));

    expect(find.text('Voices of Success'), findsOneWidget);
    expect(find.text('Real Patient Stories'), findsOneWidget);

    await _scrollHomeUntil(tester, find.text('Real Patient Stories'));
    expect(find.text('Real Patient Stories'), findsOneWidget);
  });

  testWidgets(
    'HomeView displays Pending Assessment Stepper and triggers onStartHairTest',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool started = false;
      await tester.pumpWidget(
        buildHomeView(
          onStartHairTest: () {
            started = true;
          },
        ),
      );
      await tester.pumpAndSettle();

      // Verify Stepper Header and Milestone labels
      expect(find.text('Hair & Scalp Assessment'), findsOneWidget);
      expect(find.text('PENDING'), findsOneWidget);
      expect(find.text('Pattern'), findsOneWidget);
      expect(find.text('Scalp'), findsOneWidget);
      expect(find.text('Habits'), findsOneWidget);
      expect(find.text('Photos'), findsOneWidget);

      // Verify Stepper CTA button and interaction
      final ctaButton = find.text('Start Free Hair Assessment');
      expect(ctaButton, findsOneWidget);

      await tester.ensureVisible(ctaButton);
      await tester.tap(ctaButton);
      await tester.pumpAndSettle();

      expect(started, isTrue);
    },
  );

  testWidgets(
    'HomeView renders Skeletonizer shimmer while products and videos are loading',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final completer =
          Completer<({List<ProductItem> items, bool hasMore, int total})>();

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<CareCubit>(create: (_) => CareCubit()),
            BlocProvider<HairTestCubit>(create: (_) => HairTestCubit()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: HomeView(
                onStartHairTest: () {},
                productRepository: _PendingProductRepository(completer.future),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Verify Skeletonizer shimmer cards are displayed during loading
      expect(
        find.byWidgetPredicate((widget) => widget is Skeletonizer),
        findsWidgets,
      );

      // Verify no CircularProgressIndicator is rendered
      expect(find.byType(CircularProgressIndicator), findsNothing);

      completer.complete((items: <ProductItem>[], hasMore: false, total: 0));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'HomeView hides Real Patient Stories section completely when stories list is empty',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<CareCubit>(create: (_) => CareCubit()),
            BlocProvider<HairTestCubit>(create: (_) => HairTestCubit()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: HomeView(
                onStartHairTest: () {},
                productRepository: _FakeHomeProductRepository(),
                videoRepository: _EmptyHomeVideoRepository(),
                reviewDataSource: _FakeReviewRemoteDataSource(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Real Patient Stories'), findsNothing);
      expect(find.text('Watch All'), findsNothing);
      expect(find.text('No video stories are published yet.'), findsNothing);
    },
  );

  testWidgets(
    'HomeView renders new clinical report card with title, view all, and unread highlight when report exists',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final summaryCubit = HomeSummaryCubit();
      summaryCubit.emit(
        const HomeSummaryState(
          data: HomeSummaryData(
            latestReport: {
              'id': 'rep_new_1',
              'title': 'Trichoscopy Scalp Examination',
              'file_name': 'trichoscopy_report.pdf',
              'bytes': 1572864,
              'uploaded_by': 'Dr. Jai Bansal',
              'created_at': '2026-11-19T10:00:00Z',
            },
          ),
        ),
      );

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<CareCubit>(create: (_) => CareCubit()),
            BlocProvider<HairTestCubit>(create: (_) => HairTestCubit()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: HomeView(
                onStartHairTest: () {},
                homeSummaryCubit: summaryCubit,
                productRepository: _FakeHomeProductRepository(),
                videoRepository: _FakeHomeVideoRepository(),
                reviewDataSource: _FakeReviewRemoteDataSource(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Clinical Reports'), findsOneWidget);
      expect(find.text('View all'), findsOneWidget);
      expect(find.text('Trichoscopy Scalp Examination'), findsOneWidget);
      expect(find.text('NEW'), findsOneWidget);
      expect(find.textContaining('Received: 19 Nov 2026'), findsOneWidget);
    },
  );
}
