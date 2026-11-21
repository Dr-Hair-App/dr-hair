import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

/// Image upload preparation shared by profile, progress, and assessment APIs.
///
/// Images are resized and re-encoded once on-device before they are attached to
/// their domain save request. If the native codec fails or produces a larger
/// image, the original bytes are kept so upload preparation never blocks a
/// valid image.
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

class PreparedUploadBytes {
  const PreparedUploadBytes({
    required this.bytes,
    required this.filename,
    required this.originalBytes,
    required this.uploadBytes,
    required this.optimized,
    required this.optimizationStatus,
  });

  final Uint8List bytes;
  final String filename;
  final int originalBytes;
  final int uploadBytes;
  final bool optimized;
  final String optimizationStatus;
}

class SmartImageUploadService {
  const SmartImageUploadService({
    this.supportDirectoryProvider,
    this.compressFile,
    this.compressBytes,
  });

  @visibleForTesting
  final Future<Directory> Function()? supportDirectoryProvider;

  @visibleForTesting
  final Future<Uint8List?> Function(String path, int maxDimension, int quality)?
  compressFile;

  @visibleForTesting
  final Future<Uint8List?> Function(
    Uint8List bytes,
    int maxDimension,
    int quality,
  )?
  compressBytes;

  static const int maxFileBytes = 25 * 1024 * 1024;
  static const int maxSourceBytes = 100 * 1024 * 1024;
  static const int defaultMaxDimension = 3072;
  static const int defaultQuality = 92;

  static String _extension(String path) {
    final basename = path.split(RegExp(r'[/\\]')).last;
    final dot = basename.lastIndexOf('.');
    return dot < 0 ? '' : basename.substring(dot);
  }

  static String _jpegFilename(String filename) {
    final basename = filename.split(RegExp(r'[/\\]')).last;
    final dot = basename.lastIndexOf('.');
    final stem = dot <= 0 ? basename : basename.substring(0, dot);
    return '$stem.jpg';
  }

  Future<PreparedUploadImage> prepare(
    String sourcePath, {
    int maxDimension = defaultMaxDimension,
    int quality = defaultQuality,
  }) async {
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
    if (sourceBytes > maxSourceBytes) {
      throw const FileSystemException(
        'This image is larger than 100 MiB. Choose a smaller image.',
      );
    }

    final support =
        await (supportDirectoryProvider?.call() ??
            getApplicationSupportDirectory());
    final uploadDirectory = Directory('${support.path}/drhair_uploads');
    await uploadDirectory.create(recursive: true);
    final sourceExtension = _extension(sourcePath);
    final extension = sourceExtension.isEmpty ? '.img' : sourceExtension;
    final stem = DateTime.now().microsecondsSinceEpoch.toString();
    final durablePath = '${uploadDirectory.path}/$stem.original$extension';
    await source.copy(durablePath);

    final Uint8List? candidate = await _compressFile(
      durablePath,
      maxDimension,
      quality,
    );
    if (candidate == null ||
        candidate.isEmpty ||
        candidate.length >= sourceBytes) {
      if (sourceBytes > maxFileBytes) {
        await File(durablePath).delete();
        throw const FileSystemException(
          'This image could not be reduced below the 25 MiB upload limit. Choose a smaller image.',
        );
      }
      return PreparedUploadImage(
        originalPath: durablePath,
        uploadPath: durablePath,
        originalBytes: sourceBytes,
        uploadBytes: sourceBytes,
        optimized: false,
        optimizationStatus: 'original_preserved',
      );
    }

    final optimizedPath = '${uploadDirectory.path}/$stem.upload.jpg';
    if (candidate.length > maxFileBytes) {
      await File(durablePath).delete();
      throw const FileSystemException(
        'This image remains larger than the 25 MiB upload limit after optimization. Choose a smaller image.',
      );
    }
    await File(optimizedPath).writeAsBytes(candidate, flush: true);
    return PreparedUploadImage(
      originalPath: durablePath,
      uploadPath: optimizedPath,
      originalBytes: sourceBytes,
      uploadBytes: candidate.length,
      optimized: true,
      optimizationStatus: 'client_jpeg',
    );
  }

  /// Shared byte-based entry point for profile and other in-memory uploads.
  Future<PreparedUploadBytes> prepareBytes(
    Uint8List sourceBytes, {
    required String filename,
    int maxDimension = defaultMaxDimension,
    int quality = defaultQuality,
  }) async {
    if (sourceBytes.isEmpty) {
      throw const FileSystemException('The selected image is empty.');
    }
    if (sourceBytes.length > maxSourceBytes) {
      throw const FileSystemException(
        'This image is larger than 100 MiB. Choose a smaller image.',
      );
    }
    final candidate = await _compressBytes(sourceBytes, maxDimension, quality);
    final useCandidate =
        candidate != null &&
        candidate.isNotEmpty &&
        candidate.length < sourceBytes.length;
    final uploadBytes = useCandidate ? candidate : sourceBytes;
    if (uploadBytes.length > maxFileBytes) {
      throw const FileSystemException(
        'This image could not be reduced below the 25 MiB upload limit. Choose a smaller image.',
      );
    }
    return PreparedUploadBytes(
      bytes: uploadBytes,
      filename: useCandidate ? _jpegFilename(filename) : filename,
      originalBytes: sourceBytes.length,
      uploadBytes: uploadBytes.length,
      optimized: useCandidate,
      optimizationStatus: useCandidate ? 'client_jpeg' : 'original_preserved',
    );
  }

  Future<Uint8List?> _compressFile(
    String path,
    int maxDimension,
    int quality,
  ) async {
    try {
      if (compressFile case final compressor?) {
        return await compressor(path, maxDimension, quality);
      }
      return await FlutterImageCompress.compressWithFile(
        path,
        minWidth: maxDimension,
        minHeight: maxDimension,
        quality: quality,
        format: CompressFormat.jpeg,
        autoCorrectionAngle: true,
      );
    } catch (_) {
      // Unsupported formats and native codec failures retain the source.
      return null;
    }
  }

  Future<Uint8List?> _compressBytes(
    Uint8List bytes,
    int maxDimension,
    int quality,
  ) async {
    try {
      if (compressBytes case final compressor?) {
        return await compressor(bytes, maxDimension, quality);
      }
      return await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: maxDimension,
        minHeight: maxDimension,
        quality: quality,
        format: CompressFormat.jpeg,
        autoCorrectionAngle: true,
      );
    } catch (_) {
      // Unsupported formats and native codec failures retain the source.
      return null;
    }
  }

  Future<void> deletePrepared(String originalPath, String? uploadPath) async {
    for (final path in {originalPath, ?uploadPath}) {
      if (!path.contains('/drhair_uploads/')) continue;
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }
}
