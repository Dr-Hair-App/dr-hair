import 'package:dio/dio.dart';

import '../../constants/api_endpoints.dart';
import '../../network/dio_client.dart';

/// Shared client for the single authenticated media upload endpoint.
/// Feature APIs should persist the returned asset metadata with their own data.
class MediaUploadApi {
  final Dio _dio;

  MediaUploadApi({Dio? dio})
    : _dio = dio ?? DioClient(baseUrl: ApiEndpoints.backendBaseUrl).dio;

  Future<List<Map<String, dynamic>>> uploadFiles({
    required String token,
    required String purpose,
    required List<MultipartFile> files,
    ProgressCallback? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    if (files.isEmpty || files.length > 10) {
      throw ArgumentError.value(
        files.length,
        'files',
        'Upload between 1 and 10 files.',
      );
    }
    final oversized = files.indexWhere(
      (file) => file.length > 25 * 1024 * 1024,
    );
    if (oversized >= 0) {
      throw ArgumentError.value(
        files[oversized].length,
        'files[$oversized]',
        'Each upload must be 25 MiB or smaller.',
      );
    }
    final totalBytes = files.fold<int>(0, (total, file) => total + file.length);
    if (totalBytes > 89 * 1024 * 1024) {
      throw ArgumentError.value(
        totalBytes,
        'files',
        'The combined upload must be 89 MiB or smaller to leave room for multipart data.',
      );
    }

    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.mediaUpload,
      data: FormData.fromMap({'files': files}),
      options: Options(
        headers: {'Authorization': 'Bearer $token', 'X-Media-Purpose': purpose},
      ),
      onSendProgress: onSendProgress,
      cancelToken: cancelToken,
    );

    final data = response.data?['data'];
    final items = data is Map ? data['items'] : null;
    if (items is! List || items.length != files.length) {
      throw const FormatException('Media upload response is invalid.');
    }
    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
}
