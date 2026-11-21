import 'dart:io';
import 'dart:typed_data';

import 'package:dr_hair/core/media/data/smart_image_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('drhair-upload-');
  });

  tearDown(() async {
    await tempDirectory.delete(recursive: true);
  });

  test(
    'keeps original bytes when the image codec cannot optimize them',
    () async {
      final source = File('${tempDirectory.path}/source.jpg');
      final sourceBytes = Uint8List.fromList([0xff, 0xd8, 0xff, 1, 2, 3]);
      await source.writeAsBytes(sourceBytes);
      final service = SmartImageUploadService(
        supportDirectoryProvider: () async => tempDirectory,
      );

      final prepared = await service.prepare(source.path);

      expect(prepared.optimized, isFalse);
      expect(prepared.originalBytes, sourceBytes.length);
      expect(prepared.uploadBytes, sourceBytes.length);
      expect(prepared.optimizationStatus, 'original_preserved');
      expect(prepared.uploadPath, prepared.originalPath);
      expect(await File(prepared.uploadPath).readAsBytes(), sourceBytes);
    },
  );

  test('uses a smaller optimized JPEG for picked image bytes', () async {
    final source = Uint8List.fromList([1, 2, 3, 4]);
    final prepared = await SmartImageUploadService(
      compressBytes: (bytes, maxDimension, quality) async {
        expect(maxDimension, SmartImageUploadService.defaultMaxDimension);
        expect(quality, SmartImageUploadService.defaultQuality);
        return Uint8List.fromList([0xff, 0xd8]);
      },
    ).prepareBytes(source, filename: 'avatar.png');
    expect(prepared.filename, 'avatar.jpg');
    expect(prepared.optimized, isTrue);
    expect(prepared.optimizationStatus, 'client_jpeg');
    expect(prepared.originalBytes, source.length);
    expect(prepared.uploadBytes, 2);
    expect(prepared.bytes, [0xff, 0xd8]);
  });

  test('preserves source bytes if compression is larger', () async {
    final source = Uint8List.fromList([1, 2, 3, 4]);
    final prepared = await SmartImageUploadService(
      compressBytes: (_, _, _) async => Uint8List.fromList([1, 2, 3, 4, 5]),
    ).prepareBytes(source, filename: 'avatar.png');

    expect(prepared.optimized, isFalse);
    expect(prepared.filename, 'avatar.png');
    expect(prepared.optimizationStatus, 'original_preserved');
    expect(prepared.bytes, source);
  });

  test('rejects files above the backend per-file limit', () async {
    final source = File('${tempDirectory.path}/oversized.jpg');
    await source
        .open(mode: FileMode.write)
        .then(
          (handle) => handle
              .setPosition(SmartImageUploadService.maxFileBytes + 1)
              .then((_) => handle.close()),
        );
    await expectLater(
      const SmartImageUploadService(supportDirectoryProvider: null)
          .prepare(source.path),
      throwsA(isA<FileSystemException>()),
    );
  });
}
