import 'package:flutter_test/flutter_test.dart';
import 'package:dr_hair/core/constants/api_endpoints.dart';
import 'package:dr_hair/main.dart';

void main() {
  testWidgets('App renders Dr Hair smoke test', (WidgetTester tester) async {
    // Never let a local smoke test use URLs from the developer's .env file.
    ApiEndpoints.testOverride = 'http://127.0.0.1:1';
    addTearDown(() => ApiEndpoints.testOverride = null);
    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.byType(MyApp), findsOneWidget);
  });
}
