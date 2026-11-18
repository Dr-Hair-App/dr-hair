import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/whatsapp_launcher.dart';

/// Branded, full-screen waiting state while the assessment pathway is prepared.
class AiAnalysisLoadingOverlay extends StatefulWidget {
  const AiAnalysisLoadingOverlay({super.key, this.uploadProgress});

  final double? uploadProgress;

  @override
  State<AiAnalysisLoadingOverlay> createState() =>
      _AiAnalysisLoadingOverlayState();
}

class _AiAnalysisLoadingOverlayState extends State<AiAnalysisLoadingOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _motionController;
  late final AnimationController _dotsController;
  Timer? _longWaitTimer;
  bool _reduceMotion = false;
  bool _takingLonger = false;

  @override
  void initState() {
    super.initState();
    _motionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    )..repeat();
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    )..repeat();
    _longWaitTimer = Timer(const Duration(seconds: 25), () {
      if (mounted) {
        setState(() => _takingLonger = true);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion == _reduceMotion) return;
    _reduceMotion = reduceMotion;
    if (reduceMotion) {
      _motionController.stop();
      _dotsController.stop();
    } else {
      _motionController.repeat();
      _dotsController.repeat();
    }
  }

  @override
  void dispose() {
    _longWaitTimer?.cancel();
    _motionController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  Future<void> _contactClinic() async {
    final success = await WhatsAppLauncher.launch(
      message:
          'Hello Dr. Hair Clinical Support, my assessment is taking longer than usual to prepare. Could you please assist me?\n• Portal: https://drhairindia.com',
    );
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open WhatsApp. Please retry.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uploaded =
        widget.uploadProgress != null && widget.uploadProgress! >= 1;
    final uploading = widget.uploadProgress != null && !uploaded;
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF9),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: CustomPaint(painter: _SoftBackdropPainter()),
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: const Color(0xFFDCECE8),
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x0C0F766E),
                                    blurRadius: 18,
                                    offset: Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    LucideIcons.sparkles,
                                    color: AppColors.primary,
                                    size: 15,
                                  ),
                                  SizedBox(width: 7),
                                  Text(
                                    'Dr. Hair Assistant',
                                    style: TextStyle(
                                      color: AppColors.primaryDark,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 22),
                            AnimatedBuilder(
                              animation: _motionController,
                              builder: (context, child) => CustomPaint(
                                size: const Size.square(224),
                                painter: _CarePathPainter(
                                  progress: _reduceMotion
                                      ? 0.18
                                      : _motionController.value,
                                ),
                                child: SizedBox.square(
                                  dimension: 224,
                                  child: Center(
                                    child: Container(
                                      width: 76,
                                      height: 76,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primary.withValues(
                                              alpha: 0.12,
                                            ),
                                            blurRadius: 24,
                                            spreadRadius: 4,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        LucideIcons.heartPulse,
                                        color: AppColors.primary,
                                        size: 34,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              uploading
                                  ? 'Uploading your assessment'
                                  : uploaded
                                  ? 'Photos uploaded — checking your scalp and preparing your result'
                                  : 'Putting your care pathway together',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF163A36),
                                fontSize: 21,
                                height: 1.2,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              uploading
                                  ? 'Your photos and answers are being sent securely. Keep the app open while we prepare your result.'
                                  : 'We’re reviewing your answers and photos to prepare useful care guidance and a suitable next step.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF667C78),
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Container(
                              constraints: const BoxConstraints(maxWidth: 360),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.88),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFE4EEEB),
                                ),
                              ),
                              child: Row(
                                children: [
                                  if (uploading)
                                    const Icon(
                                      LucideIcons.upload,
                                      size: 17,
                                      color: AppColors.primary,
                                    )
                                  else if (_reduceMotion)
                                    const Icon(
                                      LucideIcons.clock3,
                                      size: 17,
                                      color: AppColors.primary,
                                    )
                                  else
                                    const SizedBox.square(
                                      dimension: 17,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      uploading
                                          ? 'Uploading ${(widget.uploadProgress! * 100).round()}%'
                                          : uploaded
                                          ? 'Checking your scalp and preparing your result'
                                          : 'Reviewing your answers and preparing next steps',
                                      style: const TextStyle(
                                        color: Color(0xFF31534E),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            _DancingDots(
                              animation: _dotsController,
                              reduceMotion: _reduceMotion,
                              label: uploading ? 'Uploading assessment' : 'Checking scalp photos and preparing result',
                            ),
                            if (_takingLonger &&
                                widget.uploadProgress == null) ...[
                              const SizedBox(height: 14),
                              const Text(
                                'This is taking longer than usual.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFF667C78),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _contactClinic,
                                icon: const Icon(
                                  LucideIcons.messageCircle,
                                  size: 16,
                                ),
                                label: const Text('Contact the clinic'),
                              ),
                            ],
                            const SizedBox(height: 15),
                            const Text(
                              'Your result will appear as soon as it’s ready.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF8A9B98),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DancingDots extends StatelessWidget {
  const _DancingDots({
    required this.animation,
    required this.reduceMotion,
    required this.label,
  });

  final Animation<double> animation;
  final bool reduceMotion;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    liveRegion: true,
    child: ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (index) {
          final dot = Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          );
          if (reduceMotion) return dot;
          final phase = CurvedAnimation(
            parent: animation,
            curve: Interval(
              index * 0.19,
              0.58 + index * 0.12,
              curve: Curves.easeInOut,
            ),
          );
          return AnimatedBuilder(
            animation: phase,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, -5 * phase.value),
              child: Transform.scale(
                scale: 0.8 + 0.2 * phase.value,
                child: child,
              ),
            ),
            child: dot,
          );
        }),
      ),
    ),
  );
}

class _SoftBackdropPainter extends CustomPainter {
  const _SoftBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    paint.color = const Color(0xFFDAEEE8).withValues(alpha: 0.55);
    canvas.drawCircle(
      Offset(size.width * 0.04, size.height * 0.13),
      118,
      paint,
    );
    paint.color = const Color(0xFFE0EDF7).withValues(alpha: 0.48);
    canvas.drawCircle(
      Offset(size.width * 1.02, size.height * 0.84),
      150,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _SoftBackdropPainter oldDelegate) => false;
}

class _CarePathPainter extends CustomPainter {
  const _CarePathPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final rotation = progress * math.pi * 2;
    final outer = Rect.fromCircle(center: center, radius: 99);
    final middle = Rect.fromCircle(center: center, radius: 82);

    canvas.drawCircle(
      center,
      104,
      Paint()..color = const Color(0xFFDBECE7).withValues(alpha: 0.48),
    );
    canvas.drawCircle(
      center,
      91,
      Paint()
        ..color = const Color(0xFFD9E9E5).withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawCircle(
      center,
      72,
      Paint()
        ..color = const Color(0xFFE3EFEC)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    canvas.drawArc(
      outer,
      rotation,
      math.pi * 0.82,
      false,
      Paint()
        ..color = const Color(0xFF128477)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 3.5,
    );
    canvas.drawArc(
      middle,
      -rotation * 0.65 + math.pi,
      math.pi * 0.48,
      false,
      Paint()
        ..color = const Color(0xFF58A7C4).withValues(alpha: 0.78)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2.5,
    );

    for (var index = 0; index < 3; index++) {
      final angle = rotation + index * (math.pi * 2 / 3);
      final point = Offset(
        center.dx + math.cos(angle) * 99,
        center.dy + math.sin(angle) * 99,
      );
      canvas.drawCircle(
        point,
        index == 0 ? 5 : 3.5,
        Paint()..color = index == 0 ? const Color(0xFF128477) : Colors.white,
      );
      canvas.drawCircle(
        point,
        index == 0 ? 5 : 3.5,
        Paint()
          ..color = const Color(0xFF128477).withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }

    final follicle = Path()
      ..moveTo(center.dx - 10, center.dy + 19)
      ..cubicTo(
        center.dx - 9,
        center.dy + 35,
        center.dx - 5,
        center.dy + 47,
        center.dx,
        center.dy + 49,
      )
      ..cubicTo(
        center.dx + 5,
        center.dy + 47,
        center.dx + 9,
        center.dy + 35,
        center.dx + 10,
        center.dy + 19,
      )
      ..close();
    canvas.drawPath(
      follicle,
      Paint()..color = const Color(0xFFB6DED3).withValues(alpha: 0.82),
    );

    final strandPaint = Paint()
      ..color = const Color(0xFF16786E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round;
    for (var index = -1; index <= 1; index++) {
      final strand = Path()
        ..moveTo(center.dx + index * 5, center.dy + 22)
        ..cubicTo(
          center.dx + index * 8,
          center.dy + 4,
          center.dx + index * 4 - 4,
          center.dy - 8,
          center.dx + index * 7 - 3,
          center.dy - 22,
        );
      canvas.drawPath(strand, strandPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CarePathPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
