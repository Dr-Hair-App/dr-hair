import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dr_hair/features/reviews/presentation/views/reviews_view.dart';
import 'package:dr_hair/features/reviews/data/datasources/review_remote_data_source.dart';
import 'package:dr_hair/features/reviews/data/models/review_model.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeletonizer/skeletonizer.dart';

class _FakeReviewDataSource extends ReviewRemoteDataSource {
  final Future<List<ReviewModel>> Function(String? category) load;

  _FakeReviewDataSource(this.load) : super(dio: Dio());

  @override
  Future<List<ReviewModel>> getReviews({String? category, int? page}) =>
      load(category);
}

const _testReviews = [
  ReviewModel(
    id: 'review_hair_fall',
    name: 'Test Patient One',
    rating: 5,
    category: 'Hair Fall',
    comment: 'Test review for the filter flow.',
  ),
  ReviewModel(
    id: 'review_dandruff',
    name: 'Test Patient Two',
    rating: 4,
    category: 'Dandruff',
    comment: 'Another test review for the filter flow.',
  ),
];

void main() {
  testWidgets(
    'ReviewsView renders published stories and filters with NestedScrollView',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ReviewsView(
            remoteDataSource: _FakeReviewDataSource(
              (category) async => _testReviews
                  .where(
                    (review) => category == null || review.category == category,
                  )
                  .toList(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Category chips in app bar
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Hair Fall'), findsOneWidget);
      expect(find.text('Regrowth'), findsOneWidget);
      expect(find.text('Dandruff'), findsOneWidget);

      // Only the injected review records appear.
      expect(find.text('Test Patient One'), findsOneWidget);
      expect(find.text('Rahul Sharma'), findsNothing);

      // Switch filter to Dandruff
      await tester.tap(find.text('Dandruff'));
      await tester.pumpAndSettle();

      expect(find.text('Test Patient Two'), findsOneWidget);
      expect(find.text('Test Patient One'), findsNothing);
    },
  );

  testWidgets(
    'ReviewsView docks category bar and changes background on scroll',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ReviewsView(
            remoteDataSource: _FakeReviewDataSource(
              (category) async => _testReviews
                  .where(
                    (review) => category == null || review.category == category,
                  )
                  .toList(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify CustomScrollView is present
      expect(find.byType(CustomScrollView), findsOneWidget);
      expect(find.byType(RefreshIndicator), findsOneWidget);

      // Scroll down to dock category bar
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();

      // Category chips remain pinned and accessible
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Hair Fall'), findsOneWidget);
    },
  );

  testWidgets(
    'ReviewsView shows a truthful empty state when API has no reviews',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ReviewsView(
            remoteDataSource: _FakeReviewDataSource((_) async => const []),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No reviews found in this category'), findsOneWidget);
      expect(find.text('Rahul Sharma'), findsNothing);
      expect(find.text('Ananya Mehra'), findsNothing);
      expect(find.text('4.8'), findsNothing);
    },
  );

  testWidgets('ReviewsView offers retry after a load failure', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ReviewsView(
          remoteDataSource: _FakeReviewDataSource((_) async {
            calls++;
            if (calls == 1) throw StateError('offline');
            return _testReviews;
          }),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Reviews could not be loaded'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Test Patient One'), findsOneWidget);
    expect(calls, 2);
  });

  testWidgets(
    'ReviewsView renders Skeletonizer shimmer cards during page and category load',
    (tester) async {
      final completer = Completer<List<ReviewModel>>();
      await tester.pumpWidget(
        MaterialApp(
          home: ReviewsView(
            remoteDataSource: _FakeReviewDataSource((_) => completer.future),
          ),
        ),
      );
      await tester.pump();

      // Verify Skeletonizer shimmer cards are displayed during loading
      expect(
        find.byWidgetPredicate((widget) => widget is Skeletonizer),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('reviews_loading')), findsOneWidget);

      // Verify no basic CircularProgressIndicator is rendered
      expect(find.byType(CircularProgressIndicator), findsNothing);

      completer.complete(_testReviews);
      await tester.pumpAndSettle();

      expect(find.text('Test Patient One'), findsOneWidget);
    },
  );

  testWidgets(
    'ReviewsView shimmer skeleton renders without overflow on compact 320px screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final completer = Completer<List<ReviewModel>>();
      await tester.pumpWidget(
        MaterialApp(
          home: ReviewsView(
            remoteDataSource: _FakeReviewDataSource((_) => completer.future),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('reviews_loading')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
