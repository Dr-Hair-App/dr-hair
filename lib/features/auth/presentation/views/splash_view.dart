import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../core/storage/app_local_cache.dart';
import '../viewmodels/auth_cubit.dart';
import '../viewmodels/auth_state.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _glowAnimation;

  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    // Professional 3-second cinematic entrance and breathing animation
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              _onSplashComplete();
            }
          });

    // 1. Soft fade entrance over first 900ms (0.0 to 0.30)
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.30, curve: Curves.easeOutCubic),
    );

    // 2. Subtle upward float entrance over first 900ms
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.0, 0.30, curve: Curves.easeOutCubic),
          ),
        );

    // 3. Staged scale: entrance (0.90 -> 1.0), subtle living breath (1.0 -> 1.028 -> 1.0), and steady hold
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.90,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 35.0, // 0 - 1050ms
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.028,
        ).chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 30.0, // 1050 - 1950ms
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.028,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 25.0, // 1950 - 2700ms
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 10.0, // 2700 - 3000ms
      ),
    ]).animate(_controller);

    // 4. Ambient aura breathing glow
    _glowAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 0.8,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 35.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.8,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 30.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.6,
        ).chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 25.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.6,
          end: 0.5,
        ).chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 10.0,
      ),
    ]).animate(_controller);

    _controller.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSplashComplete() {
    if (!mounted || _hasNavigated) return;
    final authState = context.read<AuthCubit>().state;
    if (authState.status == AuthStatus.loading) {
      return;
    }
    if (authState.status == AuthStatus.failure) {
      _continueToSignIn();
      return;
    }
    _hasNavigated = true;
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
  }

  void _continueToSignIn() {
    if (!mounted || _hasNavigated) return;
    _hasNavigated = true;
    context.go(RouteNames.signin);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (!_hasNavigated) {
          if (state.status == AuthStatus.failure) {
            _continueToSignIn();
          } else if (state.status != AuthStatus.loading) {
            // If the 3-second splash animation has finished, navigate immediately
            if (_controller.isCompleted) {
              _onSplashComplete();
            }
          }
        }
      },
      child: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, authState) => Scaffold(
          body: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: authState.status == AuthStatus.failure
                ? null
                : _onSplashComplete,
            child: Stack(
              children: [
                // 1. Serene Clinical Background Gradient
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFFFFFFF),
                          Color(0xFFF8FAFC),
                          Color(0xFFEFF6F7),
                        ],
                      ),
                    ),
                  ),
                ),

                // 2. Pure, Minimal Centered Emblem and Branding
                SafeArea(
                  child: Center(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: ScaleTransition(
                          scale: _scaleAnimation,
                          child: AnimatedBuilder(
                            animation: _glowAnimation,
                            builder: (context, child) {
                              return Container(
                                width: 180,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.10 * _glowAnimation.value,
                                      ),
                                      blurRadius: 36,
                                      spreadRadius: 4,
                                    ),
                                  ],
                                ),
                                child: child,
                              );
                            },
                            child: Image.asset(
                              'assets/images/icon.png',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Center(
                                    child: Text(
                                      'DH',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 32,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                              width: 180,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // 3. Error Retry Card (if session restore fails)
                if (authState.status == AuthStatus.failure)
                  Positioned.fill(
                    child: ColoredBox(
                      color: const Color(0xFFF8FAFC).withValues(alpha: 0.94),
                      child: SafeArea(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 420),
                              child: Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: AppColors.border),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.08,
                                      ),
                                      blurRadius: 28,
                                      offset: const Offset(0, 12),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      LucideIcons.wifi,
                                      color: AppColors.secondaryDark,
                                      size: 28,
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Could not restore your session',
                                      style: TextStyle(
                                        color: AppColors.primaryDark,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      authState.errorMessage ?? 'Check your connection and try again.',
                                      style: const TextStyle(
                                        color: AppColors.secondaryDark,
                                        height: 1.45,
                                      ),
                                    ),
                                    const SizedBox(height: 22),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: context
                                            .read<AuthCubit>()
                                            .restoreSession,
                                        icon: const Icon(LucideIcons.rotateCw),
                                        label: const Text('Try again'),
                                      ),
                                    ),
                                    Align(
                                      alignment: Alignment.center,
                                      child: TextButton(
                                        onPressed: _continueToSignIn,
                                        child: const Text('Sign in with phone'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
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
