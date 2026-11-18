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

  test('keeps the source and creates a smaller WebP upload copy', () async {
    final source = File('${tempDirectory.path}/source.jpg');
    await source.writeAsBytes(List<int>.filled(2 * 1024 * 1024, 7));
    final service = SmartImageUploadService(
      supportDirectoryProvider: () async => tempDirectory,
      compressor: (path, {required quality, required maxDimension}) async =>
          Uint8List(256 * 1024),
    );

    final prepared = await service.prepare(source.path);

    expect(prepared.optimized, isTrue);
    expect(prepared.originalBytes, 2 * 1024 * 1024);
    expect(prepared.uploadBytes, 256 * 1024);
    expect(prepared.uploadPath, endsWith('.webp'));
    expect(await File(prepared.originalPath).length(), 2 * 1024 * 1024);
    expect(await File(prepared.uploadPath).length(), 256 * 1024);
  });

  test('does not re-encode a small image', () async {
    final source = File('${tempDirectory.path}/small.jpg');
    await source.writeAsBytes([1, 2, 3]);
    var compressionCalls = 0;
    final service = SmartImageUploadService(
      supportDirectoryProvider: () async => tempDirectory,
      compressor: (path, {required quality, required maxDimension}) async {
        compressionCalls++;
        return Uint8List(1);
      },
    );

    final prepared = await service.prepare(source.path);

    expect(prepared.optimized, isFalse);
    expect(prepared.uploadPath, prepared.originalPath);
    expect(prepared.optimizationStatus, 'below_optimization_threshold');
    expect(compressionCalls, 0);
  });

  test('creates a WebP fallback for AVIF previews while preserving the AVIF original', () async {
    final source = File('${tempDirectory.path}/small.avif');
    await source.writeAsBytes(List<int>.filled(32, 7));
    final service = SmartImageUploadService(
      supportDirectoryProvider: () async => tempDirectory,
      compressor: (path, {required quality, required maxDimension}) async =>
          Uint8List(64),
    );

    final prepared = await service.prepare(source.path);

    expect(prepared.optimized, isTrue);
    expect(prepared.optimizationStatus, 'webp_ready');
    expect(prepared.originalPath, endsWith('.avif'));
    expect(prepared.uploadPath, endsWith('.webp'));
    expect(await File(prepared.originalPath).length(), 32);
    expect(await File(prepared.uploadPath).length(), 64);
  });

  test('recompresses an oversized WebP into the verifier 2 MiB cap', () async {
    final source = File('${tempDirectory.path}/camera.webp');
    await source.writeAsBytes(List<int>.filled(3 * 1024 * 1024, 7));
    var compressionCalls = 0;
    final service = SmartImageUploadService(
      supportDirectoryProvider: () async => tempDirectory,
      compressor: (path, {required quality, required maxDimension}) async {
        compressionCalls++;
        return Uint8List(1900 * 1024);
      },
    );

    final prepared = await service.prepare(source.path);

    expect(compressionCalls, 1);
    expect(prepared.optimized, isTrue);
    expect(prepared.originalPath, endsWith('.webp'));
    expect(prepared.uploadPath, endsWith('.webp'));
    expect(prepared.uploadBytes, lessThanOrEqualTo(2 * 1024 * 1024));
    expect(await File(prepared.originalPath).length(), 3 * 1024 * 1024);
  });

  test('compresses an oversized source into an uploadable derivative and retains the original', () async {
    final source = File('${tempDirectory.path}/large-camera.jpg');
    final bytes = List<int>.filled(26 * 1024 * 1024, 7);
    bytes.setRange(0, 4, [0xff, 0xd8, 0xff, 0xd9]);
    await source.writeAsBytes(bytes, flush: true);
    final service = SmartImageUploadService(
      supportDirectoryProvider: () async => tempDirectory,
      compressor: (path, {required quality, required maxDimension}) async =>
          Uint8List(512 * 1024),
    );

    final prepared = await service.prepare(source.path);

    expect(prepared.optimized, isTrue);
    expect(prepared.originalBytes, 26 * 1024 * 1024);
    expect(prepared.uploadBytes, 512 * 1024);
    expect(prepared.uploadPath, endsWith('.webp'));
    expect(await File(prepared.originalPath).length(), 26 * 1024 * 1024);
    expect(
      prepared.uploadBytes,
      lessThanOrEqualTo(SmartImageUploadService.maxFileBytes),
    );
  });

  test('refuses an oversized source if compression cannot get it under the upload cap', () async {
    final source = File('${tempDirectory.path}/uncompressible.jpg');
    final bytes = List<int>.filled(26 * 1024 * 1024, 7);
    bytes.setRange(0, 4, [0xff, 0xd8, 0xff, 0xd9]);
    await source.writeAsBytes(bytes, flush: true);
    final service = SmartImageUploadService(
      supportDirectoryProvider: () async => tempDirectory,
      compressor: (path, {required quality, required maxDimension}) async =>
          null,
    );

    await expectLater(
      service.prepare(source.path),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('preserves GIF animation without conversion', () async {
    final source = File('${tempDirectory.path}/animation.gif');
    await source.writeAsBytes(List<int>.filled(2 * 1024 * 1024, 7));
    var compressionCalls = 0;
    final service = SmartImageUploadService(
      supportDirectoryProvider: () async => tempDirectory,
      compressor: (path, {required quality, required maxDimension}) async {
        compressionCalls++;
        return Uint8List(1);
      },
    );

    final prepared = await service.prepare(source.path);

    expect(prepared.optimizationStatus, 'animation_preserved');
    expect(prepared.uploadPath, prepared.originalPath);
    expect(compressionCalls, 0);
  });

  test('rejects files larger than exactly 25 MiB', () async {
    final source = File('${tempDirectory.path}/oversized.jpg');
    await source
        .open(mode: FileMode.write)
        .then(
          (handle) => handle
              .setPosition(SmartImageUploadService.maxFileBytes + 1)
              .then((_) => handle.close()),
        );
    final service = SmartImageUploadService(
      supportDirectoryProvider: () async => tempDirectory,
    );

    await expectLater(
      service.prepare(source.path),
      throwsA(isA<FileSystemException>()),
    );
  });
}
