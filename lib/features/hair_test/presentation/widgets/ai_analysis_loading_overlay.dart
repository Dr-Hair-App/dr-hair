import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';

/// Full-screen animated AI analysis scanner overlay displayed during assessment submission.
class AiAnalysisLoadingOverlay extends StatefulWidget {
  const AiAnalysisLoadingOverlay({super.key});

  @override
  State<AiAnalysisLoadingOverlay> createState() => _AiAnalysisLoadingOverlayState();
}

class _AiAnalysisLoadingOverlayState extends State<AiAnalysisLoadingOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _stepTimer;
  int _currentStepIndex = 0;

  final List<Map<String, dynamic>> _steps = [
    {
      'title': 'Scanning Scalp & Hairline Density',
      'subtitle': 'Analyzing follicular patterns & sebum indicators...',
      'icon': LucideIcons.camera,
    },
    {
      'title': 'Evaluating Internal Biomarkers',
      'subtitle': 'Correlating DHT sensitivity, protein levels & stress triggers...',
      'icon': LucideIcons.activity,
    },
    {
      'title': 'Customizing Clinical Regimen',
      'subtitle': 'Formulating diet, lifestyle & targeted Dr. Hair recovery kit...',
      'icon': LucideIcons.sparkles,
    },
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _stepTimer = Timer.periodic(const Duration(milliseconds: 1300), (timer) {
      if (mounted) {
        setState(() {
          if (_currentStepIndex < _steps.length - 1) {
            _currentStepIndex++;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _stepTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentStep = _steps[_currentStepIndex];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Top Gemini Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDFA),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFCCFBF1)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.sparkles, color: AppColors.primary, size: 14),
                      SizedBox(width: 6),
                      Text(
                        'Dr. Hair Assistant • Gemini Flash',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 36),

                // Pulsing Holographic Scanner Icon
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F766E), Color(0xFF0284C7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F766E).withValues(alpha: 0.35),
                          blurRadius: 28,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        currentStep['icon'] as IconData,
                        color: Colors.white,
                        size: 42,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 36),

                // Animated Title & Subtitle
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  child: Column(
                    key: ValueKey<int>(_currentStepIndex),
                    children: [
                      Text(
                        currentStep['title'] as String,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        currentStep['subtitle'] as String,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // 3 Step Indicator Dots / Bars
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_steps.length, (index) {
                    final isDone = index <= _currentStepIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: isDone ? 28 : 8,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isDone ? AppColors.primary : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 24),

                const Text(
                  'Preparing your personalized recovery blueprint...',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
