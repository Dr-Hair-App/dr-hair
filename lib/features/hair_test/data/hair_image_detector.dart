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
    String? sessionToken,
    Dio? dioClient,
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
      final dio =
          dioClient ??
          DioClient(
            baseUrl: ApiEndpoints.backendBaseUrl,
            enableDebugLogging: false,
          ).dio;
      final headers = <String, String>{};
      final token = sessionToken?.trim();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
      final response = await dio.post<Map<String, dynamic>>(
        ApiEndpoints.hairTestDetectScalpImage,
        data: FormData.fromMap({
          'label': label,
          'image': await MultipartFile.fromFile(
            path,
            filename: path.split('/').last,
          ),
        }),
        options: Options(
          headers: headers,
          connectTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 35),
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
    } on DioException catch (error) {
      return _unavailableResult(path, label, _failureMessage(error));
    } catch (_) {
      return _unavailableResult(
        path,
        label,
        'The verification service returned an unexpected response. Please retry.',
      );
    }

    return _unavailableResult(
      path,
      label,
      'The verification service returned an unexpected response. Please retry.',
    );
  }

  static HairPhotoAnalysis _unavailableResult(
    String path,
    String label,
    String message,
  ) => HairPhotoAnalysis(
    label: label,
    photoPath: path,
    status: HairDetectionStatus.verificationUnavailable,
    confidence: 0,
    message: message,
    details: 'The image verification service did not return a result.',
  );

  static String _failureMessage(DioException error) {
    final statusCode = error.response?.statusCode;
    if (statusCode == 401 || statusCode == 403) {
      return 'Your session may have expired. Sign in again, then retry the photo check.';
    }
    if (statusCode == 413) {
      return 'This photo is too large to check. Choose a smaller photo and retry.';
    }
    if (statusCode == 400 || statusCode == 415) {
      return 'This photo format could not be checked. Choose a JPEG, PNG, or WebP photo.';
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'The photo check took too long. Check your connection and retry.';
    }
    if (error.type == DioExceptionType.connectionError) {
      return 'Could not reach the photo verification service. Check your connection and retry.';
    }
    if (statusCode != null && statusCode >= 500) {
      return 'The photo verification service is temporarily unavailable. Please retry.';
    }
    return 'Could not verify this photo. Check your connection and retry.';
  }

  static String _messageFor(HairDetectionStatus status) => switch (status) {
    HairDetectionStatus.hairDetected => 'Scalp photo verified.',
    HairDetectionStatus.notHair =>
      'This photo does not show a scalp. Please choose another photo.',
    HairDetectionStatus.lowClarity =>
      'The photo is unclear. Try brighter light and a closer view.',
    HairDetectionStatus.analyzing => 'Checking your photo…',
    HairDetectionStatus.awaitingAssessment =>
      'Your photo will be reviewed with the assessment.',
    HairDetectionStatus.verificationUnavailable =>
      'Could not verify this photo. Please retry.',
  };
}
