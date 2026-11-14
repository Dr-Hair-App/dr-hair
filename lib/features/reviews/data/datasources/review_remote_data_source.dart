import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../models/review_model.dart';

class ReviewRemoteDataSource {
  final Dio _dio;

  ReviewRemoteDataSource({Dio? dio})
    : _dio = dio ?? DioClient(baseUrl: ApiEndpoints.backendBaseUrl).dio;

  Future<List<ReviewModel>> getReviews({String? category, int? page}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.reviewsGet,
      queryParameters: {
        if (category != null && category != 'All') 'category': category,
        'page': ?page,
      },
      options: Options(extra: const {'silent': true}),
    );

    final data = response.data?['data'];
    final rawList = data is List
        ? data
        : data is Map && data['items'] is List
        ? data['items'] as List
        : null;

    if (rawList == null) {
      throw const FormatException('Review response is invalid.');
    }

    return rawList
        .whereType<Map<String, dynamic>>()
        .map(ReviewModel.fromJson)
        .where(
          (review) =>
              review.id.isNotEmpty &&
              review.name.trim().isNotEmpty &&
              review.rating > 0 &&
              review.comment.trim().isNotEmpty &&
              review.verified,
        )
        .toList();
  }
}
