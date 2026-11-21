import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_form_field.dart';
import '../../../../core/widgets/custom_cached_image.dart';
import '../../data/datasources/cart_remote_data_source.dart';
import '../viewmodels/cart_cubit.dart';

class CartView extends StatefulWidget {
  final List<Map<String, dynamic>>? initialItems;
  final CartRemoteDataSource? remoteDataSource;

  const CartView({super.key, this.initialItems, this.remoteDataSource});

  @override
  State<CartView> createState() => _CartViewState();
}

class _CartViewState extends State<CartView> {
  late List<Map<String, dynamic>> _localItems;
  List<Map<String, dynamic>> get _items =>
      context.read<CartCubit?>()?.state.items ?? _localItems;

  final TextEditingController _couponController = TextEditingController();
  String? _appliedCouponCode;
  int _serverCouponDiscount = 0;
  String? _appliedCartFingerprint;
  String? _couponError;

  String get _cartFingerprint => _items
      .map((item) => '${item['id']}:${item['quantity']}:${item['price']}')
      .join('|');
  bool get _couponApplied =>
      _appliedCouponCode != null && _appliedCartFingerprint == _cartFingerprint;
  bool get _cartChangedAfterCoupon =>
      _appliedCouponCode != null && !_couponApplied;
  String? get _couponMessage {
    if (_cartChangedAfterCoupon) {
      return 'Cart changed. Apply the coupon again to refresh its discount.';
    }
    return _couponError;
  }

  @override
  void initState() {
    super.initState();
    _localItems = widget.initialItems != null
        ? List<Map<String, dynamic>>.from(
            widget.initialItems!.map((item) => Map<String, dynamic>.from(item)),
          )
        : <Map<String, dynamic>>[];
  }

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  int get _subtotal => _items.fold(
    0,
    (sum, item) => sum + (item['price'] as int) * (item['quantity'] as int),
  );

  int get _totalItemCount =>
      _items.fold(0, (sum, item) => sum + (item['quantity'] as int));

  int get _discount => _couponApplied ? _serverCouponDiscount : 0;

  int get _totalAmount {
    final total = _subtotal - _discount;
    return total < 0 ? 0 : total;
  }

  void _incrementQuantity(int index) {
    if (_items[index]['quantity'] < 10) {
      final sharedCart = context.read<CartCubit?>();
      if (sharedCart != null) {
        sharedCart.setQuantity(
          _items[index]['id'] as String,
          (_items[index]['quantity'] as int) + 1,
        );
      } else {
        setState(() {
          _localItems[index]['quantity'] =
              (_localItems[index]['quantity'] as int) + 1;
        });
      }
      HapticFeedback.selectionClick();
    }
  }

  void _decrementQuantity(int index) {
    if ((_items[index]['quantity'] as int) > 1) {
      final sharedCart = context.read<CartCubit?>();
      if (sharedCart != null) {
        sharedCart.setQuantity(
          _items[index]['id'] as String,
          (_items[index]['quantity'] as int) - 1,
        );
      } else {
        setState(() {
          _localItems[index]['quantity'] =
              (_localItems[index]['quantity'] as int) - 1;
        });
      }
      HapticFeedback.selectionClick();
    } else {
      _requestRemoveItem(index);
    }
  }

  void _removeItem(int index) {
    final removed = _items[index];
    final sharedCart = context.read<CartCubit?>();
    if (sharedCart != null) {
      sharedCart.remove(removed['id'] as String);
    } else {
      setState(() => _localItems.removeAt(index));
    }
    HapticFeedback.lightImpact();
  }

  Future<bool> _showDeleteWarning({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    return await showModalBottomSheet<bool>(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (sheetContext) => Container(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: AppColors.secondaryDark,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          height: 44,
                          text: 'Keep items',
                          variant: AppButtonVariant.outlined,
                          onPressed: () => Navigator.pop(sheetContext, false),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppButton(
                          height: 44,
                          text: confirmLabel,
                          variant: AppButtonVariant.filled,
                          backgroundColor: AppColors.danger,
                          foregroundColor: Colors.white,
                          onPressed: () => Navigator.pop(sheetContext, true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ) ??
        false;
  }

  Future<void> _requestRemoveItem(int index) async {
    if (index < 0 || index >= _items.length) return;
    final item = _items[index];
    final confirmed = await _showDeleteWarning(
      title: 'Remove this item?',
      message: '${item['title']} will be removed from your cart.',
      confirmLabel: 'Remove item',
    );
    if (!confirmed || !mounted) return;
    final currentIndex = _items.indexWhere(
      (entry) => entry['id'] == item['id'],
    );
    if (currentIndex >= 0) _removeItem(currentIndex);
  }

  Future<void> _clearCart() async {
    if (_items.isEmpty) return;
    final confirmed = await _showDeleteWarning(
      title: 'Clear your cart?',
      message:
          'All ${_items.length} item${_items.length == 1 ? '' : 's'} will be removed from your cart.',
      confirmLabel: 'Clear cart',
    );
    if (!confirmed || !mounted) return;
    final sharedCart = context.read<CartCubit?>();
    if (sharedCart != null) {
      sharedCart.clear();
      setState(() {
        _appliedCouponCode = null;
        _serverCouponDiscount = 0;
        _appliedCartFingerprint = null;
        _couponError = null;
        _couponController.clear();
      });
    } else {
      setState(() {
        _localItems.clear();
        _appliedCouponCode = null;
        _serverCouponDiscount = 0;
        _appliedCartFingerprint = null;
        _couponError = null;
        _couponController.clear();
      });
    }
    HapticFeedback.mediumImpact();
  }

  Future<void> _applyCoupon() async {
    final code = _couponController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _couponError = 'Enter a coupon code.');
      return;
    }

    final remoteRes = await (widget.remoteDataSource ?? CartRemoteDataSource())
        .applyCoupon(code);
    if (!mounted) return;

    if (remoteRes.success) {
      setState(() {
        _appliedCouponCode = code;
        _serverCouponDiscount = remoteRes.discount;
        _appliedCartFingerprint = _cartFingerprint;
        _couponError = null;
      });
      HapticFeedback.lightImpact();
      return;
    }
    setState(() {
      _appliedCouponCode = null;
      _serverCouponDiscount = 0;
      _appliedCartFingerprint = null;
      _couponError = remoteRes.message ?? 'Invalid or expired coupon code.';
    });
  }

  void _removeCoupon() {
    setState(() {
      _appliedCouponCode = null;
      _serverCouponDiscount = 0;
      _appliedCartFingerprint = null;
      _couponError = null;
      _couponController.clear();
    });
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final cartCubit = context.read<CartCubit?>();
    if (cartCubit != null) {
      return BlocBuilder<CartCubit, CartState>(
        builder: (context, state) => _buildScaffold(context),
      );
    }
    return _buildScaffold(context);
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'My Cart',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryDark,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          if (_items.isNotEmpty)
            TextButton(
              onPressed: _clearCart,
              child: const Text(
                'Clear',
                style: TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _items.isEmpty
          ? _buildEmptyState(context)
          : _buildCartContent(context),
      bottomNavigationBar: _items.isEmpty ? null : _buildCheckoutBar(context),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: 120),
          // Empty State Illustration
          Container(
            width: 150,
            height: 150,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary5,
              shape: BoxShape.circle,
            ),
            child: Image.asset(
              'assets/icons/SearchWithCross.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(
                LucideIcons.shoppingBag,
                size: 72,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'Your Cart is Empty',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Looks like you haven\'t added any hair treatments yet. Explore our doctor-approved formulations to begin your hair health journey.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.secondaryDark,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Explore Treatments Button
          AppButton(
            height: 45,
            text: 'Explore Treatments',
            variant: AppButtonVariant.filled,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            borderRadius: BorderRadius.circular(16),
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 5,
            ),
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                context.go(RouteNames.mainShell);
              }
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildCartContent(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sanctuary Clinical Assurance Banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: const Border(
                left: BorderSide(color: AppColors.primary, width: 4),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Row(
              children: [
                Icon(
                  LucideIcons.shieldCheck,
                  color: AppColors.primary,
                  size: 20,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Clinical Regimen Curated • Authentic formulations guaranteed with free dermatologist review',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.secondaryDark,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Items Heading
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Cart Items ($_totalItemCount)',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                ),
              ),
              const Row(
                children: [
                  Icon(LucideIcons.truck, size: 14, color: AppColors.success),
                  SizedBox(width: 4),
                  Text(
                    'Shipping at checkout',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Cart Items List
          ..._items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;

            return Dismissible(
              key: ValueKey('cart_item_${item['title']}_$index'),
              direction: DismissDirection.endToStart,
              background: Container(
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.trash2, color: AppColors.danger, size: 20),
                    SizedBox(width: 6),
                    Text(
                      'Remove',
                      style: TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              confirmDismiss: (_) async {
                return _showDeleteWarning(
                  title: 'Remove this item?',
                  message: '${item['title']} will be removed from your cart.',
                  confirmLabel: 'Remove item',
                );
              },
              onDismissed: (_) => _removeItem(index),
              child: Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomCachedImage(
                      imageUrl: item['image'] as String,
                      width: 72,
                      height: 72,
                      borderRadius: 14,
                      fit: BoxFit.cover,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  item['title'],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Remove ${item['title']}',
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                onPressed: () => _requestRemoveItem(index),
                                icon: const Icon(
                                  LucideIcons.trash2,
                                  color: AppColors.danger,
                                  size: 18,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            item['desc'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.secondaryDark,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '₹${item['price']}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primaryDark,
                                ),
                              ),

                              // Quantity Controls
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Decrease quantity',
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.all(6),
                                      constraints: const BoxConstraints(
                                        minWidth: 28,
                                        minHeight: 28,
                                      ),
                                      onPressed: () =>
                                          _decrementQuantity(index),
                                      icon: const Icon(
                                        LucideIcons.minus,
                                        size: 14,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      child: Text(
                                        '${item['quantity']}',
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.primaryDark,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Increase quantity',
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.all(6),
                                      constraints: const BoxConstraints(
                                        minWidth: 28,
                                        minHeight: 28,
                                      ),
                                      onPressed: () =>
                                          _incrementQuantity(index),
                                      icon: const Icon(
                                        LucideIcons.plus,
                                        size: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 12),

          // Coupon Code Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Apply a coupon',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AppTextFormField(
                        controller: _couponController,
                        hintText: 'Enter coupon code',
                        prefixIcon: const Icon(LucideIcons.tag, size: 16),
                        borderRadius: BorderRadius.circular(12),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        onChanged: (value) {
                          setState(() {
                            if (_appliedCouponCode != null &&
                                value.trim().toUpperCase() !=
                                    _appliedCouponCode) {
                              _appliedCouponCode = null;
                              _serverCouponDiscount = 0;
                              _appliedCartFingerprint = null;
                            }
                            _couponError = null;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (_couponApplied)
                      AppButton(
                        height: 40,
                        text: 'Remove',
                        variant: AppButtonVariant.outlined,
                        foregroundColor: AppColors.danger,
                        borderColor: AppColors.danger,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        borderRadius: BorderRadius.circular(12),
                        onPressed: _removeCoupon,
                      )
                    else
                      AppButton(
                        height: 40,
                        text: 'Apply',
                        variant: AppButtonVariant.filled,
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        borderRadius: BorderRadius.circular(12),
                        onPressed: _applyCoupon,
                      ),
                  ],
                ),
                if (_couponApplied) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        LucideIcons.checkCircle2,
                        size: 14,
                        color: AppColors.success,
                      ),
                      SizedBox(width: 6),
                      Text(
                        '$_appliedCouponCode applied. ₹$_discount saved.',
                        style: const TextStyle(
                          color: AppColors.success,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ] else if (_couponController.text.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _couponMessage ?? 'Enter an active coupon code.',
                    style: TextStyle(
                      color: _couponMessage == null
                          ? AppColors.secondaryDark
                          : AppColors.danger,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Order Summary Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Order Summary',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 12),
                _buildSummaryRow('Subtotal', '₹$_subtotal'),
                if (_couponApplied)
                  _buildSummaryRow(
                    'Coupon (${_appliedCouponCode ?? 'Offer'})',
                    '- ₹$_discount',
                    isDiscount: true,
                  ),
                _buildSummaryRow('Delivery charge', 'Calculated at checkout'),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(color: AppColors.border, height: 1),
                ),
                _buildSummaryRow(
                  'Total Amount',
                  '₹$_totalAmount',
                  isTotal: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: AppColors.border, width: 1.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '₹$_totalAmount',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryDark,
                        letterSpacing: -0.4,
                      ),
                    ),
                    Text(
                      '$_totalItemCount items • delivery at checkout',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 6,
                child: AppButton(
                  height: 48,
                  text: 'Proceed to Checkout',
                  trailingIcon: const Icon(
                    LucideIcons.arrowRight,
                    size: 16,
                    color: Colors.white,
                  ),
                  variant: AppButtonVariant.filled,
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    context.push(RouteNames.checkout);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isTotal = false,
    bool isDiscount = false,
  }) {
    Color valueColor;
    if (isDiscount) {
      valueColor = AppColors.success;
    } else if (isTotal) {
      valueColor = AppColors.primary;
    } else {
      valueColor = AppColors.primaryDark;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 14 : 12.5,
              fontWeight: isTotal ? FontWeight.w800 : FontWeight.w500,
              color: isTotal ? AppColors.primaryDark : AppColors.secondaryDark,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 16 : 13,
              fontWeight: isTotal ? FontWeight.w900 : FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
