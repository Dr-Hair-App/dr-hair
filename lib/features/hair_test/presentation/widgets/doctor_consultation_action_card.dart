import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/routes/route_names.dart';
import '../../../../core/widgets/app_button.dart';
import '../localization/assessment_translations.dart';

/// Callout card recommending an in-clinic consultation or doctor connect.
class DoctorConsultationActionCard extends StatelessWidget {
  final bool isHero;
  final String? reason;
  final AssessmentLanguage language;

  const DoctorConsultationActionCard({
    super.key,
    this.isHero = false,
    this.reason,
    this.language = AssessmentLanguage.english,
  });

  @override
  Widget build(BuildContext context) {
    final title = isHero
        ? AssessmentTranslations.t('in_person_consultation_recommended', language)
        : (language == AssessmentLanguage.hindi
            ? 'क्या आप क्लिनिक में परामर्श लेना पसंद करेंगे?'
            : (language == AssessmentLanguage.hinglish
                ? 'Kya aap clinic me doctor se milna chahenge?'
                : 'Prefer an In-Person Clinical Assessment?'));

    final subtitle = language == AssessmentLanguage.hindi
        ? 'क्लिनिक टीम से प्रत्यक्ष समीक्षा के लिए संपर्क करें'
        : (language == AssessmentLanguage.hinglish
            ? 'In-person checkup ke liye clinic team se connect karein'
            : 'Contact the clinic team for an in-person review');

    final bodyText = isHero
        ? (reason?.trim().isNotEmpty == true
            ? reason!.trim()
            : 'Your assessment suggests an in-person clinician review would be helpful. A clinician can assess the pattern and discuss suitable next steps with you.')
        : 'Get a comprehensive digital trichoscopy examination, clinical blood biomarker review, and doctor-prescribed customized treatment regimen at Dr. Hair OPD Clinic.';

    final buttonText = isHero
        ? 'Book In-Person Consultation (₹500)'
        : 'Book Consultation (₹500)';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isHero ? const Color(0xFF93C5FD) : const Color(0xFFBFDBFE),
          width: isHero ? 1.5 : 1.0,
        ),
        boxShadow: isHero
            ? [
                BoxShadow(
                  color: const Color(0xFF1D4ED8).withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isHero) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1D4ED8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.alertCircle, size: 12, color: Colors.white),
                  SizedBox(width: 5),
                  Text(
                    'Clinician review suggested',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  LucideIcons.stethoscope,
                  color: Color(0xFF1D4ED8),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            bodyText,
            style: const TextStyle(
              fontSize: 12,
              height: 1.45,
              color: Color(0xFF1E40AF),
            ),
          ),
          const SizedBox(height: 16),
          AppButton(
            height: 50,
            text: buttonText,
            variant: AppButtonVariant.filled,
            backgroundColor: const Color(0xFF1D4ED8),
            foregroundColor: Colors.white,
            icon: const Icon(
              LucideIcons.calendarCheck2,
              size: 16,
              color: Colors.white,
            ),
            onPressed: () => context.push(RouteNames.clinicAppointment),
          ),
        ],
      ),
    );
  }
}
