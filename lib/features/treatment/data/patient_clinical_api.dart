import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/dio_client.dart';

class PatientClinicalApi {
  final DioClient _client;

  PatientClinicalApi({DioClient? client})
    : _client =
          client ??
          DioClient(
            baseUrl: ApiEndpoints.backendBaseUrl,
            enableDebugLogging: true,
          );

  Future<Map<String, dynamic>> getClinicalRecord(String accessToken) async {
    final response = await _client.dio.get<Map<String, dynamic>>(
      ApiEndpoints.patientClinicalRecord,
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    final envelope = response.data;
    final data = envelope?['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException(
        'The patient clinical record response is invalid.',
      );
    }
    return data;
  }

  Future<Map<String, dynamic>> getHomeSummary(String accessToken) async {
    final response = await _client.dio.get<Map<String, dynamic>>(
      ApiEndpoints.patientHomeSummary,
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    final envelope = response.data;
    final data = envelope?['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException(
        'The patient home summary response is invalid.',
      );
    }
    return data;
  }

  Future<Uri> getReportDownloadUri({
    required String accessToken,
    required String reportId,
  }) async {
    final response = await _client.dio.get<Map<String, dynamic>>(
      ApiEndpoints.patientReportDownload(reportId),
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    final envelope = response.data;
    final data = envelope?['data'];
    final url = data is Map ? data['url'] : null;
    final uri = url is String ? Uri.tryParse(url) : null;
    if (uri == null || uri.scheme != 'https') {
      throw const FormatException('The report download link is invalid.');
    }
    return uri;
  }

  Future<List<Map<String, dynamic>>> getRoutineSteps(String accessToken) async {
    final response = await _client.dio.get<Map<String, dynamic>>(
      ApiEndpoints.patientRoutineSteps,
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    final data = response.data?['data'];
    final steps = data is Map ? data['routine_steps'] : null;
    if (steps is List) {
      return steps
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getCareEvents({
    required String accessToken,
    required DateTime from,
    required DateTime to,
  }) async {
    final response = await _client.dio.get<Map<String, dynamic>>(
      ApiEndpoints.patientCareEvents,
      queryParameters: {'from': _dateKey(from), 'to': _dateKey(to)},
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    final data = response.data?['data'];
    final items = data is Map ? data['items'] : null;
    if (items is! List) {
      throw const FormatException('The daily care event response is invalid.');
    }
    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> saveCareEvent({
    required String accessToken,
    required Map<String, dynamic> event,
  }) async {
    final response = await _client.dio.put<Map<String, dynamic>>(
      ApiEndpoints.patientCareEvents,
      data: event,
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    final data = response.data?['data'];
    if (data is! Map) {
      throw const FormatException('The daily care event response is invalid.');
    }
    return Map<String, dynamic>.from(data);
  }

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<List<Map<String, dynamic>>> addRoutineStep({
    required String accessToken,
    required String title,
    required String subtitle,
    required String category,
    required String timeOfDay,
  }) async {
    final response = await _client.dio.post<Map<String, dynamic>>(
      ApiEndpoints.patientRoutineSteps,
      data: {
        'title': title,
        'subtitle': subtitle,
        'category': category,
        'time_of_day': timeOfDay,
      },
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    final data = response.data?['data'];
    final steps = data is Map ? data['routine_steps'] : null;
    if (steps is List) {
      return steps
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> deleteRoutineStep({
    required String accessToken,
    required int stepIndex,
  }) async {
    final response = await _client.dio.delete<Map<String, dynamic>>(
      ApiEndpoints.patientRoutineStepByIndex(stepIndex),
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    final data = response.data?['data'];
    final steps = data is Map ? data['routine_steps'] : null;
    if (steps is List) {
      return steps
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getReminders(String accessToken) async {
    final response = await _client.dio.get<Map<String, dynamic>>(
      ApiEndpoints.patientReminders,
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    final data = response.data?['data'];
    final reminders = data is Map ? data['reminders'] : null;
    if (reminders is List) {
      return reminders
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> saveReminder({
    required String accessToken,
    required Map<String, dynamic> reminderData,
  }) async {
    final response = await _client.dio.post<Map<String, dynamic>>(
      ApiEndpoints.patientReminders,
      data: reminderData,
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    final data = response.data?['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    return {};
  }

  Future<bool> deleteReminder({
    required String accessToken,
    required String reminderId,
  }) async {
    final response = await _client.dio.delete<Map<String, dynamic>>(
      ApiEndpoints.patientReminderById(reminderId),
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    return response.statusCode == 200;
  }
}
