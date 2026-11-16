import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:dr_hair/core/constants/app_colors.dart';
import 'package:dr_hair/core/widgets/dotted_divider.dart';

void main() {
  group('DottedDivider & DottedBorder Component Tests', () {
    testWidgets(
      'renders DottedDivider with default dot size (height 1, width 3)',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(child: SizedBox(width: 300, child: DottedDivider())),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final dividerFinder = find.byType(DottedDivider);
        expect(dividerFinder, findsOneWidget);

        final DottedDivider widget = tester.widget(dividerFinder);
        expect(widget.dotHeight, 1.0);
        expect(widget.dotWidth, 3.0);
        expect(widget.spacing, 3.0);
        expect(widget.height, 20.0);
      },
    );

    testWidgets(
      'respects customizable dotHeight, dotWidth, spacing, padding, and vertical axis',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  height: 200,
                  child: DottedDivider(
                    height: 32,
                    dotWidth: 6.0,
                    dotHeight: 2.0,
                    spacing: 4.0,
                    color: AppColors.primary,
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    axis: Axis.vertical,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final dividerFinder = find.byType(DottedDivider);
        expect(dividerFinder, findsOneWidget);
        final DottedDivider widget = tester.widget(dividerFinder);
        expect(widget.height, 32);
        expect(widget.dotWidth, 6.0);
        expect(widget.dotHeight, 2.0);
        expect(widget.spacing, 4.0);
        expect(widget.color, AppColors.primary);
        expect(widget.axis, Axis.vertical);
        expect(widget.padding, const EdgeInsets.symmetric(horizontal: 16));
      },
    );

    testWidgets('renders customizable DottedBorder container around child', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: DottedBorder(
                dotWidth: 4.0,
                strokeWidth: 1.5,
                spacing: 3.5,
                radius: 16.0,
                color: AppColors.primary,
                padding: const EdgeInsets.all(12),
                child: const Text('Dotted Box Content'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DottedBorder), findsOneWidget);
      expect(find.text('Dotted Box Content'), findsOneWidget);

      final DottedBorder borderWidget = tester.widget(
        find.byType(DottedBorder),
      );
      expect(borderWidget.dotWidth, 4.0);
      expect(borderWidget.strokeWidth, 1.5);
      expect(borderWidget.spacing, 3.5);
      expect(borderWidget.radius, 16.0);
      expect(borderWidget.color, AppColors.primary);
    });

    testWidgets('handles zero width gracefully without errors', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SizedBox(width: 0, child: DottedDivider())),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
