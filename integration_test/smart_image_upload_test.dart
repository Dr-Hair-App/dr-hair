import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

import 'package:dr_hair/core/media/data/smart_image_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android native encoder creates a smaller WebP and preserves original',
    (_) async {
      final directory = await Directory.systemTemp.createTemp('drhair-codec-');
      try {
        final source = File('${directory.path}/synthetic.png');
        await source.writeAsBytes(_noisyPng(1024, 1024));
        final originalBytes = await source.length();
        expect(
          originalBytes,
          greaterThan(SmartImageUploadService.optimizeAboveBytes),
        );

        final result = await SmartImageUploadService(
          supportDirectoryProvider: () async => directory,
        ).prepare(source.path);

        expect(result.optimized, isTrue, reason: result.optimizationStatus);
        expect(result.uploadPath, endsWith('.webp'));
        expect(result.uploadBytes, lessThan(originalBytes));
        expect(await File(result.originalPath).length(), originalBytes);
        final webpPrefix = await File(result.uploadPath)
            .openRead(0, 12)
            .fold<List<int>>(<int>[], (bytes, chunk) => bytes..addAll(chunk));
        expect(ascii.decode(webpPrefix.sublist(0, 4)), 'RIFF');
        expect(ascii.decode(webpPrefix.sublist(8, 12)), 'WEBP');
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );
}

Uint8List _noisyPng(int width, int height) {
  final raw = Uint8List(height * (width * 4 + 1));
  var state = 0x12345678;
  for (var y = 0; y < height; y++) {
    final row = y * (width * 4 + 1);
    raw[row] = 0;
    for (var x = 0; x < width * 4; x++) {
      state = (1664525 * state + 1013904223) & 0xffffffff;
      raw[row + x + 1] = state >> 24;
    }
  }
  final compressed = ZLibEncoder().convert(raw);
  final header = BytesBuilder()
    ..add([137, 80, 78, 71, 13, 10, 26, 10])
    ..add(_pngChunk('IHDR', _u32(width) + _u32(height) + [8, 6, 0, 0, 0]))
    ..add(_pngChunk('IDAT', compressed))
    ..add(_pngChunk('IEND', const []));
  return header.toBytes();
}

List<int> _pngChunk(String name, List<int> data) {
  final type = ascii.encode(name);
  final checksum = _crc32(type + data);
  return _u32(data.length) + type + data + _u32(checksum);
}

List<int> _u32(int value) => [
  (value >> 24) & 0xff,
  (value >> 16) & 0xff,
  (value >> 8) & 0xff,
  value & 0xff,
];

int _crc32(List<int> bytes) {
  var crc = 0xffffffff;
  for (final byte in bytes) {
    crc ^= byte;
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc & 1) == 1 ? (crc >> 1) ^ 0xedb88320 : crc >> 1;
    }
  }
  return (crc ^ 0xffffffff) & 0xffffffff;
}
