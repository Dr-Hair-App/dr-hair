import 'package:flutter/foundation.dart';

@immutable
class ProductSupplyPlan {
  final String title;
  final String subtitle;
  final int price;
  final int mrp;
  final String? badge;

  const ProductSupplyPlan({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.mrp,
    this.badge,
  });

  factory ProductSupplyPlan.fromJson(Map<String, dynamic> json) {
    final price = (json['price'] is num)
        ? (json['price'] as num).toInt()
        : int.tryParse(json['price']?.toString() ?? '0') ?? 0;
    final mrp = (json['mrp'] is num)
        ? (json['mrp'] as num).toInt()
        : (json['compare_at_price'] is num)
        ? (json['compare_at_price'] as num).toInt()
        : int.tryParse(json['mrp']?.toString() ?? '0') ?? price;

    return ProductSupplyPlan(
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      price: price,
      mrp: mrp,
      badge: json['badge']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'subtitle': subtitle,
    'price': price,
    'mrp': mrp,
    if (badge != null) 'badge': badge,
  };

  int get durationMonths {
    final lower = title.toLowerCase();
    if (lower.contains('1') || lower.contains('one')) return 1;
    if (lower.contains('2') || lower.contains('two')) return 2;
    if (lower.contains('3') || lower.contains('three')) return 3;
    if (lower.contains('6') || lower.contains('six')) return 6;
    return 1;
  }

  int get monthlyPrice {
    final months = durationMonths;
    return months > 0 ? (price / months).round() : price;
  }

  int get savings => mrp > price ? mrp - price : 0;

  int get discountPercent =>
      mrp > price ? (((mrp - price) / mrp) * 100).round() : 0;

  /// Returns only the plans configured by the backend.
  static List<ProductSupplyPlan> ensureThreePlans(
    List<ProductSupplyPlan> plans,
  ) => List<ProductSupplyPlan>.unmodifiable(plans);
}

@immutable
class ProductBenefitItem {
  final String title;
  final String description;

  const ProductBenefitItem({required this.title, required this.description});

  factory ProductBenefitItem.fromJson(Map<String, dynamic> json) {
    return ProductBenefitItem(
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'title': title, 'description': description};
}

@immutable
class ProductIngredientItem {
  final String name;
  final String concentration;
  final String purpose;

  const ProductIngredientItem({
    required this.name,
    required this.concentration,
    required this.purpose,
  });

  factory ProductIngredientItem.fromJson(Map<String, dynamic> json) {
    return ProductIngredientItem(
      name: json['name']?.toString() ?? '',
      concentration: json['concentration']?.toString() ?? '',
      purpose: json['purpose']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'concentration': concentration,
    'purpose': purpose,
  };
}

@immutable
class ProductUsageStep {
  final int step;
  final String title;
  final String description;

  const ProductUsageStep({
    required this.step,
    required this.title,
    required this.description,
  });

  factory ProductUsageStep.fromJson(Map<String, dynamic> json) {
    return ProductUsageStep(
      step: (json['step'] is num)
          ? (json['step'] as num).toInt()
          : int.tryParse(json['step']?.toString() ?? '1') ?? 1,
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'step': step,
    'title': title,
    'description': description,
  };
}

@immutable
class ProductClinicalMetric {
  final String percentage;
  final String claim;
  final String source;

  const ProductClinicalMetric({
    required this.percentage,
    required this.claim,
    required this.source,
  });

  factory ProductClinicalMetric.fromJson(Map<String, dynamic> json) {
    return ProductClinicalMetric(
      percentage: json['percentage']?.toString() ?? '',
      claim: json['claim']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'percentage': percentage,
    'claim': claim,
    'source': source,
  };
}

@immutable
class ProductItem {
  final String id;
  final String name;
  final String subtitle;
  final String category;
  final String rootCause;
  final double rating;
  final int reviewsCount;
  final bool inStock;
  final List<String> images;
  final List<ProductSupplyPlan> supplyPlans;
  final List<ProductBenefitItem> benefits;
  final List<ProductIngredientItem> ingredients;
  final List<ProductUsageStep> usageSteps;
  final List<ProductClinicalMetric> clinicalMetrics;

  const ProductItem({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.category,
    this.rootCause = '',
    required this.rating,
    required this.reviewsCount,
    required this.inStock,
    required this.images,
    required this.supplyPlans,
    required this.benefits,
    required this.ingredients,
    required this.usageSteps,
    required this.clinicalMetrics,
  });

  static const ProductItem empty = ProductItem(
    id: '',
    name: '',
    subtitle: '',
    category: '',
    rootCause: '',
    rating: 0,
    reviewsCount: 0,
    inStock: false,
    images: [],
    supplyPlans: [],
    benefits: [],
    ingredients: [],
    usageSteps: [],
    clinicalMetrics: [],
  );

  factory ProductItem.fromJson(Map<String, dynamic> json) {
    final List<String> images = [];
    final rawImages = json['images'] as List<dynamic>? ?? [];
    for (final e in rawImages) {
      final s = e?.toString().trim() ?? '';
      if ((s.startsWith('http://') || s.startsWith('https://')) &&
          !images.contains(s)) {
        images.add(s);
      }
    }

    for (final key in ['image_url', 'secure_url', 'thumbnail', 'image']) {
      final val = json[key]?.toString().trim() ?? '';
      if ((val.startsWith('http://') || val.startsWith('https://')) &&
          !images.contains(val)) {
        images.add(val);
      }
    }

    if (json['media'] is List) {
      final mediaList = json['media'] as List<dynamic>;
      for (final item in mediaList) {
        if (item is Map) {
          final url =
              (item['url'] ?? item['secure_url'] ?? item['name'])
                  ?.toString()
                  .trim() ??
              '';
          if ((url.startsWith('http://') || url.startsWith('https://')) &&
              !images.contains(url)) {
            images.add(url);
          }
        }
      }
    }

    final rawPlans =
        json['supply_plans'] as List<dynamic>? ??
        json['supplyPlans'] as List<dynamic>? ??
        [];
    final supplyPlans = rawPlans
        .whereType<Map<String, dynamic>>()
        .map(ProductSupplyPlan.fromJson)
        .toList();

    final normalizedPlans = ProductSupplyPlan.ensureThreePlans(supplyPlans);

    final rawBenefits = json['benefits'] as List<dynamic>? ?? [];
    final benefits = rawBenefits
        .whereType<Map<String, dynamic>>()
        .map(ProductBenefitItem.fromJson)
        .toList();

    final rawIngredients = json['ingredients'] as List<dynamic>? ?? [];
    final ingredients = rawIngredients
        .whereType<Map<String, dynamic>>()
        .map(ProductIngredientItem.fromJson)
        .toList();

    final rawSteps =
        json['usage_steps'] as List<dynamic>? ??
        json['usageSteps'] as List<dynamic>? ??
        [];
    final usageSteps = rawSteps
        .whereType<Map<String, dynamic>>()
        .map(ProductUsageStep.fromJson)
        .toList();

    final rawMetrics =
        json['clinical_metrics'] as List<dynamic>? ??
        json['clinicalMetrics'] as List<dynamic>? ??
        [];
    final clinicalMetrics = rawMetrics
        .whereType<Map<String, dynamic>>()
        .map(ProductClinicalMetric.fromJson)
        .toList();

    final rootCauses =
        json['root_causes'] as List<dynamic>? ??
        json['rootCauses'] as List<dynamic>? ??
        [];
    final rootCause =
        json['root_cause']?.toString() ??
        json['rootCause']?.toString() ??
        (rootCauses.isNotEmpty ? rootCauses.first.toString() : '');

    return ProductItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      subtitle:
          json['subtitle']?.toString() ?? json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      rootCause: rootCause,
      rating: (json['rating'] is num)
          ? (json['rating'] as num).toDouble()
          : double.tryParse(json['rating']?.toString() ?? '') ?? 0,
      reviewsCount: (json['reviews_count'] is num)
          ? (json['reviews_count'] as num).toInt()
          : (json['reviewsCount'] is num)
          ? (json['reviewsCount'] as num).toInt()
          : int.tryParse(json['reviews_count']?.toString() ?? '0') ?? 0,
      inStock: json['in_stock'] == true || json['inStock'] == true,
      images: images,
      supplyPlans: normalizedPlans,
      benefits: benefits,
      ingredients: ingredients,
      usageSteps: usageSteps,
      clinicalMetrics: clinicalMetrics,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'subtitle': subtitle,
    'category': category,
    'root_cause': rootCause,
    'rating': rating,
    'reviews_count': reviewsCount,
    'in_stock': inStock,
    'images': images,
    'supply_plans': supplyPlans.map((p) => p.toJson()).toList(),
    'benefits': benefits.map((b) => b.toJson()).toList(),
    'ingredients': ingredients.map((i) => i.toJson()).toList(),
    'usage_steps': usageSteps.map((u) => u.toJson()).toList(),
    'clinical_metrics': clinicalMetrics.map((c) => c.toJson()).toList(),
  };

  static ProductItem get defaultProduct => ProductItem.empty;

  static final Map<String, ProductItem> _cachedProducts = {};

  static void cacheProducts(Iterable<ProductItem> items) {
    for (final p in items) {
      if (p.id.isNotEmpty) {
        _cachedProducts[p.id] = p;
      }
    }
  }

  static void clearCachedProducts() => _cachedProducts.clear();

  static ProductItem? findById(String? id) {
    if (id == null || id.isEmpty) return null;
    return _cachedProducts[id];
  }

  static List<ProductItem> getSuggestedProducts(String currentProductId) {
    final cached = _cachedProducts.values
        .where((p) => p.id.isNotEmpty && p.id != currentProductId && p.inStock && p.supplyPlans.isNotEmpty)
        .toList();
    return cached;
  }
}
