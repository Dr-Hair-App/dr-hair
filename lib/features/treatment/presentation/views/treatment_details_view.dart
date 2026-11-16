import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../core/utils/whatsapp_launcher.dart';
import '../../../auth/presentation/viewmodels/auth_cubit.dart';
import '../../data/patient_clinical_api.dart';

enum DocumentFormat { pdf, doc, image }

class ClinicalReportItem {
  final String id;
  final String title;
  final DocumentFormat format;
  final String fileName;
  final String fileSize;
  final String uploadedBy;
  final String uploadDate;
  final String uploaderRole;

  const ClinicalReportItem({
    required this.id,
    required this.title,
    required this.format,
    required this.fileName,
    required this.fileSize,
    required this.uploadedBy,
    required this.uploadDate,
    required this.uploaderRole,
  });
}

class PrescribedMedicine {
  final String catalogId;
  final String name;
  final String type;
  final String dosage;
  final String timing;
  final String duration;
  final String instructions;
  final IconData icon;

  const PrescribedMedicine({
    this.catalogId = '',
    required this.name,
    required this.type,
    required this.dosage,
    required this.timing,
    this.duration = '',
    required this.instructions,
    required this.icon,
  });
}

class TreatmentDetailsView extends StatefulWidget {
  final PatientClinicalApi? clinicalApi;
  const TreatmentDetailsView({super.key, this.clinicalApi});

  @override
  State<TreatmentDetailsView> createState() => _TreatmentDetailsViewState();
}

class _TreatmentDetailsViewState extends State<TreatmentDetailsView>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  String _selectedReportFilter = 'All';
  late final PatientClinicalApi _clinicalApi =
      widget.clinicalApi ?? PatientClinicalApi();

  List<ClinicalReportItem> _reports = [];
  List<PrescribedMedicine> _medicines = [];
  List<Map<String, dynamic>> _routineSteps = [];
  List<Map<String, dynamic>> _dietMeals = [];
  Map<String, dynamic>? _latestPlan;
  String? _accessToken;
  String? _recordError;
  String? _downloadingReportId;
  bool _loadingRecord = true;
  bool _didResolveSession = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didResolveSession) return;
    _didResolveSession = true;
    _checkAndLoadSession();
  }

  void _checkAndLoadSession() {
    final auth = context.read<AuthCubit?>()?.state;
    final token = auth?.sessionToken;
    if (token == null || token.isEmpty || auth?.isGuest == true) {
      setState(() {
        _loadingRecord = false;
        _recordError =
            'Sign in to view care plans and reports shared by your clinic.';
      });
      return;
    }
    _accessToken = token;
    unawaited(_loadClinicalRecord(token));
  }

  Future<void> _loadClinicalRecord(String token) async {
    setState(() {
      _loadingRecord = true;
      _recordError = null;
    });
    try {
      final record = await _clinicalApi.getClinicalRecord(token);
      final plans = _asMapList(record['care_plans']);
      final plan = plans.isEmpty ? null : plans.first;
      final medicineRows = _asMapList(plan?['medications']);
      final reports = _asMapList(record['reports'])
          .map((row) {
            final mime = row['mime_type']?.toString().toLowerCase() ?? '';
            final format = row['format']?.toString().toLowerCase() ?? '';
            final image =
                mime.startsWith('image/') ||
                ['jpg', 'jpeg', 'png', 'webp'].contains(format);
            return ClinicalReportItem(
              id: row['id']?.toString() ?? '',
              title: row['title']?.toString() ?? 'Clinical report',
              format: image ? DocumentFormat.image : DocumentFormat.pdf,
              fileName: row['file_name']?.toString() ?? 'report',
              fileSize: _formatBytes(row['bytes']),
              uploadedBy:
                  row['uploaded_by']?.toString().trim().isNotEmpty == true
                  ? row['uploaded_by'].toString()
                  : 'Dr. Jai Bansal',
              uploaderRole: 'Clinic',
              uploadDate: _formatDate(row['created_at']),
            );
          })
          .where((report) => report.id.isNotEmpty)
          .toList();

      if (!mounted) return;
      setState(() {
        _latestPlan = plan;
        _medicines = medicineRows.map((row) {
          final cat = (row['category']?.toString() ?? '').toLowerCase();
          final form = (row['form']?.toString() ?? '').toLowerCase();
          IconData icon = LucideIcons.pill;
          if (cat.contains('topical') ||
              form.contains('serum') ||
              form.contains('solution') ||
              form.contains('oil') ||
              form.contains('foam')) {
            icon = LucideIcons.droplets;
          } else if (cat.contains('shampoo') ||
              form.contains('shampoo') ||
              cat.contains('wash')) {
            icon = LucideIcons.sparkles;
          }

          return PrescribedMedicine(
            catalogId: row['catalog_id']?.toString() ?? '',
            name: row['name']?.toString() ?? '',
            type: [row['category'], row['form']]
                .whereType<String>()
                .where((value) => value.isNotEmpty)
                .join(' · '),
            dosage: row['dose']?.toString() ?? '',
            timing: row['frequency']?.toString() ?? '',
            duration: row['duration']?.toString() ?? '',
            instructions: row['instructions']?.toString() ?? '',
            icon: icon,
          );
        }).toList();
        _routineSteps = _asMapList(plan?['routine_steps']);
        _dietMeals = _asMapList(plan?['diet_meals']);
        _reports = reports;
        _loadingRecord = false;
        _recordError = null;
      });
      _animController.forward(from: 0.0);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingRecord = false;
        _recordError = 'Your clinic plan could not be loaded. Check your connection and try again.';
      });
    }
  }

  List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  String _formatBytes(dynamic value) {
    final bytes = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0;
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${bytes.toInt()} B';
  }

  String _formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return 'Date unavailable';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Future<void> _downloadReport(ClinicalReportItem report) async {
    final token = _accessToken;
    if (token == null) return;
    HapticFeedback.lightImpact();
    setState(() => _downloadingReportId = report.id);
    try {
      final uri = await _clinicalApi.getReportDownloadUri(
        accessToken: token,
        reportId: report.id,
      );
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) {
        throw StateError('The secure report link could not be opened.');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFF1E293B),
            content: Text('Could not open this report. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _downloadingReportId = null);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        title: const Text(
          'Medical Reports & Prescription',
          style: TextStyle(
            color: AppColors.primaryDark,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            LucideIcons.arrowLeft,
            color: AppColors.primaryDark,
            size: 20,
          ),
          onPressed: () => Navigator.maybePop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(
              LucideIcons.rotateCw,
              color: AppColors.secondary,
              size: 18,
            ),
            onPressed: () {
              final token = _accessToken;
              if (token != null) {
                HapticFeedback.selectionClick();
                unawaited(_loadClinicalRecord(token));
              }
            },
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(45),
          child: Container(
            height: 45,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.secondaryDark,
              labelStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.1,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(
                  iconMargin: EdgeInsets.zero,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.pill, size: 14),
                      SizedBox(width: 6),
                      Text(
                        'Prescription Details',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                ),
                Tab(
                  iconMargin: EdgeInsets.zero,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.fileText, size: 14),
                      SizedBox(width: 6),
                      Text(
                        'Medical Reports',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildPrescriptionTab(), _buildMedicalReportsTab()],
      ),
    );
  }

  // ==========================================
  // TAB 1: PRESCRIPTION DETAILS VIEW
  // ==========================================
  Widget _buildPrescriptionTab() {
    final plan = _latestPlan;

    if (_loadingRecord) {
      return _buildSkeletonLoader();
    }

    if (_recordError != null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _clinicalLoadMessage(
            _recordError!,
            isAuthPrompt: _recordError!.contains('Sign in'),
            onRetry: () {
              final token = _accessToken;
              if (token != null) {
                unawaited(_loadClinicalRecord(token));
              } else {
                context.push(RouteNames.signin);
              }
            },
          ),
        ),
      );
    }

    if (plan == null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _buildEmptyPlanState(),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        final token = _accessToken;
        if (token != null) await _loadClinicalRecord(token);
      },
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _buildCarePlanHeader(plan),
              const SizedBox(height: 20),
              _buildPrescriptionsHeader(),
              const SizedBox(height: 12),
              if (_medicines.isEmpty)
                _emptySectionCard('No medicines or products in this care plan.')
              else
                ..._medicines.map(_buildMedicineCard),
              if (_routineSteps.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildConnectedSectionCard(
                  icon: LucideIcons.calendarCheck,
                  title: 'Daily Care Routine',
                  subtitle:
                      '${_routineSteps.length} care steps scheduled by Dr. Jai Bansal',
                  actionLabel: 'Open Routine',
                  onTap: () => context.push(RouteNames.routine),
                ),
              ],
              if (_dietMeals.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildConnectedSectionCard(
                  icon: LucideIcons.heart,
                  title: 'Clinical Nutrition Plan',
                  subtitle:
                      '${_dietMeals.length} prescribed dietary meals & nutrient guidance',
                  actionLabel: 'Open Diet Plan',
                  onTap: () => context.push(RouteNames.dietPlan),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCarePlanHeader(Map<String, dynamic> plan) {
    final treatmentName =
        plan['treatment_name']?.toString() ?? 'Personalized care plan';
    final doctorName = (plan['doctor_name']?.toString() ?? '').isNotEmpty
        ? plan['doctor_name'].toString()
        : 'Dr. Jai Bansal';
    final diagnosis = plan['diagnosis']?.toString() ?? '';
    final stage = plan['stage']?.toString() ?? '';
    final duration = plan['duration']?.toString() ?? '';
    final nextReviewDate = plan['next_review_date']?.toString() ?? '';
    final instructions = plan['instructions']?.toString() ?? '';
    final refNo = plan['reference_no']?.toString() ?? '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Accent Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              gradient: AppColors.navyGradient,
              borderRadius: BorderRadius.vertical(top: Radius.circular(19)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    LucideIcons.stethoscope,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'YOUR CLINIC CARE PLAN',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Prepared by $doctorName',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (refNo.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '#$refNo',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  treatmentName,
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                if (diagnosis.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary5,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary100),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          LucideIcons.activity,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'CLINICIAN ASSESSMENT',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                diagnosis,
                                style: const TextStyle(
                                  color: AppColors.primaryDark,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (stage.isNotEmpty)
                      _metricPill(LucideIcons.gauge, 'Stage · $stage'),
                    if (duration.isNotEmpty)
                      _metricPill(LucideIcons.clock, 'Duration · $duration'),
                    if (nextReviewDate.isNotEmpty)
                      _metricPill(
                        LucideIcons.calendar,
                        'Review · ${_formatDate(nextReviewDate)}',
                        isHighlighted: true,
                      ),
                  ],
                ),
                if (instructions.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          LucideIcons.messageSquare,
                          size: 14,
                          color: AppColors.secondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            instructions,
                            style: const TextStyle(
                              color: AppColors.primaryDark,
                              fontSize: 11,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: const BorderSide(color: Color(0xFF25D366)),
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          WhatsAppLauncher.launch(
                            message:
                                'Hello Dr. Hair Clinic, I have a clinical question regarding my care plan ($treatmentName${refNo.isNotEmpty ? ' · Ref: $refNo' : ''}).',
                          );
                        },
                        icon: const Icon(
                          LucideIcons.messageCircle,
                          size: 15,
                          color: Color(0xFF25D366),
                        ),
                        label: const Text(
                          'Ask on WhatsApp',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F5132),
                          ),
                        ),
                      ),
                    ),
                    if (nextReviewDate.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            context.push(RouteNames.clinicAppointment);
                          },
                          icon: const Icon(
                            LucideIcons.calendarPlus,
                            size: 14,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Book Review',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricPill(IconData icon, String text, {bool isHighlighted = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isHighlighted ? AppColors.primary5 : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isHighlighted ? AppColors.primary100 : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: isHighlighted ? AppColors.primary : AppColors.secondaryDark,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: isHighlighted ? AppColors.primary : AppColors.primaryDark,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrescriptionsHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.primary5,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            LucideIcons.pill,
            color: AppColors.primary,
            size: 16,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Prescribed medicines & products',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
              letterSpacing: -0.2,
            ),
          ),
        ),
        if (_medicines.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primary5,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${_medicines.length} items',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMedicineCard(PrescribedMedicine med) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary5,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(med.icon, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      med.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      med.type.isNotEmpty
                          ? med.type
                          : 'Prescription Formulation',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.secondaryDark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (med.timing.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    med.timing,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (med.dosage.isNotEmpty)
                _badgeChip(LucideIcons.scale, 'Dose: ${med.dosage}'),
              if (med.duration.isNotEmpty)
                _badgeChip(LucideIcons.calendar, 'Duration: ${med.duration}'),
            ],
          ),
          if (med.instructions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    LucideIcons.info,
                    size: 13,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      med.instructions,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.secondaryDark,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (med.catalogId.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  side: const BorderSide(color: AppColors.primary),
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  context.push(RouteNames.productPath(med.catalogId));
                },
                icon: const Icon(
                  LucideIcons.shoppingBag,
                  size: 13,
                  color: AppColors.primary,
                ),
                label: const Text(
                  'Order from Clinic Shop',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _badgeChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: AppColors.secondaryDark),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedSectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary5,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.secondaryDark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary5,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    actionLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    LucideIcons.chevronRight,
                    size: 12,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 2: MEDICAL REPORTS & DOCUMENTS
  // ==========================================
  Widget _buildMedicalReportsTab() {
    if (_loadingRecord) {
      return _buildSkeletonLoader();
    }

    if (_recordError != null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _clinicalLoadMessage(
            _recordError!,
            isAuthPrompt: _recordError!.contains('Sign in'),
            onRetry: () {
              final token = _accessToken;
              if (token != null) {
                unawaited(_loadClinicalRecord(token));
              } else {
                context.push(RouteNames.signin);
              }
            },
          ),
        ),
      );
    }

    final filteredReports = _selectedReportFilter == 'All'
        ? _reports
        : _reports.where((r) {
            if (_selectedReportFilter == 'PDF') {
              return r.format == DocumentFormat.pdf;
            }
            if (_selectedReportFilter == 'Images') {
              return r.format == DocumentFormat.image;
            }
            if (_selectedReportFilter == 'Docs') {
              return r.format == DocumentFormat.doc;
            }
            return true;
          }).toList();

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        final token = _accessToken;
        if (token != null) await _loadClinicalRecord(token);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _buildReportsHeaderCard(),
          const SizedBox(height: 16),
          if (_reports.isNotEmpty) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', _reports.length),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'PDF',
                    _reports
                        .where((r) => r.format == DocumentFormat.pdf)
                        .length,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Images',
                    _reports
                        .where((r) => r.format == DocumentFormat.image)
                        .length,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Docs',
                    _reports
                        .where((r) => r.format == DocumentFormat.doc)
                        .length,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (filteredReports.isEmpty)
            _buildEmptyReportsState()
          else
            ...filteredReports.map(_buildReportCard),
        ],
      ),
    );
  }

  Widget _buildReportsHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              LucideIcons.shieldCheck,
              color: AppColors.secondary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reports shared by your clinic',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Private documents uploaded to your patient record. Download links are created securely when you open a report.',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.secondaryDark,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, int count) {
    final isSelected = _selectedReportFilter == label;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedReportFilter = label);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.secondaryDark,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : AppColors.primaryDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(ClinicalReportItem report) {
    final isDownloading = _downloadingReportId == report.id;
    final (icon, color, badge) = switch (report.format) {
      DocumentFormat.pdf => (
        LucideIcons.fileText,
        const Color(0xFFDC2626),
        'PDF',
      ),
      DocumentFormat.image => (LucideIcons.image, AppColors.secondary, 'IMAGE'),
      DocumentFormat.doc => (
        LucideIcons.fileText,
        const Color(0xFF2563EB),
        'DOCUMENT',
      ),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          color: color,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  report.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${report.fileName} · ${report.fileSize}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.secondaryDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Shared by ${report.uploadedBy} · ${report.uploadDate}',
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.secondaryDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Open secure report download',
            onPressed: isDownloading
                ? null
                : () => unawaited(_downloadReport(report)),
            icon: isDownloading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : const Icon(
                    LucideIcons.download,
                    size: 18,
                    color: AppColors.primary,
                  ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SHARED STATES & PLACEHOLDERS
  // ==========================================
  Widget _buildSkeletonLoader() {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          height: 180,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmerBar(width: 140, height: 12),
                const SizedBox(height: 12),
                _shimmerBar(width: 220, height: 18),
                const SizedBox(height: 16),
                _shimmerBar(width: double.infinity, height: 40),
                const Spacer(),
                Row(
                  children: [
                    _shimmerBar(width: 80, height: 24),
                    const SizedBox(width: 8),
                    _shimmerBar(width: 90, height: 24),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _shimmerBar(width: 180, height: 14),
        const SizedBox(height: 12),
        _skeletonCard(),
        const SizedBox(height: 10),
        _skeletonCard(),
      ],
    );
  }

  Widget _skeletonCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmerBar(width: 150, height: 12),
                const SizedBox(height: 6),
                _shimmerBar(width: 90, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _shimmerBar({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }

  Widget _emptySectionCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        message,
        style: const TextStyle(fontSize: 12, color: AppColors.secondaryDark),
      ),
    );
  }

  Widget _clinicalLoadMessage(
    String message, {
    bool isAuthPrompt = false,
    VoidCallback? onRetry,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary5,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isAuthPrompt ? LucideIcons.lock : LucideIcons.fileText,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              fontWeight: FontWeight.w600,
              color: AppColors.secondaryDark,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
              onPressed: onRetry,
              icon: Icon(
                isAuthPrompt ? LucideIcons.logIn : LucideIcons.rotateCw,
                size: 15,
              ),
              label: Text(
                isAuthPrompt ? 'Sign in to Continue' : 'Try again',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyPlanState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary5,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.stethoscope,
              color: AppColors.primary,
              size: 30,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'No Active Care Plan Yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your clinic has not shared a care plan yet. Prescriptions and care suggestions will appear here after your clinician adds them.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: AppColors.secondaryDark,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: const BorderSide(color: Color(0xFF25D366)),
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    WhatsAppLauncher.launch(
                      message: 'Hello Dr. Hair Clinic, I would like to consult about getting a clinical care plan.',
                    );
                  },
                  child: const Text(
                    'Chat on WhatsApp',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F5132),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    context.push(RouteNames.hairTest);
                  },
                  child: const Text(
                    'Take Hair Test',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyReportsState() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.folderOpen,
              color: AppColors.secondaryDark,
              size: 26,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'No reports have been shared with you yet.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Clinical documents, blood test analyses, or trichoscopy scans uploaded by the clinic will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              height: 1.4,
              color: AppColors.secondaryDark,
            ),
          ),
        ],
      ),
    );
  }
}
