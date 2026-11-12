import 'package:flutter/widgets.dart';

/// Exposes the selected bottom-navigation branch to its retained descendants.
/// StatefulShellRoute keeps inactive branches mounted, so media must not rely
/// on disposal or viewport visibility alone to detect a tab switch.
class ShellTabVisibility extends InheritedWidget {
  final int activeIndex;

  const ShellTabVisibility({
    super.key,
    required this.activeIndex,
    required super.child,
  });

  static ShellTabVisibility? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellTabVisibility>();

  @override
  bool updateShouldNotify(ShellTabVisibility oldWidget) =>
      activeIndex != oldWidget.activeIndex;
}
