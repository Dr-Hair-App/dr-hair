import 'dart:io';

import 'package:dr_hair/core/media/data/smart_image_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('image preparation safely keeps the source on codec failure', (
    _,
  ) async {
    final directory = await Directory.systemTemp.createTemp('drhair-source-');
    try {
      final source = File('${directory.path}/source.png');
      final bytes = List<int>.generate(8192, (index) => index % 256);
      await source.writeAsBytes(bytes);
      final prepared = await SmartImageUploadService(
        supportDirectoryProvider: () async => directory,
      ).prepare(source.path);

      expect(prepared.optimized, isFalse);
      expect(prepared.optimizationStatus, 'original_preserved');
      expect(prepared.uploadPath, prepared.originalPath);
      expect(await File(prepared.uploadPath).readAsBytes(), bytes);
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
