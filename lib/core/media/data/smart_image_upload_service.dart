import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class PreparedUploadImage {
  const PreparedUploadImage({
    required this.originalPath,
    required this.uploadPath,
    required this.originalBytes,
    required this.uploadBytes,
    required this.optimized,
    required this.optimizationStatus,
  });

  final String originalPath;
  final String uploadPath;
  final int originalBytes;
  final int uploadBytes;
  final bool optimized;
  final String optimizationStatus;
}

typedef SmartImageCompressor = Future<Uint8List?> Function(
  String path, {
  required int quality,
  required int maxDimension,
});

/// Keeps a durable app-private original and builds a smaller upload copy when
/// the source is large enough to justify decoding and re-encoding it.
class SmartImageUploadService {
  const SmartImageUploadService({
    this.compressor,
    this.supportDirectoryProvider,
  });

  @visibleForTesting
  final SmartImageCompressor? compressor;
  @visibleForTesting
  final Future<Directory> Function()? supportDirectoryProvider;

  static const int maxFileBytes = 25 * 1024 * 1024;
  static const int maxSourceFileBytes = 100 * 1024 * 1024;
  static const int optimizeAboveBytes = 1536 * 1024;
  static const int targetUploadBytes = 2 * 1024 * 1024;
  static const int maxDimension = 2560;

  Future<PreparedUploadImage> prepare(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const FileSystemException(
        'The selected image is no longer available.',
      );
    }
    final sourceBytes = await source.length();
    if (sourceBytes <= 0) {
      throw const FileSystemException('The selected image is empty.');
    }
    if (sourceBytes > maxSourceFileBytes) {
      throw const FileSystemException(
        'This image is larger than the 100 MiB preparation limit. Choose a smaller image.',
      );
    }
    final sourceExceedsUploadLimit = sourceBytes > maxFileBytes;

    final support =
        await (supportDirectoryProvider?.call() ??
            getApplicationSupportDirectory());
    final uploadDirectory = Directory('${support.path}/drhair_uploads');
    await uploadDirectory.create(recursive: true);
    final id = _randomId();
    final extension = _safeExtension(sourcePath);
    final originalPath = '${uploadDirectory.path}/$id.original$extension';
    await source.copy(originalPath);

    final lowerExtension = extension.toLowerCase();
    final isAnimatedGif = lowerExtension == '.gif';
    final alreadyWebp = lowerExtension == '.webp';
    if (isAnimatedGif && sourceExceedsUploadLimit) {
      throw const FileSystemException(
        'Animated images larger than 25 MiB cannot be uploaded. Choose a smaller image.',
      );
    }
    if (isAnimatedGif && !sourceExceedsUploadLimit) {
      return PreparedUploadImage(
        originalPath: originalPath,
        uploadPath: originalPath,
        originalBytes: sourceBytes,
        uploadBytes: sourceBytes,
        optimized: false,
        optimizationStatus: isAnimatedGif
            ? 'animation_preserved'
            : 'already_optimized',
      );
    }

    if (alreadyWebp && sourceBytes <= targetUploadBytes) {
      return PreparedUploadImage(
        originalPath: originalPath,
        uploadPath: originalPath,
        originalBytes: sourceBytes,
        uploadBytes: sourceBytes,
        optimized: false,
        optimizationStatus: 'already_optimized',
      );
    }

    if (!sourceExceedsUploadLimit &&
        sourceBytes <= optimizeAboveBytes &&
        lowerExtension != '.avif') {
      return PreparedUploadImage(
        originalPath: originalPath,
        uploadPath: originalPath,
        originalBytes: sourceBytes,
        uploadBytes: sourceBytes,
        optimized: false,
        optimizationStatus: 'below_optimization_threshold',
      );
    }

    try {
      Uint8List? best;
      for (final settings in const [
        (quality: 88, dimension: maxDimension),
        (quality: 80, dimension: maxDimension),
        (quality: 76, dimension: 1920),
        (quality: 70, dimension: 1600),
        (quality: 64, dimension: 1280),
      ]) {
        final result =
            await (compressor?.call(
                  originalPath,
                  quality: settings.quality,
                  maxDimension: settings.dimension,
                ) ??
                FlutterImageCompress.compressWithFile(
                  originalPath,
                  minWidth: settings.dimension,
                  minHeight: settings.dimension,
                  quality: settings.quality,
                  format: CompressFormat.webp,
                  autoCorrectionAngle: true,
                  keepExif: false,
                ));
        if (result == null || result.isEmpty) continue;
        best = result;
        if (result.length <= targetUploadBytes) break;
      }

      if (best == null ||
          best.length > maxFileBytes ||
          (!sourceExceedsUploadLimit &&
              sourceBytes <= targetUploadBytes &&
              lowerExtension != '.avif' &&
              best.length >= sourceBytes * 0.9)) {
        if (sourceExceedsUploadLimit) {
          throw const FileSystemException(
            'This image could not be compressed below 25 MiB. Choose a smaller image.',
          );
        }
        return PreparedUploadImage(
          originalPath: originalPath,
          uploadPath: originalPath,
          originalBytes: sourceBytes,
          uploadBytes: sourceBytes,
          optimized: false,
          optimizationStatus: 'kept_original_no_size_saving',
        );
      }

      final optimizedPath = '${uploadDirectory.path}/$id.upload.webp';
      await File(optimizedPath).writeAsBytes(best, flush: true);
      return PreparedUploadImage(
        originalPath: originalPath,
        uploadPath: optimizedPath,
        originalBytes: sourceBytes,
        uploadBytes: best.length,
        optimized: true,
        optimizationStatus: 'webp_ready',
      );
    } on UnsupportedError {
      if (sourceExceedsUploadLimit) {
        throw const FileSystemException(
          'This image format could not be compressed below 25 MiB. Choose a smaller image.',
        );
      }
      return PreparedUploadImage(
        originalPath: originalPath,
        uploadPath: originalPath,
        originalBytes: sourceBytes,
        uploadBytes: sourceBytes,
        optimized: false,
        optimizationStatus: 'encoder_unavailable_original_preserved',
      );
    } catch (_) {
      if (sourceExceedsUploadLimit) {
        throw const FileSystemException(
          'This image could not be compressed below 25 MiB. Choose a smaller image.',
        );
      }
      return PreparedUploadImage(
        originalPath: originalPath,
        uploadPath: originalPath,
        originalBytes: sourceBytes,
        uploadBytes: sourceBytes,
        optimized: false,
        optimizationStatus: 'optimization_failed_original_preserved',
      );
    }
  }

  Future<void> deletePrepared(String originalPath, [String? uploadPath]) async {
    for (final path in {originalPath, ?uploadPath}) {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
  }

  static String _safeExtension(String path) {
    final name = path.split('/').last;
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return '.img';
    final extension = name.substring(dot).toLowerCase();
    return RegExp(r'^\.[a-z0-9]{1,8}$').hasMatch(extension)
        ? extension
        : '.img';
  }

  static String _randomId() {
    final random = Random.secure();
    return List<int>.generate(
      16,
      (_) => random.nextInt(256),
    ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  }
}
