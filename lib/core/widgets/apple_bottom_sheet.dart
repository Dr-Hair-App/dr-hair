import 'package:material_ui/material_ui.dart';
import 'package:cupertino_ui/cupertino_ui.dart'
    show CupertinoPageTransitionsBuilder;

import '../constants/app_colors.dart';

/// Presents a bottom sheet with a coordinated, iOS-style background transition.
///
/// Add [appleSheetPageTransitionsTheme] to the app's [ThemeData] to animate the
/// route behind the sheet. Call this helper for other sheets to reuse the same
/// scale, corner, and dimming treatment.
Future<T?> showAppleBottomSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool useSafeArea = true,
  bool isDismissible = true,
  bool enableDrag = true,
  bool useRootNavigator = true,
  double? heightFactor,
  Color barrierColor = const Color(0x330A0A0A),
}) async {
  var motionReleased = false;
  void releaseMotion() {
    if (motionReleased) return;
    motionReleased = true;
    AppleSheetMotion.end();
  }

  AppleSheetMotion.begin();
  try {
    return await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      useSafeArea: useSafeArea,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      useRootNavigator: useRootNavigator,
      backgroundColor: Colors.transparent,
      barrierColor: barrierColor,
      builder: (sheetContext) {
        final sheet = builder(sheetContext);
        final sizedSheet = heightFactor == null
            ? sheet
            : FractionallySizedBox(heightFactor: heightFactor, child: sheet);
        return PopScope<T>(
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) releaseMotion();
          },
          child: sizedSheet,
        );
      },
    );
  } finally {
    releaseMotion();
  }
}

/// Shared state read by the app's page transitions while a modal sheet is up.
class AppleSheetMotion {
  AppleSheetMotion._();

  static final ValueNotifier<int> _activeSheets = ValueNotifier<int>(0);

  static bool get isActive => _activeSheets.value > 0;
  static ValueNotifier<int> get activeSheetCount => _activeSheets;

  static void begin() => _activeSheets.value++;

  static void end() {
    if (_activeSheets.value > 0) _activeSheets.value--;
  }
}

/// Page transitions that preserve the platform navigation animation while
/// scaling and rounding the covered page during a modal sheet presentation.
final PageTransitionsTheme appleSheetPageTransitionsTheme =
    PageTransitionsTheme(
      builders: {
        for (final platform in TargetPlatform.values)
          platform: const AppleSheetPageTransitionsBuilder(),
      },
    );

class AppleSheetPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppleSheetPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final Widget platformTransition = switch (Theme.of(context).platform) {
      TargetPlatform.iOS || TargetPlatform.macOS =>
        const CupertinoPageTransitionsBuilder().buildTransitions<T>(
          route,
          context,
          animation,
          secondaryAnimation,
          child,
        ),
      TargetPlatform.android ||
      TargetPlatform.windows ||
      TargetPlatform.linux ||
      TargetPlatform.fuchsia =>
        const ZoomPageTransitionsBuilder().buildTransitions<T>(
          route,
          context,
          animation,
          secondaryAnimation,
          child,
        ),
    };

    return _AppleSheetBackgroundTransition(child: platformTransition);
  }
}

class _AppleSheetBackgroundTransition extends StatefulWidget {
  final Widget child;

  const _AppleSheetBackgroundTransition({required this.child});

  @override
  State<_AppleSheetBackgroundTransition> createState() =>
      _AppleSheetBackgroundTransitionState();
}

class _AppleSheetBackgroundTransitionState
    extends State<_AppleSheetBackgroundTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
    reverseDuration: const Duration(milliseconds: 360),
  );

  @override
  void initState() {
    super.initState();
    AppleSheetMotion._activeSheets.addListener(_syncAnimation);
    if (AppleSheetMotion.isActive) _controller.value = 1;
  }

  void _syncAnimation() {
    if (!mounted) return;
    if (AppleSheetMotion.isActive) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    AppleSheetMotion._activeSheets.removeListener(_syncAnimation);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final progress = Curves.easeInOutCubic.transform(_controller.value);
        final radius = 28 * progress;
        final safeTop = MediaQuery.paddingOf(context).top;
        final topGap = safeTop + 20;
        return ColoredBox(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Transform.translate(
                offset: Offset(0, topGap * progress),
                child: Transform.scale(
                  scale: 1 - (0.06 * progress),
                  alignment: Alignment.topCenter,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(radius),
                    child: ColoredBox(
                      color: AppColors.background,
                      child: child,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
