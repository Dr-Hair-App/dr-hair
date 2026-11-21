import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:dr_hair/features/home/data/content_api.dart';
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
      '{"status":"success","data":[{"id":"tip-1","type":"tip","title":"Daily Scalp Care","placement":"home"}]}',
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
    ContentApi.clearCache();
  });

  tearDown(() {
    ContentApi.clearCache();
  });

  group('ContentApi TTL Caching', () {
    test('getPublishedContent caches tips and faqs in memory and skips repeated network requests', () async {
      final adapter = _CountingAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final api = ContentApi(dio: dio);

      final tips1 = await api.getPublishedContent(type: 'tip', placement: 'home');
      expect(tips1.length, 1);
      expect(tips1.first.title, 'Daily Scalp Care');
      expect(adapter.requestCount, 1);

      // Second call must return cached items
      final tips2 = await api.getPublishedContent(type: 'tip', placement: 'home');
      expect(tips2.length, 1);
      expect(tips2.first.title, 'Daily Scalp Care');
      expect(adapter.requestCount, 1); // Zero new network calls!

      // Clear cache triggers new network request
      ContentApi.clearCache();
      final tips3 = await api.getPublishedContent(type: 'tip', placement: 'home');
      expect(tips3.length, 1);
      expect(adapter.requestCount, 2);
    });
  });
}
