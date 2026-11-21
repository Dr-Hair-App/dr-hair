import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_toast.dart';
import '../viewmodels/app_config_cubit.dart';
import '../viewmodels/app_config_state.dart';

class AppConfigUpdateGate extends StatefulWidget {
  final Widget child;

  const AppConfigUpdateGate({super.key, required this.child});

  @override
  State<AppConfigUpdateGate> createState() => _AppConfigUpdateGateState();
}

class _AppConfigUpdateGateState extends State<AppConfigUpdateGate> {
  String? _dismissedVersion;

  Future<void> _openStore(String? value) async {
    final uri = value == null ? null : Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https' || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        AppToast.showError(
          context,
          'The app store link is not available. Please try again later.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppConfigCubit, AppConfigState>(
      builder: (context, state) {
        final policy = state.versionCheck;
        final required = policy.updateRequired || policy.maintenanceMode;
        final showRecommended = policy.updateAvailable && !required && _dismissedVersion != policy.latestVersion;
        return Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            if (required)
              Positioned.fill(
                child: Material(
                  color: const Color(0xFFF6F8FB),
                  child: SafeArea(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(policy.maintenanceMode ? Icons.build_circle_outlined : Icons.system_update_alt_rounded, size: 42, color: const Color(0xFF17365D)),
                              const SizedBox(height: 20),
                              Text(policy.maintenanceMode ? 'We’ll be back shortly' : 'Update required', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700), textAlign: TextAlign.center),
                              const SizedBox(height: 10),
                              Text(policy.maintenanceMode ? (policy.maintenanceMessage ?? 'The app is temporarily unavailable while we make improvements.') : (policy.updateMessage ?? 'Install the latest version to continue.'), style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
                              if (!policy.maintenanceMode && policy.latestVersion != null) ...[
                                const SizedBox(height: 8),
                                Text('Version ${policy.latestVersion}', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: const Color(0xFF56708D))),
                              ],
                              if (!policy.maintenanceMode) ...[
                                const SizedBox(height: 24),
                                AppButton(
                                  height: 46,
                                  text: 'Update app',
                                  icon: const Icon(
                                    Icons.open_in_new_rounded,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                  variant: AppButtonVariant.filled,
                                  onPressed: () =>
                                      _openStore(policy.downloadUrl),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else if (showRecommended)
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: SafeArea(
                  top: false,
                  child: Material(
                    color: const Color(0xFF17365D),
                    elevation: 8,
                    borderRadius: BorderRadius.circular(18),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                      child: Row(
                        children: [
                          const Icon(Icons.system_update_alt_rounded, color: Colors.white),
                          const SizedBox(width: 12),
                          Expanded(child: Text(policy.updateMessage?.isNotEmpty == true ? policy.updateMessage! : 'Version ${policy.latestVersion ?? ''} is available.', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                          TextButton(onPressed: () => _openStore(policy.downloadUrl), child: const Text('Update', style: TextStyle(color: Color(0xFF85DED1)))),
                          IconButton(onPressed: () => setState(() => _dismissedVersion = policy.latestVersion), icon: const Icon(Icons.close_rounded, color: Colors.white70), tooltip: 'Dismiss update'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
