import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dr_hair/core/constants/api_endpoints.dart';
import 'package:dr_hair/features/hair_test/data/hair_image_detector.dart';
import 'package:dr_hair/features/hair_test/domain/models/hair_photo_analysis.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'posts the photo to the protected detector and parses its result',
    () async {
      final directory = await Directory.systemTemp.createTemp('hair-photo-');
      final image = File('${directory.path}/scalp.jpg');
      await image.writeAsBytes([0xFF, 0xD8, 0xFF, 0xD9]);
      final dio = Dio(BaseOptions(baseUrl: 'https://test.drhair.local'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.path, ApiEndpoints.hairTestDetectScalpImage);
            expect(
              options.headers['Authorization'],
              'Bearer synthetic-session-token',
            );
            expect(options.data, isA<FormData>());
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'message': 'ok',
                  'data': {
                    'is_hair': true,
                    'status': 'hairDetected',
                    'confidence': 0.97,
                    'message': 'Scalp verified.',
                    'details': 'Test response.',
                  },
                },
              ),
            );
          },
        ),
      );

      try {
        final result = await HairImageDetector.analyze(
          image.path,
          label: 'Crown / Top',
          sessionToken: 'synthetic-session-token',
          dioClient: dio,
        );

        expect(result.status, HairDetectionStatus.hairDetected);
        expect(result.confidence, 0.97);
        expect(result.message, 'Scalp verified.');
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'maps verifier service failures to unavailable without a false verdict',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'hair-photo-error-',
      );
      final image = File('${directory.path}/scalp.jpg');
      await image.writeAsBytes([0xFF, 0xD8, 0xFF, 0xD9]);
      final dio = Dio(BaseOptions(baseUrl: 'https://test.drhair.local'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.reject(
            DioException(
              requestOptions: options,
              response: Response(
                requestOptions: options,
                statusCode: 503,
                data: {'message': 'synthetic unavailable'},
              ),
              type: DioExceptionType.badResponse,
            ),
          ),
        ),
      );

      try {
        final result = await HairImageDetector.analyze(
          image.path,
          label: 'Front Hairline',
          sessionToken: 'synthetic-session-token',
          dioClient: dio,
        );
        expect(result.status, HairDetectionStatus.verificationUnavailable);
        expect(result.isHair, isFalse);
        expect(result.confidence, 0);
        expect(result.message, contains('temporarily unavailable'));
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );
}
