import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/dio_client.dart';

class PatientProgressApi {
  final Dio _dio;

  PatientProgressApi({Dio? dio})
    : _dio = dio ?? DioClient(baseUrl: ApiEndpoints.backendBaseUrl).dio;

  Future<void> createCheckIn({
    required String token,
    required String id,
    required DateTime date,
    required Map<String, String> photoPaths,
    required String scalpRegion,
    required String sheddingLevel,
    required String notes,
    required int densityRating,
  }) async {
    final formData = FormData();
    formData.fields.add(
      MapEntry(
        'payload',
        jsonEncode({
          'id': id,
          'date': date.toIso8601String(),
          'scalp_region': scalpRegion,
          'shedding_level': sheddingLevel,
          'notes': notes,
          'density_rating': densityRating,
        }),
      ),
    );
    for (final entry in photoPaths.entries) {
      formData.files.add(
        MapEntry(
          'photo_${entry.key}',
          await MultipartFile.fromFile(
            entry.value,
            filename: File(entry.value).uri.pathSegments.last,
          ),
        ),
      );
    }
    await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.patientProgressCheckins,
      data: formData,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  Future<List<Map<String, dynamic>>> listCheckIns({
    required String token,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.patientProgressCheckins,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final data = response.data?['data'];
    final items = data is Map ? data['items'] : null;
    if (items is! List) return [];
    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> deleteCheckIn({
    required String token,
    required String checkInId,
  }) async {
    await _dio.delete<Map<String, dynamic>>(
      ApiEndpoints.patientProgressCheckinById(checkInId),
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }
}
