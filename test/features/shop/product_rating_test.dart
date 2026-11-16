import 'package:flutter_test/flutter_test.dart';

import 'package:dr_hair/features/shop/data/models/product_model.dart';

void main() {
  test('product without saved ratings parses as unrated', () {
    final product = ProductItem.fromJson({
      'id': 'unrated-product',
      'name': 'Test product',
      'category': 'Hair care',
    });

    expect(product.rating, 0);
    expect(product.reviewsCount, 0);
  });

  test('suggestions use only cached in-stock API products', () {
    ProductItem.clearCachedProducts();
    expect(ProductItem.getSuggestedProducts('current'), isEmpty);

    ProductItem.cacheProducts([
      ProductItem.fromJson({'id': 'current', 'name': 'Current'}),
      ProductItem.fromJson({
        'id': 'available',
        'name': 'Available',
        'in_stock': true,
        'supply_plans': [
          {'title': 'Four Week Course', 'price': 1000, 'mrp': 1200},
        ],
      }),
      ProductItem.fromJson({
        'id': 'sold-out',
        'name': 'Sold out',
        'in_stock': false,
      }),
    ]);

    expect(
      ProductItem.getSuggestedProducts('current').map((product) => product.id),
      ['available'],
    );
  });
}
