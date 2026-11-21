import 'package:dr_hair/core/constants/api_endpoints.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Flutter tests route app API clients to the local hermetic base URL', () {
    final uri = Uri.parse(ApiEndpoints.backendBaseUrl);

    expect(uri.scheme, 'http');
    expect(uri.host, '127.0.0.1');
    expect(uri.port, 1);
  });
}
