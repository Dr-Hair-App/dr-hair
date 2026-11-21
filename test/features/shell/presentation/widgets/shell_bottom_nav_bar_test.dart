import 'package:dr_hair/features/shell/presentation/widgets/shell_bottom_nav_bar.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

void main() {
  testWidgets('selects tabs through the shell navigation bar', (tester) async {
    int selectedIndex = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ShellBottomNavBar(
              currentIndex: selectedIndex,
              onTabSelected: (index) => selectedIndex = index,
            ),
          ),
        ),
      ),
    );

    // Tap Videos tab by icon
    await tester.tap(find.byIcon(LucideIcons.circlePlay));
    expect(selectedIndex, 2);

    expect(find.byTooltip('AI Hair Assistant'), findsNothing);
  });

  testWidgets('renders and handles taps on cart summary bar', (tester) async {
    int cartPressedCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ShellBottomNavBar(
              currentIndex: 0,
              cartItemCount: 2,
              cartSubtotal: 1499,
              onTabSelected: (_) {},
              onCartPressed: () => cartPressedCount++,
            ),
          ),
        ),
      ),
    );

    // Ensure cart bar renders
    expect(find.byKey(const ValueKey('cart-summary')), findsOneWidget);
    expect(find.text('2 items · ₹1499'), findsOneWidget);
    expect(find.text('Tap to review & checkout'), findsOneWidget);
    expect(find.text('View Cart'), findsOneWidget);

    // Tap View Cart button directly
    await tester.tap(find.text('View Cart'));
    expect(cartPressedCount, 1);

    // Tap somewhere else on the cart bar
    await tester.tap(find.text('2 items · ₹1499'));
    expect(cartPressedCount, 2);
  });

  testWidgets('hides cart summary bar when cart is empty', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ShellBottomNavBar(
              currentIndex: 0,
              cartItemCount: 0,
              onTabSelected: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('cart-summary')), findsNothing);
    expect(find.byKey(const ValueKey('cart-summary-hidden')), findsOneWidget);
  });
  testWidgets('keeps the navigation pill centered with no assistant action', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShellBottomNavBar(currentIndex: 0, onTabSelected: (_) {}),
        ),
      ),
    );

    expect(find.byTooltip('AI Hair Assistant'), findsNothing);
    final constrainedBoxFinder = find.byWidgetPredicate(
      (w) => w is ConstrainedBox && w.constraints.maxWidth <= 288,
    );
    expect(constrainedBoxFinder, findsWidgets);
    expect(
      find.ancestor(of: constrainedBoxFinder.first, matching: find.byType(Center)),
      findsOneWidget,
    );
  });

  testWidgets('renders right-side shop button with medicine icon when isShopEnabled is true', (
    tester,
  ) async {
    bool shopTapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShellBottomNavBar(
            currentIndex: 0,
            onTabSelected: (_) {},
            isShopEnabled: true,
            onShopPressed: () => shopTapped = true,
          ),
        ),
      ),
    );

    final shopButton = find.byIcon(LucideIcons.pill);
    expect(shopButton, findsOneWidget);
    await tester.tap(shopButton);
    expect(shopTapped, isTrue);
  });

  testWidgets('tab width never exceeds 70 px in 3-slot and 4-slot configurations', (
    tester,
  ) async {
    // 3 slots (videos disabled)
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShellBottomNavBar(
            currentIndex: 0,
            isVideosEnabled: false,
            isShopEnabled: true,
            onTabSelected: (_) {},
          ),
        ),
      ),
    );

    // Verify all tab item sizes are <= 70 px width
    final homeTabFinder = find.byIcon(LucideIcons.home);
    expect(homeTabFinder, findsOneWidget);
    final homeSize = tester.getSize(homeTabFinder);
    expect(homeSize.width <= 70.0, isTrue);

    // 4 slots (videos enabled)
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShellBottomNavBar(
            currentIndex: 0,
            isVideosEnabled: true,
            isShopEnabled: true,
            onTabSelected: (_) {},
          ),
        ),
      ),
    );

    final homeSize4 = tester.getSize(find.byIcon(LucideIcons.home));
    expect(homeSize4.width <= 70.0, isTrue);
  });

  testWidgets(
    'animates hide with shrink and slide down for pill, and slide right + shrink for medicine button',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShellBottomNavBar(
              currentIndex: 0,
              isHidden: true,
              isShopEnabled: true,
              onTabSelected: (_) {},
            ),
          ),
        ),
      );

      // Verify AnimatedSlide with rightward offset for medicine button
      final rightSlideFinder = find.byWidgetPredicate(
        (w) => w is AnimatedSlide && w.offset == const Offset(2.2, 0),
      );
      expect(rightSlideFinder, findsOneWidget);

      // Verify AnimatedSlide with downward offset for navigation pill
      final bottomSlideFinder = find.byWidgetPredicate(
        (w) => w is AnimatedSlide && w.offset == const Offset(0, 1.5),
      );
      expect(bottomSlideFinder, findsOneWidget);

      // Verify AnimatedScale with shrink values
      final rightScaleFinder = find.byWidgetPredicate(
        (w) => w is AnimatedScale && w.scale == 0.1,
      );
      expect(rightScaleFinder, findsOneWidget);

      final pillScaleFinder = find.byWidgetPredicate(
        (w) => w is AnimatedScale && w.scale == 0.5,
      );
      expect(pillScaleFinder, findsOneWidget);
    },
  );

  testWidgets('hides videos tab and adjusts slots when isVideosEnabled is false', (
    tester,
  ) async {
    int selectedIndex = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShellBottomNavBar(
            currentIndex: selectedIndex,
            isVideosEnabled: false,
            onTabSelected: (index) => selectedIndex = index,
          ),
        ),
      ),
    );

    // Videos tab icon should NOT be present
    expect(find.byIcon(LucideIcons.circlePlay), findsNothing);
    expect(find.text('Videos'), findsNothing);

    // Other 3 tabs must still exist
    expect(find.byIcon(LucideIcons.home), findsOneWidget);
    expect(find.byIcon(LucideIcons.listChecks), findsOneWidget);
    expect(find.byIcon(LucideIcons.userRound), findsOneWidget);

    // ConstrainedBox has maxWidth 218 for 3 tabs (3 * 70 + 8)
    final constrainedBoxFinder = find.byWidgetPredicate(
      (w) => w is ConstrainedBox && w.constraints.maxWidth == 218,
    );
    expect(constrainedBoxFinder, findsWidgets);

    // Tapping Profile tab routes to branch 3
    await tester.tap(find.byIcon(LucideIcons.userRound));
    expect(selectedIndex, 3);

    // Tapping Reviews tab routes to branch 1
    await tester.tap(find.byIcon(LucideIcons.listChecks));
    expect(selectedIndex, 1);
  });
}
