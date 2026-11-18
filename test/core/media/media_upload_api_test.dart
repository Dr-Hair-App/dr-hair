import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dr_hair/core/media/data/media_upload_api.dart';

void main() {
  test(
    'rejects a file over the backend 25 MiB limit before making a request',
    () async {
      final api = MediaUploadApi(dio: Dio());
      final file = MultipartFile.fromBytes(
        List<int>.filled(25 * 1024 * 1024 + 1, 0),
        filename: 'too-large.png',
      );

      expect(
        () =>
            api.uploadFiles(token: 'token', purpose: 'profile', files: [file]),
        throwsArgumentError,
      );
    },
  );

  test('rejects more than ten files before making a request', () async {
    final api = MediaUploadApi(dio: Dio());
    final files = List.generate(
      11,
      (index) => MultipartFile.fromBytes([1], filename: '$index.png'),
    );

    expect(
      () => api.uploadFiles(token: 'token', purpose: 'progress', files: files),
      throwsArgumentError,
    );
  });

  test(
    'rejects combined uploads over the safe 89 MiB request budget',
    () async {
      final api = MediaUploadApi(dio: Dio());
      final files = List.generate(
        4,
        (index) => MultipartFile.fromStream(
          () => const Stream<List<int>>.empty(),
          23 * 1024 * 1024,
          filename: '$index.png',
        ),
      );

      expect(
        () => api.uploadFiles(
          token: 'token',
          purpose: 'assessment',
          files: files,
        ),
        throwsArgumentError,
      );
    },
  );
}
