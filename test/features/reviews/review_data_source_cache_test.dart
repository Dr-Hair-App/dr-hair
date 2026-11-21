import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:dr_hair/features/reviews/data/datasources/review_remote_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

class _CountingAdapter implements HttpClientAdapter {
  int requestCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestCount++;
    return ResponseBody.fromString(
      '{"status":"success","data":[{"id":"rev-1","name":"Aarav Patel","rating":5,"comment":"Excellent scalp treatment","verified":true,"category":"Hair Fall"}]}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  setUp(() {
    ReviewRemoteDataSource.clearCache();
  });

  tearDown(() {
    ReviewRemoteDataSource.clearCache();
  });

  group('ReviewRemoteDataSource TTL Caching', () {
    test('getReviews caches reviews by category for 5 minutes', () async {
      final adapter = _CountingAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final ds = ReviewRemoteDataSource(dio: dio);

      final r1 = await ds.getReviews(category: 'Hair Fall');
      expect(r1.length, 1);
      expect(r1.first.name, 'Aarav Patel');
      expect(adapter.requestCount, 1);

      // Second call returns cached list
      final r2 = await ds.getReviews(category: 'Hair Fall');
      expect(r2.length, 1);
      expect(r2.first.name, 'Aarav Patel');
      expect(adapter.requestCount, 1); // No new network call!

      // Clear cache forces reload
      ds.clear();
      final r3 = await ds.getReviews(category: 'Hair Fall');
      expect(r3.length, 1);
      expect(adapter.requestCount, 2);
    });
  });
}
