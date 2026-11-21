import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_urls.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/custom_cached_image.dart';
import '../../../shop/data/models/product_model.dart';
import '../../domain/models/ai_assessment_model.dart';
import '../viewmodels/hair_test_state.dart';

/// Reusable recommendation card rendered in [AssessmentReportView].
/// Adheres strictly to clinical backend rules:
/// - Critical Case: ONLY displays appointment booking option with doctor guidance.
/// - Non-Critical Case (Products available & enabled): Recommends suitable active products.
/// - Non-Critical Case (Products unavailable or shop disabled): Offers direct doctor WhatsApp
///   consultation pre-filled with patient ID, admin panel link, name, and assessment summary.
class AssessmentRecommendationCard extends StatelessWidget {
  final HairTestState state;
  final AiAssessmentModel aiAssessment;
  final List<ProductItem> recommendedProducts;
  final VoidCallback onConnectWhatsApp;
  final ValueChanged<ProductItem>? onAddToCart;

  const AssessmentRecommendationCard({
    super.key,
    required this.state,
    required this.aiAssessment,
    required this.recommendedProducts,
    required this.onConnectWhatsApp,
    this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    final bool isCritical = aiAssessment.isCritical;
    final bool hasProducts =
        recommendedProducts.isNotEmpty && aiAssessment.shopEnabled;

    if (isCritical) {
      return _buildCriticalAppointmentOnlyCard(context);
    } else if (hasProducts) {
      return _buildProductsRecommendationCard(context);
    } else {
      return _buildWhatsAppDoctorCard(context);
    }
  }

  // ---------------------------------------------------------------------------
  // 1. CRITICAL CASE: ONLY APPOINTMENT BOOKING IS SHOWN
  // ---------------------------------------------------------------------------
  Widget _buildCriticalAppointmentOnlyCard(BuildContext context) {
    final reason = aiAssessment.nextStepReason.trim().isNotEmpty
        ? aiAssessment.nextStepReason.trim()
        : 'Your scalp symptoms or reported hair loss pattern require direct evaluation by a clinical trichologist.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB45309).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFFD97706),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.stethoscope,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Doctor Consultation Required',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF92400E),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'AI Clinical Priority Evaluation',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            reason,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: Color(0xFF78350F),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Row(
              children: [
                Icon(
                  LucideIcons.shieldAlert,
                  size: 16,
                  color: Color(0xFFD97706),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'To protect patient clinical safety, online product self-purchase is paused until a doctor evaluates your condition.',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          AppButton(
            height: 48,
            text: 'Book In-Clinic Consultation',
            variant: AppButtonVariant.filled,
            backgroundColor: const Color(0xFFD97706),
            foregroundColor: Colors.white,
            icon: const Icon(
              LucideIcons.calendarCheck,
              size: 18,
              color: Colors.white,
            ),
            onPressed: () => context.push(RouteNames.clinicAppointment),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. NON-CRITICAL: SUITABLE PRODUCTS RECOMMENDED
  // ---------------------------------------------------------------------------
  Widget _buildProductsRecommendationCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.sparkles,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Suitable Formulations',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      Text(
                        'Personalized for your scalp health score',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              TextButton(
                onPressed: () => context.push(RouteNames.products),
                child: const Text(
                  'Explore Shop',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...recommendedProducts
              .take(3)
              .map((product) => _buildProductItemRow(context, product)),
        ],
      ),
    );
  }

  Widget _buildProductItemRow(BuildContext context, ProductItem product) {
    final image = product.images.isNotEmpty ? product.images.first : '';
    final plan = product.supplyPlans.isNotEmpty
        ? product.supplyPlans.first
        : null;
    final price = plan?.price ?? 0;
    final mrp = plan?.mrp ?? price;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEF2F6)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 58,
              height: 58,
              child: image.isNotEmpty
                  ? CustomCachedImage(imageUrl: image, fit: BoxFit.cover)
                  : Container(
                      color: const Color(0xFFE2E8F0),
                      child: const Icon(
                        LucideIcons.package,
                        color: AppColors.textSecondary,
                        size: 24,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  product.category,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                if (plan == null)
                  const Text(
                    'View for price',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  )
                else
                  Row(
                    children: [
                      Text(
                        '₹$price',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      if (mrp > price) ...[
                        const SizedBox(width: 6),
                        Text(
                          '₹$mrp',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AppButton(
            height: 36,
            text: plan == null ? 'View' : 'Add',
            variant: AppButtonVariant.filled,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            borderRadius: BorderRadius.circular(10),
            onPressed: () {
              if (onAddToCart != null) {
                onAddToCart!(product);
              } else {
                context.push(RouteNames.productPath(product.id));
              }
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. NON-CRITICAL BUT PRODUCTS UNAVAILABLE: WHATSAPP DOCTOR CONNECT
  // ---------------------------------------------------------------------------
  Widget _buildWhatsAppDoctorCard(BuildContext context) {
    final patientId = (state.patientId?.trim().isNotEmpty == true)
        ? state.patientId!.trim()
        : (aiAssessment.patientCode?.trim().isNotEmpty == true
              ? aiAssessment.patientCode!.trim()
              : (aiAssessment.patientId?.trim().isNotEmpty == true
                    ? aiAssessment.patientId!.trim()
                    : (state.referenceNo ?? 'Patient')));
    final assessmentLink = AppUrls.assessmentUniversalLink(
      state.referenceNo ?? '',
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFBBF7D0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF15803D).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFF16A34A),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.messageCircle,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connect with Doctor on WhatsApp',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF14532D),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Instant trichology guidance & product advice',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF166534),
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
            aiAssessment.productAvailabilityStatus == 'unavailable'
                ? 'We couldn’t confirm current stock, so no products are being suggested. You can contact the clinic for guidance.'
                : 'No matching in-stock products are available right now. Your care steps remain available above.',
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: Color(0xFF166534),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDCFCE7)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      LucideIcons.smartphone,
                      size: 14,
                      color: Color(0xFF16A34A),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'App Assessment Link: $assessmentLink',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF15803D),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Patient ID: $patientId  •  Ref: ${state.referenceNo ?? "N/A"}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF4B5563),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppButton(
            height: 46,
            text: 'Contact doctor on WhatsApp',
            variant: AppButtonVariant.filled,
            backgroundColor: const Color(0xFF16A34A),
            foregroundColor: Colors.white,
            icon: const Icon(
              LucideIcons.messageCircle,
              size: 18,
              color: Colors.white,
            ),
            onPressed: onConnectWhatsApp,
          ),
        ],
      ),
    );
  }
}
