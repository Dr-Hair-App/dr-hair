import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../core/services/network_connection_service.dart';
import '../../../../core/storage/app_local_cache.dart';
import '../../../app_config/presentation/viewmodels/app_config_cubit.dart';
import '../../../auth/presentation/viewmodels/auth_cubit.dart';

class NoInternetView extends StatefulWidget {
  final NetworkConnectionService? networkService;

  const NoInternetView({super.key, this.networkService});

  @override
  State<NoInternetView> createState() => _NoInternetViewState();
}

class _NoInternetViewState extends State<NoInternetView> {
  bool _isChecking = false;

  NetworkConnectionService get _service =>
      widget.networkService ?? NetworkConnectionService.instance;

  Future<void> _handleRetry() async {
    if (_isChecking) return;
    setState(() => _isChecking = true);

    final isConnected = await _service.hasInternet();

    if (!mounted) return;

    if (isConnected) {
      // Re-trigger session & app config sync now that network is restored
      final authCubit = context.read<AuthCubit>();
      final appConfigCubit = context.read<AppConfigCubit?>();
      await Future.wait([
        authCubit.restoreSession(),
        if (appConfigCubit != null) appConfigCubit.loadConfig(),
      ]);

      if (!mounted) return;
      final authState = authCubit.state;

      if (authState.requiresProfileCompletion ||
          authState.nextStep == 'COMPLETE_PROFILE') {
        context.go(RouteNames.completeProfile);
      } else if (authState.isAuthenticated) {
        final cachedCompleted =
            AppLocalCache.instance.getBool('has_completed_hair_test') ?? false;
        final cachedSkipped =
            AppLocalCache.instance.getBool('has_skipped_hair_test') ?? false;
        if ((authState.nextStep == 'ASSESSMENT' ||
                (!authState.hasCompletedAssessment && !cachedCompleted)) &&
            !cachedSkipped) {
          context.go(RouteNames.hairTest);
        } else {
          context.go(RouteNames.mainShell);
        }
      } else {
        context.go(RouteNames.signin);
      }
    } else {
      setState(() => _isChecking = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Still offline. Please check your Wi-Fi or mobile data and try again.',
            ),
            backgroundColor: Color(0xFFDC2626),
            duration: Duration(seconds: 3),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Glowing Icon Badge
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFEE2E2),
                      width: 3,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1AE11D48),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      LucideIcons.wifiOff,
                      size: 42,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Title
                const Text(
                  'No Internet Connection',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 10),

                // Description
                const Text(
                  'We could not reach Dr. Hair clinic servers. Please verify your Wi-Fi or mobile data connection to continue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.secondaryDark,
                  ),
                ),
                const SizedBox(height: 28),

                // Connection Tips Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x061A365D),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildTipRow(
                        LucideIcons.wifi,
                        'Check that Wi-Fi or Mobile Data is turned on',
                      ),
                      const Divider(height: 20, color: AppColors.border),
                      _buildTipRow(
                        LucideIcons.plane,
                        'Ensure Airplane mode and VPN are disabled',
                      ),
                      const Divider(height: 20, color: AppColors.border),
                      _buildTipRow(
                        LucideIcons.refreshCw,
                        'Tap the button below once connected',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Retry Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isChecking ? null : _handleRetry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: _isChecking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(LucideIcons.refreshCw, size: 18),
                    label: Text(
                      _isChecking ? 'Checking connection…' : 'Retry Connection',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Fallback option to proceed to app anyway
                TextButton.icon(
                  onPressed: () {
                    final authState = context.read<AuthCubit>().state;
                    if (authState.isAuthenticated) {
                      context.go(RouteNames.mainShell);
                    } else {
                      context.go(RouteNames.signin);
                    }
                  },
                  icon: const Icon(LucideIcons.arrowRight, size: 16),
                  label: const Text('Continue to App anyway'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.secondaryDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTipRow(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.primary5,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryDark,
            ),
          ),
        ),
      ],
    );
  }
}
