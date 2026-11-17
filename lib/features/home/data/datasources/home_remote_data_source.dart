import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../models/service_model.dart';

abstract class HomeRemoteDataSource {
  Future<List<ServiceModel>> fetchServices();
}

class HomeRemoteDataSourceImpl implements HomeRemoteDataSource {
  final DioClient dioClient;

  HomeRemoteDataSourceImpl({required this.dioClient});

  @override
  Future<List<ServiceModel>> fetchServices() async {
    final response = await dioClient.dio.get(ApiEndpoints.services);
    final responseData = response.data;
    final services = responseData is List
        ? responseData
        : responseData is Map
        ? (responseData['data'] is List ? responseData['data'] as List : null)
        : null;
    if (response.statusCode == 200 && services != null) {
      return services
          .map((item) => ServiceModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    throw const FormatException('The services response was not a list.');
  }
}
