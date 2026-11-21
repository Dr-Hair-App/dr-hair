import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';

class AuthRemoteDataSource {
  final Dio _dio;

  AuthRemoteDataSource({Dio? dio})
    : _dio = dio ?? DioClient(baseUrl: ApiEndpoints.backendBaseUrl).dio;

  Future<Map<String, dynamic>> requestOtp(String login) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.authSendLoginOtp,
      data: {'login': login},
      options: Options(extra: const {'sensitive': true}),
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> verifyOtp({
    required String login,
    required String otp,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.authVerifyLoginOtp,
      data: {'login': login, 'otp': otp},
      options: Options(extra: const {'sensitive': true}),
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> loginWithPassword({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.authLogin,
      data: {'email': email.trim().toLowerCase(), 'password': password},
      options: Options(extra: const {'sensitive': true}),
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> sendSignupOtp(
    String phone, {
    String? tempToken,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.authSendSignupOtp,
      data: {
        'phone': phone.trim(),
        if (tempToken != null && tempToken.isNotEmpty) 'tempToken': tempToken,
      },
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> registerWithPassword({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String otp,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.authRegister,
      data: {
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        'password': password,
        'phone': phone.trim(),
        'otp': otp.trim(),
      },
      options: Options(extra: const {'sensitive': true}),
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> socialLogin({
    required String provider,
    required String idToken,
    String? email,
    String? name,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.authSocialLogin,
      data: {
        'provider': provider,
        'id_token': idToken,
        'email': ?(email?.trim().toLowerCase()),
        'name': ?name?.trim(),
      },
      options: Options(extra: const {'sensitive': true}),
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> verifySocialSignup({
    required String phone,
    required String otp,
    required String tempToken,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.authVerifySocialSignup,
      data: {
        'phone': phone.trim(),
        'otp': otp.trim(),
        'temp_token': tempToken.trim(),
      },
      options: Options(extra: const {'sensitive': true}),
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> forgotPassword(String login) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.authForgotPassword,
      data: {'login': login.trim()},
      options: Options(extra: const {'sensitive': true}),
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> resetPassword({
    required String login,
    required String otp,
    required String newPassword,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.authResetPassword,
      data: {
        'login': login.trim(),
        'otp': otp.trim(),
        'newPassword': newPassword,
      },
      options: Options(extra: const {'sensitive': true}),
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> getProfile(String token) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.userGetProfile,
      options: _authorized(token),
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> getSession(String token) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.authSession,
      options: _authorized(token, silent: true),
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> refreshSession({
    required String refreshToken,
    required String sessionId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.authRefresh,
      data: {'refresh_token': refreshToken, 'session_id': sessionId},
      options: Options(extra: const {'sensitive': true, 'silent': true}),
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> register({
    required String token,
    required String verifiedLogin,
    required String name,
    int? age,
    String? gender,
    String? city,
    String? occupation,
  }) async {
    final login = verifiedLogin.trim();
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.userLoginSignup,
      data: {
        'name': name,
        if (login.contains('@')) 'email': login,
        if (!login.contains('@')) 'phone': login,
        'age': ?age,
        'gender': ?(gender?.isNotEmpty == true ? gender : null),
        'city': ?(city?.isNotEmpty == true ? city : null),
        'occupation': ?(occupation?.isNotEmpty == true ? occupation : null),
        'platform': 'app',
      },
      options: _authorized(token),
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> updateProfile({
    required String token,
    String? name,
    int? age,
    bool clearAge = false,
    String? gender,
    String? city,
    String? occupation,
    String? profileUrl,
    bool clearProfileUrl = false,
    List<int>? profilePhotoBytes,
    String? profilePhotoFilename,
  }) async {
    final payload = <String, dynamic>{
      'name': ?name,
      'age': ?age,
      if (clearAge) 'age': null,
      'gender': ?gender,
      'city': ?city,
      'occupation': ?occupation,
      'profile_url': ?profileUrl,
      if (clearProfileUrl) 'profile_url': null,
    };
    final photoBytes = profilePhotoBytes;
    final photoFilename = profilePhotoFilename;
    final Object requestBody;
    if (photoBytes != null && photoFilename?.trim().isNotEmpty == true) {
      final formData = FormData()
        ..fields.add(MapEntry('payload', jsonEncode(payload)))
        ..files.add(
          MapEntry(
            'profile',
            MultipartFile.fromBytes(
              photoBytes,
              filename: photoFilename!.trim(),
            ),
          ),
        );
      requestBody = formData;
    } else {
      requestBody = payload;
    }
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.userUpdateProfile,
      data: requestBody,
      options: _authorized(token),
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> removeProfilePhoto(String token) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.userUpdateProfile,
      data: {'profile_url': null},
      options: _authorized(token),
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> deleteAccount(String token) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.userDeleteAccount,
      options: _authorized(token),
    );
    return _asMap(response.data);
  }

  Future<void> logout(String token, {String? fcmToken}) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.authLogout,
        data: fcmToken != null && fcmToken.isNotEmpty
            ? {'fcm_token': fcmToken}
            : null,
        options: _authorized(token, silent: true),
      );
    } catch (_) {
      // Best-effort remote revocation; local session must still be cleared.
    }
  }

  Options _authorized(String token, {bool silent = false}) => Options(
    headers: {'Authorization': 'Bearer $token'},
    extra: {'sensitive': true, if (silent) 'silent': true},
  );

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }
}
