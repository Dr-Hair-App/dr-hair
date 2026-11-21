import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:material_ui/material_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:offline_document_viewer/offline_document_viewer.dart';
import 'package:path_provider/path_provider.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/apple_bottom_sheet.dart';
import '../../data/patient_clinical_api.dart';

Future<void> showClinicalReportViewer(
  BuildContext context, {
  required PatientClinicalApi api,
  required String accessToken,
  required String reportId,
  required String reportName,
  String? fileName,
  String? mimeType,
  Future<void> Function()? onViewed,
}) {
  final screenHeight = MediaQuery.sizeOf(context).height;
  final topInset = MediaQuery.paddingOf(context).top;
  final slideGap = (screenHeight * 0.025).clamp(16.0, 28.0).toDouble();
  final availableHeight = (screenHeight - topInset).clamp(1.0, screenHeight);
  final desiredTopGap = kToolbarHeight + 20 + slideGap;
  final heightFactor = (1 - desiredTopGap / availableHeight)
      .clamp(0.72, 0.90)
      .toDouble();
  return showAppleBottomSheet<void>(
    context,
    heightFactor: heightFactor,
    barrierColor: const Color(0x330A0A0A),
    builder: (sheetContext) => ClinicalReportViewerSheet(
      api: api,
      accessToken: accessToken,
      reportId: reportId,
      reportName: reportName,
      fileName: fileName,
      mimeType: mimeType,
      onViewed: onViewed,
    ),
  );
}

class ClinicalReportViewerSheet extends StatefulWidget {
  final PatientClinicalApi api;
  final String accessToken;
  final String reportId;
  final String reportName;
  final String? fileName;
  final String? mimeType;
  final Future<void> Function()? onViewed;

  const ClinicalReportViewerSheet({
    super.key,
    required this.api,
    required this.accessToken,
    required this.reportId,
    required this.reportName,
    this.fileName,
    this.mimeType,
    this.onViewed,
  });

  @override
  State<ClinicalReportViewerSheet> createState() =>
      _ClinicalReportViewerSheetState();
}

class _ClinicalReportViewerSheetState extends State<ClinicalReportViewerSheet> {
  PatientReportFile? _file;
  Object? _error;
  bool _loading = true;
  bool _markedViewed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadReport());
  }

  Future<void> _loadReport() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
        _file = null;
      });
    }
    try {
      final file = await widget.api.downloadReportFile(
        accessToken: widget.accessToken,
        reportId: widget.reportId,
        fileName: widget.fileName,
        mimeType: widget.mimeType,
      );
      final extension = file.fileName.split('.').last.toLowerCase();
      final needsPreviewConversion =
          {'heic', 'heif', 'avif'}.contains(extension) ||
          {'image/heic', 'image/heif', 'image/avif'}.contains(file.mimeType);
      final displayFile = needsPreviewConversion
          ? PatientReportFile(
              bytes: await FlutterImageCompress.compressWithList(
                file.bytes,
                minWidth: 2560,
                minHeight: 2560,
                quality: 95,
                format: CompressFormat.jpeg,
                keepExif: false,
              ),
              fileName:
                  '${file.fileName.replaceFirst(RegExp(r'\.[^.]+$'), '')}.jpg',
              mimeType: 'image/jpeg',
            )
          : file;
      if (displayFile.bytes.isEmpty) {
        throw const FormatException(
          'This image format could not be previewed.',
        );
      }
      if (!mounted) return;
      setState(() {
        _file = displayFile;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    final file = _file;
    if (file != null && !_isImage(file)) {
      unawaited(_removeTemporaryDocumentWorkspace(file));
    }
    super.dispose();
  }

  Future<void> _removeTemporaryDocumentWorkspace(PatientReportFile file) async {
    try {
      final extension = file.fileName.split('.').last.toLowerCase();
      final format = switch (extension) {
        'docm' => 'docx',
        'xlsm' => 'xlsx',
        'pptm' => 'pptx',
        'tsv' => 'csv',
        'pdf' => 'pdf',
        'doc' => 'doc',
        'docx' => 'docx',
        'xls' => 'xls',
        'xlsx' => 'xlsx',
        'ppt' => 'ppt',
        'pptx' => 'pptx',
        'txt' => 'txt',
        'rtf' => 'rtf',
        _ => null,
      };
      if (format == null) return;
      final hash = sha256.convert(file.bytes).toString().substring(0, 16);
      final cache = await getApplicationCacheDirectory();
      final workspaces = Directory('${cache.path}/odv_workspaces');
      if (!await workspaces.exists()) return;
      await for (final entity in workspaces.list()) {
        if (entity is Directory &&
            entity.uri.pathSegments.last.endsWith('_$hash')) {
          await entity.delete(recursive: true);
        }
      }
    } catch (_) {
      // Temporary report previews stay within the app's cache sandbox. If
      // cleanup is temporarily unavailable, the OS can still reclaim them.
    }
  }

  bool _isImage(PatientReportFile file) => file.mimeType.startsWith('image/');

  Future<void> _markViewed() async {
    if (_markedViewed) return;
    _markedViewed = true;
    await widget.onViewed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final file = _file;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF7F9FC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 12, 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 50,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                // const Spacer(),
                // IconButton(
                //   tooltip: 'Close report',
                //   onPressed: () => Navigator.of(context).maybePop(),
                //   icon: const Icon(LucideIcons.x, size: 19),
                //   color: AppColors.secondaryDark,
                // ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 2),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: ColoredBox(
                  color: Colors.white,
                  child: _loading
                      ? _buildLoading()
                      : _error != null
                      ? _buildError()
                      : file == null
                      ? _buildError()
                      : _buildDocument(file),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() => Skeletonizer(
    effect: const ShimmerEffect(
      baseColor: Color(0xFFE4EAF1),
      highlightColor: Color(0xFFF8FAFC),
      duration: Duration(milliseconds: 1250),
    ),
    child: SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _skeletonBone(width: 42, height: 42, radius: 13),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _skeletonBone(width: 155, height: 14),
                    const SizedBox(height: 8),
                    _skeletonBone(width: 95, height: 10),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _skeletonBone(width: 122, height: 10),
          const SizedBox(height: 10),
          _skeletonBone(width: double.infinity, height: 15),
          const SizedBox(height: 7),
          _skeletonBone(width: double.infinity, height: 15),
          const SizedBox(height: 7),
          _skeletonBone(width: 190, height: 15),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFEEF2F6)),
            ),
            child: Column(
              children: List.generate(
                4,
                (index) => Padding(
                  padding: EdgeInsets.only(bottom: index == 3 ? 0 : 13),
                  child: Row(
                    children: [
                      Expanded(child: _skeletonBone(height: 12)),
                      const SizedBox(width: 14),
                      _skeletonBone(width: 62, height: 12),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          _skeletonBone(width: 108, height: 10),
          const SizedBox(height: 12),
          _skeletonBone(width: double.infinity, height: 12),
          const SizedBox(height: 8),
          _skeletonBone(width: double.infinity, height: 12),
          const SizedBox(height: 8),
          _skeletonBone(width: 220, height: 12),
          const SizedBox(height: 22),
          _skeletonBone(width: 135, height: 10),
          const SizedBox(height: 12),
          _skeletonBone(width: double.infinity, height: 108, radius: 12),
          const SizedBox(height: 14),
          _skeletonBone(width: double.infinity, height: 108, radius: 12),
        ],
      ),
    ),
  );

  Widget _skeletonBone({
    double? width,
    required double height,
    double radius = 5,
  }) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
    ),
  );

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            LucideIcons.fileWarning,
            color: AppColors.secondaryDark,
            size: 34,
          ),
          const SizedBox(height: 12),
          const Text(
            'This report could not be opened.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.primaryDark,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _loadReport,
            icon: const Icon(LucideIcons.rotateCw, size: 16),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );

  Widget _buildDocument(PatientReportFile file) {
    if (file.mimeType.startsWith('image/')) {
      return InteractiveViewer(
        minScale: 0.7,
        maxScale: 5,
        boundaryMargin: const EdgeInsets.all(32),
        child: Center(
          child: Image.memory(
            file.bytes,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => _buildError(),
            frameBuilder: (context, child, frame, _) {
              if (frame != null) unawaited(_markViewed());
              return child;
            },
          ),
        ),
      );
    }

    final extension = file.fileName.split('.').last.toLowerCase();
    if (extension == 'txt') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_markViewed());
      });
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
        child: SelectableText(
          utf8.decode(file.bytes, allowMalformed: true),
          style: const TextStyle(
            color: AppColors.primaryDark,
            fontSize: 14,
            height: 1.6,
          ),
        ),
      );
    }
    final supportedExtensions = {
      'pdf',
      'doc',
      'docx',
      'docm',
      'xls',
      'xlsx',
      'xlsm',
      'csv',
      'tsv',
      'ppt',
      'pptx',
      'pptm',
      'rtf',
    };
    if (!supportedExtensions.contains(extension)) return _buildError();

    return DocumentView(
      source: DocumentSource.bytes(file.bytes, name: file.fileName),
      placeholderBuilder: (_) => _buildLoading(),
      errorBuilder: (_, _) => _buildError(),
      onReady: (_) => unawaited(_markViewed()),
      onFailure: (_) {},
    );
  }
}
