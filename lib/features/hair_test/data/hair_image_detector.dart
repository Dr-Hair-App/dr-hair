import 'dart:io';

import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../domain/models/hair_photo_analysis.dart';

/// Sends scalp photo verification to the authenticated backend AI endpoint.
class HairImageDetector {
  const HairImageDetector._();

  static Future<HairPhotoAnalysis> Function(String path, {String label})?
      analyzerOverride;

  static Future<HairPhotoAnalysis> analyze(
    String path, {
    String label = 'Scalp',
  }) async {
    if (analyzerOverride != null) {
      return analyzerOverride!(path, label: label);
    }

    final file = File(path);
    if (!await file.exists() || await file.length() == 0) {
      return HairPhotoAnalysis(
        label: label,
        photoPath: path,
        status: HairDetectionStatus.notHair,
        confidence: 0,
        message: 'Photo could not be opened. Please choose it again.',
        details: 'The selected file is missing or empty.',
      );
    }

    try {
      final dio = DioClient(
        baseUrl: ApiEndpoints.backendBaseUrl,
        enableDebugLogging: false,
      ).dio;
      final response = await dio.post<Map<String, dynamic>>(
        '/HairTest/detect_scalp_image',
        data: FormData.fromMap({
          'label': label,
          'image': await MultipartFile.fromFile(
            path,
            filename: path.split('/').last,
          ),
        }),
        options: Options(
          sendTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      final payload = response.data?['data'];
      if (payload is Map) {
        final status = switch (payload['status']?.toString()) {
          'hairDetected' => HairDetectionStatus.hairDetected,
          'notHair' => HairDetectionStatus.notHair,
          'lowClarity' => HairDetectionStatus.lowClarity,
          _ => HairDetectionStatus.verificationUnavailable,
        };
        final confidence = (payload['confidence'] as num?)?.toDouble() ?? 0;
        return HairPhotoAnalysis(
          label: label,
          photoPath: path,
          status: status,
          confidence: confidence.clamp(0, 1),
          message: payload['message']?.toString() ?? _messageFor(status),
          details: payload['details']?.toString() ?? '',
        );
      }
    } catch (_) {
      // A network/service failure is not evidence that the image is valid.
    }

    return HairPhotoAnalysis(
      label: label,
      photoPath: path,
      status: HairDetectionStatus.verificationUnavailable,
      confidence: 0,
      message: 'Could not verify this photo. Check your connection and retry.',
      details: 'The image verification service did not return a result.',
    );
  }

  static String _messageFor(HairDetectionStatus status) => switch (status) {
    HairDetectionStatus.hairDetected => 'Scalp photo verified.',
    HairDetectionStatus.notHair =>
      'This photo does not show a scalp. Please choose another photo.',
    HairDetectionStatus.lowClarity =>
      'The photo is unclear. Try brighter light and a closer view.',
    HairDetectionStatus.analyzing => 'Checking your photo…',
    HairDetectionStatus.verificationUnavailable =>
      'Could not verify this photo. Please retry.',
  };
}
