import 'package:dr_hair/features/shop/data/datasources/cart_remote_data_source.dart';
import 'package:dr_hair/features/shop/presentation/views/cart_view.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class _CouponApi extends CartRemoteDataSource {
  @override
  Future<({bool success, String? message, int discount, int total})>
  applyCoupon(String code) async => code == 'FIRSTDR'
      ? (
          success: true,
          message: 'Coupon accepted by API.',
          discount: 200,
          total: 1848,
        )
      : (
          success: false,
          message: 'Coupon is not active.',
          discount: 0,
          total: 0,
        );
}

List<Map<String, dynamic>> _cartItems() => [
  {
    'id': 'serum',
    'title': 'Follicle Booster Serum',
    'desc': 'Test serum',
    'image': 'https://example.test/serum.png',
    'price': 1299,
    'quantity': 1,
  },
  {
    'id': 'biotin',
    'title': 'Biotin Growth Complex',
    'desc': 'Test nutrition product',
    'image': 'https://example.test/biotin.png',
    'price': 749,
    'quantity': 1,
  },
];

void main() {
  group('CartView', () {
    testWidgets('displays the server coupon discount', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CartView(
            initialItems: _cartItems(),
            remoteDataSource: _CouponApi(),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'FIRSTDR');
      await tester.ensureVisible(find.text('Apply'));
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(find.text('FIRSTDR applied. ₹200 saved.'), findsOneWidget);
      expect(find.text('₹1848'), findsWidgets);
    });

    testWidgets('renders the API-empty state with explore action', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: CartView(initialItems: [])),
      );
      expect(find.text('Your Cart is Empty'), findsOneWidget);
      expect(
        find.textContaining('haven\'t added any hair treatments yet'),
        findsOneWidget,
      );
      expect(find.text('Explore Treatments'), findsOneWidget);
    });

    testWidgets('clear cart empties without an undo toast', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: CartView(initialItems: _cartItems())),
      );
      expect(find.text('Follicle Booster Serum'), findsOneWidget);
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear cart'));
      await tester.pumpAndSettle();
      expect(find.text('Your Cart is Empty'), findsOneWidget);
      expect(find.text('UNDO'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('quantity changes update the cart total', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: CartView(initialItems: _cartItems())),
      );
      expect(find.text('₹2048'), findsWidgets);
      await tester.tap(find.byIcon(LucideIcons.plus).first);
      await tester.pumpAndSettle();
      expect(find.text('₹3347'), findsWidgets);
      await tester.tap(find.byIcon(LucideIcons.minus).first);
      await tester.pumpAndSettle();
      expect(find.text('₹2048'), findsWidgets);
    });

    testWidgets('removing an item updates the cart without a toast', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: CartView(initialItems: _cartItems())),
      );
      await tester.tap(find.byIcon(LucideIcons.trash2).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove item'));
      await tester.pumpAndSettle();
      expect(find.text('UNDO'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('₹749'), findsWidgets);
      expect(find.text('Follicle Booster Serum'), findsNothing);
    });
  });
}
