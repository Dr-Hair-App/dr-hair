import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/routes/app_destination.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../core/widgets/app_skeletonizer.dart';
import '../../../../core/widgets/app_text_form_field.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/custom_cached_image.dart';
import '../../data/models/category_model.dart';
import '../../data/models/product_model.dart';
import '../viewmodels/cart_cubit.dart';
import '../viewmodels/products_cubit.dart';
import '../viewmodels/products_state.dart';

/// Dedicated Medicines & Products screen using [NestedScrollView] with SliverAppBar,
/// category TabBar for clinical root causes (Thyroid, Dandruff, Hair, Stress, Gut, PCOS, Hormone),
/// 2-column responsive product grid cards, and search icon beside cart button.
class ProductsView extends StatelessWidget {
  final ProductsCubit? cubit;

  const ProductsView({super.key, this.cubit});

  @override
  Widget build(BuildContext context) {
    if (cubit != null) {
      return BlocProvider<ProductsCubit>.value(
        value: cubit!,
        child: const _ProductsContent(),
      );
    }

    try {
      final existing = context.read<ProductsCubit?>();
      if (existing != null) {
        return const _ProductsContent();
      }
    } catch (_) {}

    return BlocProvider<ProductsCubit>(
      create: (_) => ProductsCubit()..loadProducts(),
      child: const _ProductsContent(),
    );
  }
}

class _ProductsContent extends StatefulWidget {
  const _ProductsContent();

  @override
  State<_ProductsContent> createState() => _ProductsContentState();
}

class _ProductsContentState extends State<_ProductsContent> {
  List<CategoryItem> _categories = CategoryItem.defaultProductCategories();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    final cubitCategories = context.read<ProductsCubit>().state.categories;
    if (cubitCategories.isNotEmpty) {
      _categories = cubitCategories;
    }
  }

  void _syncCategories(List<CategoryItem> newCategories) {
    if (newCategories.isEmpty) return;
    _categories = newCategories;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  double _productGridMainAxisExtent(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final baseExtent = screenWidth < 360 ? 274.0 : 270.0;
    final textScale = MediaQuery.textScalerOf(context).scale(12) / 12;
    final scaledExtent = baseExtent + ((textScale - 1).clamp(0.0, 0.8) * 90);
    return scaledExtent.clamp(baseExtent, 342.0).toDouble();
  }

  void _handleAddToCart(ProductItem product) {
    if (product.supplyPlans.isEmpty) {
      AppToast.showInfo(context, 'This product has no purchase option yet.');
      return;
    }
    final plan = product.supplyPlans.first;

    final cartCubit = context.read<CartCubit?>();
    if (cartCubit == null) {
      AppToast.showError(
        context,
        'Cart is unavailable. Please reopen the shop and try again.',
      );
      return;
    }
    cartCubit.addProduct(product: product, plan: plan, quantity: 1);
    AppToast.showSuccess(context, '${product.name} added to cart');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlocConsumer<ProductsCubit, ProductsState>(
        listener: (context, state) {
          if (state.products.isNotEmpty) {
            ProductItem.cacheProducts(state.products);
          }
          if (state.categories.isNotEmpty) {
            _syncCategories(state.categories);
          }
        },
        builder: (context, state) {
          final length = _categories.length;
          final initialIndex = state.selectedCategoryIndex
              .clamp(0, length - 1)
              .toInt();
          return DefaultTabController(
            length: length,
            initialIndex: initialIndex,
            child: _ProductTabSelectionListener(
              onChanged: (index) =>
                  context.read<ProductsCubit>().selectCategory(index),
              child: Builder(
                builder: (tabsContext) => RefreshIndicator(
                  color: AppColors.primary,
                  backgroundColor: Colors.white,
                  onRefresh: () async {
                    await context
                        .read<ProductsCubit>()
                        .refreshSelectedCategory();
                  },
                  child: NestedScrollView(
                    headerSliverBuilder:
                        (BuildContext context, bool innerBoxIsScrolled) {
                          return <Widget>[
                            SliverOverlapAbsorber(
                              handle:
                                  NestedScrollView.sliverOverlapAbsorberHandleFor(
                                    context,
                                  ),
                              sliver: SliverAppBar(
                                pinned: true,
                                floating: true,
                                snap: false,
                                centerTitle: true,
                                elevation: innerBoxIsScrolled ? 1 : 0,
                                backgroundColor: Colors.white,
                                surfaceTintColor: Colors.transparent,
                                title: const FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Medicines & Products',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                ),
                                actions: [
                                  // Cart Button with badge
                                  _buildCartButton(context),
                                  const SizedBox(width: 8),
                                ],
                                bottom: PreferredSize(
                                  preferredSize: const Size.fromHeight(104),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildSearchBar(),
                                      _buildTabBar(tabsContext),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ];
                        },
                    body: TabBarView(
                      controller: DefaultTabController.of(tabsContext),
                      children: _categories.asMap().entries.map((entry) {
                        final categoryIndex = entry.key;
                        final category = entry.value;
                        return SafeArea(
                          top: false,
                          bottom: false,
                          child: Builder(
                            builder: (BuildContext context) {
                              final catalog = state.productsFor(
                                category.id,
                                state.searchQuery,
                              );
                              // The API already applies the selected category and
                              // search query. Keep its result intact so searches by
                              // fields such as SKU are not filtered out locally.
                              final displayList = catalog;
                              final isActiveCategory =
                                  state.selectedCategoryIndex == categoryIndex;

                              return NotificationListener<ScrollNotification>(
                                onNotification: (notification) {
                                  if (notification.metrics.axis ==
                                          Axis.vertical &&
                                      notification.metrics.extentAfter < 420 &&
                                      state.hasMoreFor(
                                        category.id,
                                        state.searchQuery,
                                      )) {
                                    context.read<ProductsCubit>().loadNextPage(
                                      category.id,
                                      query: state.searchQuery,
                                    );
                                  }
                                  return false;
                                },
                                child: CustomScrollView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  key: PageStorageKey<String>(category.id),
                                  slivers: <Widget>[
                                    SliverOverlapInjector(
                                      handle:
                                          NestedScrollView.sliverOverlapAbsorberHandleFor(
                                            context,
                                          ),
                                    ),
                                    if (isActiveCategory &&
                                        state.errorMessage != null &&
                                        displayList.isNotEmpty)
                                      SliverPadding(
                                        padding: const EdgeInsets.fromLTRB(
                                          16,
                                          8,
                                          16,
                                          0,
                                        ),
                                        sliver: SliverToBoxAdapter(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.error.withValues(
                                                alpha: 0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: AppColors.error
                                                    .withValues(alpha: 0.3),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.info_outline,
                                                  size: 16,
                                                  color: AppColors.error,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    state.errorMessage!,
                                                    style: const TextStyle(
                                                      fontSize: 11.5,
                                                      color: AppColors.error,
                                                    ),
                                                  ),
                                                ),
                                                TextButton(
                                                  onPressed: () => context
                                                      .read<ProductsCubit>()
                                                      .refreshSelectedCategory(),
                                                  style: TextButton.styleFrom(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4,
                                                        ),
                                                    minimumSize: Size.zero,
                                                    tapTargetSize:
                                                        MaterialTapTargetSize
                                                            .shrinkWrap,
                                                  ),
                                                  child: const Text(
                                                    'Retry',
                                                    style: TextStyle(
                                                      fontSize: 11.5,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (isActiveCategory &&
                                        state.isLoading &&
                                        displayList.isEmpty) ...[
                                      SliverPadding(
                                        padding: const EdgeInsets.fromLTRB(
                                          16,
                                          12,
                                          16,
                                          4,
                                        ),
                                        sliver: SliverToBoxAdapter(
                                          child: AppSkeletonizer(
                                            enabled: true,
                                            child: Container(
                                              height: 12,
                                              width: 76,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFE9EEF5),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      SliverPadding(
                                        padding: const EdgeInsets.fromLTRB(
                                          10,
                                          8,
                                          10,
                                          32,
                                        ),
                                        sliver: SliverGrid(
                                          gridDelegate:
                                              SliverGridDelegateWithFixedCrossAxisCount(
                                                crossAxisCount:
                                                    MediaQuery.sizeOf(context)
                                                            .width >=
                                                        1000
                                                    ? 4
                                                    : MediaQuery.sizeOf(context)
                                                              .width >=
                                                          640
                                                    ? 3
                                                    : 2,
                                                crossAxisSpacing: 8,
                                                mainAxisSpacing: 8,
                                                mainAxisExtent:
                                                    _productGridMainAxisExtent(
                                                      context,
                                                    ),
                                              ),
                                          delegate: SliverChildBuilderDelegate((
                                            context,
                                            index,
                                          ) {
                                            return AppSkeletonizer(
                                              enabled: true,
                                              child:
                                                  const _ProductGridSkeletonCard(),
                                            );
                                          }, childCount: 6),
                                        ),
                                      ),
                                    ] else if (displayList.isEmpty)
                                      SliverFillRemaining(
                                        hasScrollBody: false,
                                        child:
                                            isActiveCategory &&
                                                state.errorMessage != null
                                            ? _buildErrorState(
                                                state.errorMessage!,
                                              )
                                            : _buildEmptyState(tabsContext),
                                      )
                                    else ...[
                                      SliverPadding(
                                        padding: const EdgeInsets.fromLTRB(
                                          16,
                                          12,
                                          16,
                                          4,
                                        ),
                                        sliver: SliverToBoxAdapter(
                                          child: AppSkeletonizer(
                                            enabled: state.isLoading,
                                            child: Text(
                                              state.totalFor(
                                                        category.id,
                                                        state.searchQuery,
                                                      ) >
                                                      displayList.length
                                                  ? '${displayList.length} of ${state.totalFor(category.id, state.searchQuery)} products'
                                                  : '${displayList.length} ${displayList.length == 1 ? 'product' : 'products'}',
                                              style: const TextStyle(
                                                color: AppColors.textSecondary,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      SliverPadding(
                                        padding: const EdgeInsets.fromLTRB(
                                          10,
                                          8,
                                          10,
                                          32,
                                        ),
                                        sliver: SliverGrid(
                                          gridDelegate:
                                              SliverGridDelegateWithFixedCrossAxisCount(
                                                crossAxisCount:
                                                    MediaQuery.sizeOf(context)
                                                            .width >=
                                                        1000
                                                    ? 4
                                                    : MediaQuery.sizeOf(context)
                                                              .width >=
                                                          640
                                                    ? 3
                                                    : 2,
                                                crossAxisSpacing: 8,
                                                mainAxisSpacing: 8,
                                                mainAxisExtent:
                                                    _productGridMainAxisExtent(
                                                      context,
                                                    ),
                                              ),
                                          delegate: SliverChildBuilderDelegate((
                                            context,
                                            index,
                                          ) {
                                            final product = displayList[index];
                                            return AppSkeletonizer(
                                              enabled:
                                                  isActiveCategory &&
                                                  state.isLoading,
                                              child: _ProductGridCard(
                                                product: product,
                                                onTap: () {
                                                  final destination =
                                                      AppDestination.product(
                                                        product.id,
                                                      ).location;
                                                  if (destination == null) {
                                                    AppToast.showError(
                                                      context,
                                                      'This product is unavailable right now.',
                                                    );
                                                    return;
                                                  }
                                                  context.push(
                                                    destination,
                                                    extra: product,
                                                  );
                                                },
                                                onAddToCart: () =>
                                                    _handleAddToCart(product),
                                              ),
                                            );
                                          }, childCount: displayList.length),
                                        ),
                                      ),
                                      if (isActiveCategory &&
                                          state.isLoadingMore &&
                                          displayList.isNotEmpty)
                                        const SliverToBoxAdapter(
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(
                                              vertical: 18,
                                            ),
                                            child: Center(
                                              child: SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: AppColors.primary,
                                                    ),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCartButton(BuildContext context) {
    final cartCubit = context.read<CartCubit?>();
    if (cartCubit == null) {
      return IconButton(
        icon: Center(
          child: const Icon(
            LucideIcons.shoppingBag,
            color: AppColors.primaryDark,
            size: 20,
          ),
        ),
        tooltip: 'My Cart',
        onPressed: () => context.push(RouteNames.cart),
      );
    }

    return BlocBuilder<CartCubit, CartState>(
      builder: (context, cartState) {
        final count = cartState.itemCount;
        return Semantics(
          label: 'Shopping Cart with $count items',
          button: true,
          child: Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(
                  LucideIcons.shoppingBag,
                  size: 20,
                  color: AppColors.primaryDark,
                ),
                tooltip: 'My Cart',
                onPressed: () => context.push(RouteNames.cart),
              ),
              if (count > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
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

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: AppTextFormField(
        key: const ValueKey('product-search'),
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: (value) {
          setState(() => _searchQuery = value);
          context.read<ProductsCubit>().search(value);
        },
        textInputAction: TextInputAction.search,
        hintText: 'Search medicines, products, ingredients…',
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppColors.primary,
          size: 20,
        ),
        suffixIcon: _searchQuery.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                  context.read<ProductsCubit>().clearSearch();
                },
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
        filled: true,
        fillColor: Colors.white,
        borderRadius: BorderRadius.circular(16),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 10,
          horizontal: 14,
        ),
      ),
    );
  }

  Widget _buildTabBar(BuildContext tabsContext) {
    return Container(
      height: 44,
      alignment: Alignment.centerLeft,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.8)),
      ),
      child: TabBar(
        controller: DefaultTabController.of(tabsContext),
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorColor: AppColors.primary,
        indicatorWeight: 2.5,
        indicatorPadding: const EdgeInsets.symmetric(horizontal: 4),
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        tabs: _categories.map((cat) {
          return Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(cat.icon, size: 14),
                const SizedBox(width: 6),
                Text(cat.name),
                if (cat.badge != null && cat.badge!.isNotEmpty) ...[
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      cat.badge!,
                      style: const TextStyle(
                        fontSize: 8.5,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ] else if (cat.itemCount > 0 && cat.id != 'all') ...[
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary5,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${cat.itemCount}',
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext tabsContext) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.primary5,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                color: AppColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'No matching products',
              style: TextStyle(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Try another condition, ingredient, or clear search.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                });
                context.read<ProductsCubit>().clearSearch();
                context.read<ProductsCubit>().selectCategory(0);
                DefaultTabController.of(tabsContext).animateTo(0);
              },
              child: const Text('Clear filters'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.primary5,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                color: AppColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Unable to load products',
              style: TextStyle(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey('products-retry-button'),
              onPressed: () =>
                  context.read<ProductsCubit>().refreshSelectedCategory(),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductTabSelectionListener extends StatefulWidget {
  final ValueChanged<int> onChanged;
  final Widget child;

  const _ProductTabSelectionListener({
    required this.onChanged,
    required this.child,
  });

  @override
  State<_ProductTabSelectionListener> createState() =>
      _ProductTabSelectionListenerState();
}

class _ProductTabSelectionListenerState
    extends State<_ProductTabSelectionListener> {
  TabController? _controller;
  int? _lastIndex;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextController = DefaultTabController.of(context);
    if (identical(nextController, _controller)) return;
    final previousIndex = _lastIndex;
    _controller?.removeListener(_handleTabSelection);
    _controller = nextController..addListener(_handleTabSelection);
    _lastIndex = nextController.index;
    if (previousIndex != null && previousIndex != nextController.index) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && identical(_controller, nextController)) {
          widget.onChanged(nextController.index);
        }
      });
    }
  }

  void _handleTabSelection() {
    final controller = _controller;
    if (mounted &&
        controller != null &&
        !controller.indexIsChanging &&
        controller.index != _lastIndex) {
      _lastIndex = controller.index;
      widget.onChanged(controller.index);
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_handleTabSelection);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Skeleton placeholder card designed specifically for the 2-column clinical product grid
class _ProductGridSkeletonCard extends StatelessWidget {
  const _ProductGridSkeletonCard();

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.sizeOf(context).width < 360;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Image area placeholder with fake badge silhouettes
          Stack(
            children: [
              Container(
                height: isNarrow ? 92 : 104,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  height: 18,
                  width: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              Positioned(
                bottom: 6,
                right: 6,
                child: Container(
                  height: 16,
                  width: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // 2. Title placeholders (2 lines)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 12,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9EEF5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  height: 12,
                  width: 90,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9EEF5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),

                // 3. Subtitle / ingredients placeholder
                Container(
                  height: 9,
                  width: 65,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9EEF5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // 4. Bottom row: Price & Add button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 9,
                        width: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE9EEF5),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 15,
                        width: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE9EEF5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 26,
                  width: 50,
                  decoration: BoxDecoration(
                    color: AppColors.primary5,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.15),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 3),
        ],
      ),
    );
  }
}

/// Clinical Product Card designed specifically for the 2-column grid
class _ProductGridCard extends StatelessWidget {
  final ProductItem product;
  final VoidCallback onTap;
  final VoidCallback onAddToCart;

  const _ProductGridCard({
    required this.product,
    required this.onTap,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    final plan = product.supplyPlans.isNotEmpty
        ? product.supplyPlans.first
        : null;
    final hasMultiplePlans = product.supplyPlans.length > 1;
    final minPrice = product.supplyPlans.fold<int>(
      plan?.price ?? 0,
      (min, p) => p.price < min ? p.price : min,
    );
    final price = plan != null
        ? (hasMultiplePlans ? 'From ₹$minPrice' : '₹${plan.price}')
        : 'Price N/A';
    final mrp = plan != null && plan.mrp > plan.price ? '₹${plan.mrp}' : null;
    final discountPercent = plan != null && plan.mrp > plan.price
        ? (((plan.mrp - plan.price) / plan.mrp) * 100).round()
        : null;

    final isAyurveda = product.category.toLowerCase().contains('ayurved');
    final tagLabel = product.rootCause.isNotEmpty
        ? product.rootCause
        : (isAyurveda ? 'Ayurveda' : 'Clinical');
    final isNarrow = MediaQuery.sizeOf(context).width < 360;

    return Semantics(
      label:
          '${product.name}, $price${product.rating > 0 && product.reviewsCount > 0 ? ', ${product.rating} stars from ${product.reviewsCount} reviews' : ''}',
      button: true,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.035),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image with category badge, discount & rating
                  Stack(
                    children: [
                      Hero(
                        tag: 'product_image_${product.id}_0',
                        child: CustomCachedImage(
                          imageUrl: product.images.isNotEmpty
                              ? product.images.first
                              : '',
                          height: isNarrow ? 92 : 104,
                          width: double.infinity,
                          borderRadius: 14,
                          fit: BoxFit.cover,
                          errorWidget: Container(
                            height: 104,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: AppColors.primary5,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              isAyurveda ? LucideIcons.leaf : LucideIcons.pill,
                              color: isAyurveda
                                  ? AppColors.success
                                  : AppColors.primary,
                              size: 28,
                            ),
                          ),
                        ),
                      ),

                      // Root cause badge (Top-Left)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.94),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isAyurveda
                                  ? AppColors.success.withValues(alpha: 0.3)
                                  : AppColors.primary.withValues(alpha: 0.25),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            tagLabel,
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: isAyurveda
                                  ? AppColors.success
                                  : AppColors.primary,
                            ),
                          ),
                        ),
                      ),

                      // Discount badge (Top-Right)
                      if (discountPercent != null && discountPercent > 0)
                        Positioned(
                          bottom: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$discountPercent% OFF',
                              style: const TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),

                      // Show ratings only when reviews are available.
                      if (product.rating > 0 && product.reviewsCount > 0)
                        Positioned(
                          bottom: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  size: 11,
                                  color: AppColors.starGold,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  product.rating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),

                  // Product Title
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryDark,
                              height: 1.2,
                            ),
                          ),

                          const SizedBox(height: 2),

                          // Subtitle / Active key ingredients
                          Text(
                            product.subtitle,
                            maxLines: isNarrow ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),

                          const Spacer(),

                          // Price and Add button Row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (mrp != null)
                                      Text(
                                        mrp,
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          decoration:
                                              TextDecoration.lineThrough,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    Text(
                                      price,
                                      style: const TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              InkWell(
                                onTap: onAddToCart,
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary5,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.25,
                                      ),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        LucideIcons.plus,
                                        size: 12,
                                        color: AppColors.primary,
                                      ),
                                      SizedBox(width: 2),
                                      Text(
                                        'Add',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
