import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/routes/route_names.dart';
import '../../domain/models/home_action_card.dart';
import '../viewmodels/home_summary_cubit.dart';
import '../viewmodels/home_summary_state.dart';

class HomeActionCardsSection extends StatelessWidget {
  final HomeSummaryCubit? cubit;
  final Future<void> Function()? onRefresh;

  const HomeActionCardsSection({super.key, this.cubit, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final activeCubit = cubit ?? context.read<HomeSummaryCubit?>();
    if (activeCubit == null) {
      return const SizedBox.shrink();
    }

    return BlocBuilder<HomeSummaryCubit, HomeSummaryState>(
      bloc: activeCubit,
      builder: (context, state) {
        if (state.isLoading && !state.hasCards) {
          return _buildSkeletonPlaceholder(context);
        }

        if (!state.hasCards) {
          return const SizedBox.shrink();
        }

        final disableAnimations = MediaQuery.disableAnimationsOf(context);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...state.actionCards.map((card) {
                final cardWidget = Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _buildCardItem(context, card, state),
                );

                if (disableAnimations) {
                  return cardWidget;
                }

                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  child: cardWidget,
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSkeletonPlaceholder(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Skeletonizer(
        enabled: true,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primary5,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 160,
                          height: 16,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 100,
                          height: 12,
                          color: Colors.grey.shade200,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                height: 12,
                color: Colors.grey.shade200,
              ),
              const SizedBox(height: 14),
              Container(
                width: 120,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardItem(
    BuildContext context,
    HomeActionCard card,
    HomeSummaryState state,
  ) {
    if (card.isClinicianUrgent) {
      return _buildClinicianUrgentCard(context, card);
    } else if (card.isPendingAssessment) {
      return _buildPendingAssessmentCard(context, card);
    } else if (card.isPendingAppointment) {
      return _buildPendingAppointmentCard(context, card);
    } else if (card.isSharedReport) {
      return _buildSharedReportCard(context, card, state);
    } else if (card.isCarePlan) {
      return _buildCarePlanCard(context, card);
    } else if (card.isProductSuggestions) {
      return _buildProductSuggestionsCard(context, card);
    } else if (card.isAppointmentSuggestion) {
      return _buildAppointmentSuggestionCard(context, card);
    }
    return _buildGenericActionCard(context, card);
  }

  Widget _buildClinicianUrgentCard(BuildContext context, HomeActionCard card) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2), // subtle rose
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFFECDD3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0AE11D48),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE4E6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  LucideIcons.stethoscope,
                  color: Color(0xFFE11D48),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF881337),
                      ),
                    ),
                    if (card.whyShown != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        card.whyShown!,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFBE123C),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            card.body,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: Color(0xFF4C0519),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: ElevatedButton.icon(
              onPressed: () {
                final route = card.destinationRoute ?? RouteNames.clinicAppointment;
                context.push(route);
              },
              icon: const Icon(LucideIcons.calendarDays, size: 15),
              label: Text(
                card.actionLabel,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE11D48),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingAssessmentCard(BuildContext context, HomeActionCard card) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB), // amber
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  LucideIcons.clipboardList,
                  color: Color(0xFFD97706),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF78350F),
                      ),
                    ),
                    if (card.whyShown != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        card.whyShown!,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            card.body,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: Color(0xFF451A03),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: ElevatedButton.icon(
              onPressed: () => context.push(RouteNames.hairTest),
              icon: const Icon(LucideIcons.arrowRight, size: 15),
              label: Text(
                card.actionLabel,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingAppointmentCard(BuildContext context, HomeActionCard card) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primary100),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060D1B2A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary5,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  LucideIcons.calendarClock,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    if (card.whyShown != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        card.whyShown!,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            card.body,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: AppColors.secondaryDark,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: ElevatedButton.icon(
              onPressed: () => context.push(RouteNames.clinicAppointment),
              icon: const Icon(LucideIcons.arrowRight, size: 15),
              label: Text(
                card.actionLabel,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSharedReportCard(
    BuildContext context,
    HomeActionCard card,
    HomeSummaryState state,
  ) {
    final isOpening = state.openingReportId == card.entityId;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4), // light emerald / teal
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFBBF7D0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A059669),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  LucideIcons.fileCheck2,
                  color: Color(0xFF059669),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF064E3B),
                      ),
                    ),
                    if (card.whyShown != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        card.whyShown!,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            card.body,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: Color(0xFF065F46),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                height: 36,
                child: ElevatedButton.icon(
                  onPressed: isOpening
                      ? null
                      : () async {
                          final reportId = card.entityId;
                          if (reportId == null || reportId.isEmpty) {
                            context.push(RouteNames.treatmentDetails);
                            return;
                          }
                          final cubit = context.read<HomeSummaryCubit>();
                          final uri = await cubit.getReportDownloadUri(reportId);
                          if (uri != null) {
                            final launched = await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                            if (!launched && context.mounted) {
                              context.push(RouteNames.treatmentDetails);
                            }
                          } else if (context.mounted) {
                            context.push(RouteNames.treatmentDetails);
                          }
                        },
                  icon: isOpening
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(LucideIcons.download, size: 15),
                  label: Text(
                    isOpening ? 'Opening…' : card.actionLabel,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => context.push(RouteNames.treatmentDetails),
                child: const Text(
                  'View in records',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF059669),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCarePlanCard(BuildContext context, HomeActionCard card) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF9), // teal / mint
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF99F6E4)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0D9488),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFCCFBF1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  LucideIcons.pill,
                  color: Color(0xFF0D9488),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF134E4A),
                      ),
                    ),
                    if (card.whyShown != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        card.whyShown!,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0D9488),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            card.body,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: Color(0xFF115E59),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: ElevatedButton.icon(
              onPressed: () => context.push(RouteNames.treatmentDetails),
              icon: const Icon(LucideIcons.arrowRight, size: 15),
              label: Text(
                card.actionLabel,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductSuggestionsCard(BuildContext context, HomeActionCard card) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primary100),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060D1B2A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary5,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  LucideIcons.sparkles,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    if (card.whyShown != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        card.whyShown!,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            card.body,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: AppColors.secondaryDark,
            ),
          ),
          if (card.products.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: card.products.length,
                separatorBuilder: (context, index) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final prod = card.products[index];
                  final name = prod['name']?.toString() ?? 'Product';
                  final price = prod['price'];
                  final prodId = prod['id']?.toString() ?? '';

                  return InkWell(
                    onTap: () {
                      if (prodId.isNotEmpty) {
                        context.push(RouteNames.productPath(prodId));
                      } else {
                        context.push(RouteNames.products);
                      }
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 150,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary5,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.primary100),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            price != null ? '₹$price' : 'In Stock',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: ElevatedButton.icon(
              onPressed: () => context.push(RouteNames.products),
              icon: const Icon(LucideIcons.shoppingBag, size: 15),
              label: Text(
                card.actionLabel,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentSuggestionCard(BuildContext context, HomeActionCard card) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primary100),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060D1B2A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary5,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  LucideIcons.calendar,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    if (card.whyShown != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        card.whyShown!,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            card.body,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: AppColors.secondaryDark,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: ElevatedButton.icon(
              onPressed: () => context.push(RouteNames.clinicAppointment),
              icon: const Icon(LucideIcons.calendarDays, size: 15),
              label: Text(
                card.actionLabel,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenericActionCard(BuildContext context, HomeActionCard card) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primary100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            card.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            card.body,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: AppColors.secondaryDark,
            ),
          ),
          const SizedBox(height: 12),
          if (card.destinationRoute != null)
            SizedBox(
              height: 36,
              child: ElevatedButton(
                onPressed: () => context.push(card.destinationRoute!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(
                  card.actionLabel,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
