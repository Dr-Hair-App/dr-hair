import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dr_hair/features/reviews/data/datasources/review_remote_data_source.dart';

void main() {
  test(
    'empty review response remains empty instead of using sample stories',
    () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              data: {
                'data': {'items': <dynamic>[]},
              },
            ),
          ),
        ),
      );

      final reviews = await ReviewRemoteDataSource(dio: dio).getReviews();

      expect(reviews, isEmpty);
    },
  );

  test('only complete and approved API reviews are returned', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.resolve(
          Response<Map<String, dynamic>>(
            requestOptions: options,
            data: {
              'data': {
                'items': [
                  {
                    'id': 'approved-1',
                    'name': 'Patient One',
                    'rating': 5,
                    'category': 'Hair Fall',
                    'message': 'Shared after review.',
                    'is_verified': true,
                  },
                  {
                    'id': 'unapproved-2',
                    'name': 'Patient Two',
                    'rating': 5,
                    'category': 'Hair Fall',
                    'message': 'Not approved yet.',
                    'is_verified': false,
                  },
                ],
              },
            },
          ),
        ),
      ),
    );

    final reviews = await ReviewRemoteDataSource(dio: dio).getReviews();

    expect(reviews, hasLength(1));
    expect(reviews.single.id, 'approved-1');
    expect(reviews.single.verified, isTrue);
  });

  test('review API failure is surfaced to the screen for retry', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.reject(
          DioException(requestOptions: options, message: 'offline'),
        ),
      ),
    );

    await expectLater(
      ReviewRemoteDataSource(dio: dio).getReviews(),
      throwsA(isA<DioException>()),
    );
  });
}
