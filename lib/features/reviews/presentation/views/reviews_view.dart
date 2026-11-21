import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/category_filter_bar.dart';
import '../../../../core/widgets/custom_cached_image.dart';
import '../../data/datasources/review_remote_data_source.dart';
import '../../data/models/review_model.dart';

class ReviewsView extends StatefulWidget {
  final ReviewRemoteDataSource? remoteDataSource;

  const ReviewsView({super.key, this.remoteDataSource});

  @override
  State<ReviewsView> createState() => _ReviewsViewState();
}

class _ReviewsViewState extends State<ReviewsView> {
  int _selectedFilterIndex = 0;
  final List<String> _filters = ['All', 'Hair Fall', 'Regrowth', 'Dandruff'];
  late final ReviewRemoteDataSource _dataSource;
  List<ReviewModel> _reviews = const [];
  bool _isLoading = false;
  String? _loadErrorMessage;
  late final ScrollController _scrollController;
  bool _isScrolledPastHeader = false;

  @override
  void initState() {
    super.initState();
    _dataSource = widget.remoteDataSource ?? ReviewRemoteDataSource();
    _scrollController = ScrollController()..addListener(_onScroll);
    _loadReviews();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final bool past = _scrollController.offset >= 10.0;
    if (past != _isScrolledPastHeader) {
      setState(() => _isScrolledPastHeader = past);
    }
  }

  Future<void> _loadReviews({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    _loadErrorMessage = null;
    if (forceRefresh) {
      ReviewRemoteDataSource.clearCache();
    }
    try {
      final items = await _dataSource.getReviews(category: null);
      if (!mounted) return;
      setState(() {
        _reviews = items;
        _isLoading = false;
        _loadErrorMessage = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadErrorMessage =
            'Reviews could not be loaded. Check your connection and retry.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<ReviewModel> filteredReviews = _selectedFilterIndex == 0
        ? _reviews
        : _reviews
              .where(
                (r) =>
                    r.category.toLowerCase() ==
                        _filters[_selectedFilterIndex].toLowerCase() ||
                    r.treatment.toLowerCase().contains(
                      _filters[_selectedFilterIndex].toLowerCase(),
                    ),
              )
              .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () => _loadReviews(forceRefresh: true),
        color: AppColors.primary,
        backgroundColor: Colors.white,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: <Widget>[
            SliverAppBar(
              pinned: true,
              floating: false,
              centerTitle: false,
              automaticallyImplyLeading: false,
              elevation: 0.0,
              backgroundColor: _isScrolledPastHeader
                  ? Colors.white
                  : AppColors.background,
              surfaceTintColor: Colors.transparent,
              toolbarHeight: 52.0,
              titleSpacing: 0,
              title: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                height: 52.0,
                decoration: BoxDecoration(
                  color: _isScrolledPastHeader
                      ? Colors.white
                      : AppColors.background,
                  border: Border(
                    bottom: BorderSide(
                      color: _isScrolledPastHeader
                          ? AppColors.border
                          : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  boxShadow: _isScrolledPastHeader
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.centerLeft,
                child: CategoryFilterBar(
                  categories: _filters,
                  selectedIndex: _selectedFilterIndex,
                  unselectedColor: _isScrolledPastHeader
                      ? AppColors.neutral100
                      : Colors.white,
                  onSelected: (index) {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedFilterIndex = index);
                    if (_reviews.isEmpty) {
                      _loadReviews();
                    }
                  },
                ),
              ),
            ),
            if (_isLoading)
              SliverPadding(
                key: const ValueKey('reviews_loading'),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
                sliver: SliverToBoxAdapter(
                  child: Skeletonizer(
                    enabled: true,
                    effect: _kReviewsShimmerEffect,
                    containersColor: Colors.white,
                    child: const Column(
                      children: [
                        _ReviewCardSkeleton(),
                        SizedBox(height: 14),
                        _ReviewCardSkeleton(),
                        SizedBox(height: 14),
                        _ReviewCardSkeleton(),
                        SizedBox(height: 14),
                        _ReviewCardSkeleton(),
                      ],
                    ),
                  ),
                ),
              )
            else if (_loadErrorMessage != null || filteredReviews.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    final scale = Tween<double>(begin: 0.98, end: 1).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    );
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(scale: scale, child: child),
                    );
                  },
                  child: _loadErrorMessage != null
                      ? _buildErrorState(_loadErrorMessage!)
                      : _buildEmptyState(),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
                sliver: SliverList.separated(
                  itemCount: filteredReviews.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final r = filteredReviews[index];
                    return _ReviewCard(review: r);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      key: const ValueKey('empty_reviews'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: AppColors.primary5,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.messageSquareDashed,
                size: 38,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'No reviews found in this category',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Try selecting another filter or view all reviews.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppColors.secondaryDark),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                setState(() => _selectedFilterIndex = 0);
                _loadReviews();
              },
              child: const Text('Show All Reviews'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      key: const ValueKey('reviews_load_error'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.92, end: 1),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: const Icon(
                LucideIcons.wifiOff,
                size: 36,
                color: AppColors.secondaryDark,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.secondaryDark),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: _loadReviews,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends StatefulWidget {
  final ReviewModel review;

  const _ReviewCard({required this.review});

  @override
  State<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<_ReviewCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _pressScale;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _pressScale = Tween<double>(begin: 1, end: 0.985).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.review;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return AnimatedBuilder(
      animation: _pressController,
      builder: (context, child) => Transform.scale(
        scale: reduceMotion ? 1 : _pressScale.value,
        child: child,
      ),
      child: GestureDetector(
        onTapDown: (_) {
          if (!reduceMotion) _pressController.forward();
        },
        onTapUp: (_) => _pressController.reverse(),
        onTapCancel: _pressController.reverse,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User info row
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary100,
                        width: 1.5,
                      ),
                    ),
                    child: ClipOval(
                      child: r.avatar.isNotEmpty
                          ? CustomCachedImage(
                              imageUrl: r.avatar,
                              width: 44,
                              height: 44,
                              borderRadius: 22,
                              fit: BoxFit.cover,
                              errorWidget: Container(
                                color: AppColors.primary5,
                                child: const Icon(
                                  LucideIcons.userRound,
                                  color: AppColors.primary,
                                  size: 22,
                                ),
                              ),
                            )
                          : Container(
                              color: AppColors.primary5,
                              child: const Icon(
                                LucideIcons.userRound,
                                color: AppColors.primary,
                                size: 22,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                r.name,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primaryDark,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (r.verified) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFFA7F3D0),
                                  ),
                                ),
                                child: const Text(
                                  'VERIFIED',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF047857),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (r.duration.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            r.duration,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.secondaryDark,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Row(
                    children: List.generate(
                      r.rating,
                      (i) => const Icon(
                        LucideIcons.star,
                        color: AppColors.starGold,
                        size: 15,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Category tag pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary5,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  r.treatment,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Testimonial comment
              Text(
                r.comment,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.secondaryDark,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Clinical medical shimmer effect matching Dr. Hair design system
const _kReviewsShimmerEffect = ShimmerEffect(
  baseColor: Color(0xFFE9EEF5),
  highlightColor: Colors.white,
  duration: Duration(milliseconds: 1400),
);

/// Skeleton placeholder for ReviewCard with attractive clinical aesthetics
class _ReviewCardSkeleton extends StatelessWidget {
  const _ReviewCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User info row
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFE9EEF5),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Container(
                            height: 14,
                            constraints: const BoxConstraints(maxWidth: 80),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE9EEF5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          height: 14,
                          width: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE9EEF5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Container(
                      height: 11,
                      width: 75,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE9EEF5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  5,
                  (i) => const Padding(
                    padding: EdgeInsets.only(left: 2),
                    child: Icon(
                      LucideIcons.star,
                      color: Color(0xFFE9EEF5),
                      size: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Category tag pill
          Container(
            height: 22,
            width: 95,
            decoration: BoxDecoration(
              color: const Color(0xFFE9EEF5),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 10),

          // Testimonial comment lines
          Container(
            height: 12,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFE9EEF5),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 12,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFE9EEF5),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 6),
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: 0.65,
            child: Container(
              height: 12,
              decoration: BoxDecoration(
                color: const Color(0xFFE9EEF5),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
