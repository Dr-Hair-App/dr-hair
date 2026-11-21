import 'package:dio/dio.dart';
import 'package:dr_hair/features/videos/data/datasources/video_remote_data_source.dart';
import 'package:dr_hair/features/videos/data/repositories/video_repository_impl.dart';
import 'package:dr_hair/features/videos/domain/models/video_story_model.dart';
import 'package:flutter_test/flutter_test.dart';

class _CountingVideoRemoteDataSource extends VideoRemoteDataSource {
  int fetchVideosCalls = 0;
  int fetchCategoriesCalls = 0;

  _CountingVideoRemoteDataSource() : super(dio: Dio());

  @override
  Future<({List<VideoStoryModel> items, bool hasMore, int total, int page})>
  fetchVideos({
    int page = 1,
    int limit = 10,
    String? category,
    String? placement = 'reels',
  }) async {
    fetchVideosCalls++;
    return (
      items: [
        VideoStoryModel.fromJson({
          'id': 'video-$page',
          'category': category ?? 'General',
          'name': 'Patient Video',
          'author_handle': '@patient',
        }),
      ],
      hasMore: false,
      total: 1,
      page: page,
    );
  }

  @override
  Future<List<String>> fetchVideoCategories() async {
    fetchCategoriesCalls++;
    return ['Hair Fall', 'Regrowth', 'Dandruff'];
  }
}

void main() {
  setUp(() {
    VideoRepositoryImpl.clearCache();
  });

  tearDown(() {
    VideoRepositoryImpl.clearCache();
  });

  group('VideoRepositoryImpl TTL Caching', () {
    test('getVideoCategories caches result and does not repeat remote fetch', () async {
      final remote = _CountingVideoRemoteDataSource();
      final repo = VideoRepositoryImpl(remoteDataSource: remote);

      final first = await repo.getVideoCategories();
      expect(first, ['Hair Fall', 'Regrowth', 'Dandruff']);
      expect(remote.fetchCategoriesCalls, 1);

      final second = await repo.getVideoCategories();
      expect(second, ['Hair Fall', 'Regrowth', 'Dandruff']);
      expect(remote.fetchCategoriesCalls, 1); // Hit cache
    });

    test('getVideos caches reels list for identical placement/category/page', () async {
      final remote = _CountingVideoRemoteDataSource();
      final repo = VideoRepositoryImpl(remoteDataSource: remote);

      final first = await repo.getVideos(category: 'Dandruff', page: 1);
      expect(first.items.length, 1);
      expect(remote.fetchVideosCalls, 1);

      // Same params hit cache
      final second = await repo.getVideos(category: 'Dandruff', page: 1);
      expect(second.items.length, 1);
      expect(remote.fetchVideosCalls, 1);

      // Different category triggers new remote call
      final third = await repo.getVideos(category: 'Regrowth', page: 1);
      expect(third.items.length, 1);
      expect(remote.fetchVideosCalls, 2);
    });
  });
}
