import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
// ignore: implementation_imports
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/razorpay_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_urls.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../core/storage/secure_session_store.dart';
import '../../../auth/presentation/viewmodels/auth_cubit.dart';
import '../../../care/domain/models/care_models.dart';
import '../../data/datasources/commerce_remote_data_source.dart';
import '../../data/models/delivery_address_model.dart';
import '../../data/repositories/checkout_recovery_store.dart';
import '../widgets/delivery_address_bottom_sheet.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/widgets/app_toast.dart';
import '../../../care/presentation/viewmodels/care_cubit.dart';
import '../viewmodels/cart_cubit.dart';

class CheckoutView extends StatefulWidget {
  final List<DeliveryAddress>? initialAddresses;

  const CheckoutView({super.key, this.initialAddresses});

  @override
  State<CheckoutView> createState() => _CheckoutViewState();
}

class _CheckoutViewState extends State<CheckoutView> {
  List<DeliveryAddress> _addresses = const [];
  DeliveryAddress? _selectedAddress;
  bool _isSubmitting = false;
  String _selectedPaymentGateway = 'cod';
  final Razorpay _razorpay = Razorpay();
  Map<String, dynamic>? _pendingPaymentOrder;
  String? _pendingPaymentToken;
  String? _pendingPaymentId;
  String? _pendingPaymentSignature;
  String? _pendingPaymentError;
  String? _checkoutAttemptKey;
  String? _checkoutAttemptFingerprint;
  bool _restoreStarted = false;
  Map<String, dynamic>? _shippingQuote;
  String? _shippingQuoteError;
  bool _isLoadingQuote = false;
  String? _shippingQuoteInputKey;
  int _shippingQuoteRequestId = 0;
  late final CommerceRemoteDataSource _commerceDataSource =
      CommerceRemoteDataSource();

  @override
  void initState() {
    super.initState();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _restorePendingCheckout();
    if (widget.initialAddresses != null &&
        widget.initialAddresses!.isNotEmpty) {
      _addresses = widget.initialAddresses!;
      _selectedAddress = _addresses.firstWhere(
        (a) => a.isDefault,
        orElse: () => _addresses.first,
      );
      _refreshShippingQuote();
    } else {
      _loadAddresses();
    }
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final paymentId = response.paymentId;
    final signature = response.signature;
    if (paymentId == null || signature == null) {
      if (mounted) setState(() => _isSubmitting = false);
      _showPaymentMessage(
        'Razorpay returned an incomplete payment response. Retry verification from checkout.',
      );
      return;
    }
    _pendingPaymentId = paymentId;
    _pendingPaymentSignature = signature;
    await _persistCheckoutRecovery();
    _verifyPendingPayment();
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _pendingPaymentError =
          response.message ??
          'Payment was not completed. You can retry this order.';
    });
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    _showPaymentMessage(
      'Selected external wallet: ${response.walletName ?? 'wallet'}',
    );
  }

  void _showPaymentMessage(String message) {
    if (mounted) AppToast.show(context, SnackBar(content: Text(message)));
  }

  void _openPendingRazorpayPayment() {
    final intent = _pendingPaymentOrder?['paymentIntent'];
    if (intent is! Map) return;
    final keyId = RazorpayConfig.keyId;
    final backendKey = intent['keyId']?.toString().trim() ?? '';
    final activeKeyId = backendKey.isNotEmpty ? backendKey : keyId;
    if (activeKeyId.isEmpty) {
      setState(() => _isSubmitting = false);
      _showPaymentMessage(
        'Razorpay Key ID is not configured. Check the app or backend environment.',
      );
      return;
    }
    try {
      _razorpay.open({
        'key': activeKeyId,
        'order_id': intent['intentId'],
        'amount': (intent['amount'] as num?)?.toInt(),
        'currency': intent['currency'] ?? 'INR',
        'name': 'Dr. Hair Clinic',
        'description': 'Dr. Hair Order Payment',
        'theme': {'color': '#0F766E'},
        'prefill': {
          'contact': _selectedAddress?.phone ?? '',
          'name': _selectedAddress?.name ?? '',
        },
        'retry': {'enabled': true, 'max_count': 2},
        'send_sms_hash': true,
      });
    } catch (_) {
      setState(() => _isSubmitting = false);
      _showPaymentMessage(
        'Could not open Razorpay checkout. Check that the Test Key ID is configured.',
      );
    }
  }

  Future<void> _verifyPendingPayment() async {
    final order = _pendingPaymentOrder?['order'];
    final orderId = order is Map ? order['order_id']?.toString() : null;
    var token = _pendingPaymentToken;
    final paymentId = _pendingPaymentId;
    final signature = _pendingPaymentSignature;
    if (orderId == null || paymentId == null || signature == null) {
      return;
    }
    token ??= await SecureSessionStore().readToken();
    if (token == null || token.isEmpty) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _pendingPaymentError = 'Sign in again to safely verify this payment. Your pending order is saved.';
        });
      }
      return;
    }
    _pendingPaymentToken = token;
    if (mounted) setState(() => _isSubmitting = true);
    try {
      final verified = await _commerceDataSource.verifyPayment(
        token: token,
        orderId: orderId,
        paymentId: paymentId,
        paymentSignature: signature,
      );
      final paidOrder = CareOrder.fromJson(verified);
      await _clearCheckoutRecovery();
      if (mounted) {
        context.read<CareCubit>().addOrder(paidOrder);
        context.read<CartCubit?>()?.clear();
        _pendingPaymentOrder = null;
        _pendingPaymentToken = null;
        _pendingPaymentId = null;
        _pendingPaymentSignature = null;
        _checkoutAttemptKey = null;
        _checkoutAttemptFingerprint = null;
        context.push(RouteNames.orders);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _pendingPaymentError = 'Payment was submitted, but confirmation is still pending. Tap Retry Payment to verify it; do not pay again.';
        });
        _refreshShippingQuote();
      }
    }
  }

  Future<void> _resumePendingCheckout() async {
    final order = _pendingPaymentOrder?['order'];
    final orderId = order is Map ? order['order_id']?.toString() : null;
    var token = _pendingPaymentToken;
    token ??= await SecureSessionStore().readToken();
    if (orderId == null || token == null || token.isEmpty) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _pendingPaymentError = 'Sign in again to check this saved payment. Do not start another payment yet.';
        });
      }
      return;
    }

    if (mounted) setState(() => _isSubmitting = true);
    _pendingPaymentToken = token;
    try {
      final result = await _commerceDataSource.reconcilePayment(
        token: token,
        orderId: orderId,
      );
      final rawOrder = result['order'];
      final payment = rawOrder is Map ? rawOrder['payment'] : null;
      final fulfillment = rawOrder is Map ? rawOrder['fulfillment'] : null;
      final resolved =
          result['paid'] == true ||
          result['resolved'] == true ||
          (payment is Map &&
              ['Paid', 'Refunded'].contains(payment['payment_status']));
      if (resolved) {
        if (payment is Map &&
            payment['payment_status'] == 'Paid' &&
            fulfillment is Map &&
            fulfillment['status'] != 'Cancelled' &&
            fulfillment['status'] != 'Refunded') {
          final paidOrder = CareOrder.fromJson(
            Map<String, dynamic>.from(rawOrder as Map),
          );
          if (mounted) {
            context.read<CareCubit>().addOrder(paidOrder);
            context.read<CartCubit?>()?.clear();
          }
        }
        await _clearCheckoutRecovery();
        if (!mounted) return;
        _pendingPaymentOrder = null;
        _pendingPaymentToken = null;
        _pendingPaymentId = null;
        _pendingPaymentSignature = null;
        _checkoutAttemptKey = null;
        _checkoutAttemptFingerprint = null;
        if (result['paid'] == true) {
          context.push(RouteNames.orders);
        } else {
          _showPaymentMessage(
            'This order is closed. Any captured payment is being refunded; check the order history for its status.',
          );
          context.push(RouteNames.orders);
        }
        return;
      }

      if (result['can_retry'] == true) {
        _pendingPaymentId = null;
        _pendingPaymentSignature = null;
        _pendingPaymentError = null;
        await _persistCheckoutRecovery();
        if (mounted) {
          setState(() => _isSubmitting = true);
          _openPendingRazorpayPayment();
        }
        return;
      }

      if (_pendingPaymentId != null && _pendingPaymentSignature != null) {
        await _verifyPendingPayment();
        return;
      }

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _pendingPaymentError = 'A payment attempt is still processing. Check again shortly; do not pay again yet.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _pendingPaymentError = 'Payment status could not be checked. Your order is saved; try again before making another payment.';
        });
      }
    }
  }

  Future<void> _restorePendingCheckout() async {
    if (_restoreStarted) return;
    _restoreStarted = true;
    try {
      final sessionStore = SecureSessionStore();
      final login = (await sessionStore.readLogin())?.trim().toLowerCase();
      if (login == null || login.isEmpty) return;
      final decoded = await CheckoutRecoveryStore(sessionStore: sessionStore)
          .loadForLogin(login);
      if (decoded == null) return;
      final checkout = decoded['checkout'];
      final restoredCheckout = checkout is Map
          ? Map<String, dynamic>.from(checkout)
          : null;
      final token = await sessionStore.readToken();
      if (!mounted) return;
      setState(() {
        _checkoutAttemptKey = decoded['idempotency_key']?.toString();
        _checkoutAttemptFingerprint = decoded['fingerprint']?.toString();
        if (restoredCheckout != null &&
            restoredCheckout['paymentIntent'] is Map) {
          _pendingPaymentOrder = restoredCheckout;
          _pendingPaymentToken = token;
          _pendingPaymentId = decoded['payment_id']?.toString();
          _pendingPaymentSignature = decoded['payment_signature']?.toString();
          _selectedPaymentGateway = 'razorpay';
        }
      });
    } catch (_) {
      // A corrupt local recovery record must not prevent the user from checking out again.
    }
  }

  Future<void> _persistCheckoutRecovery() async {
    try {
      final sessionStore = SecureSessionStore();
      final login = (await sessionStore.readLogin())?.trim();
      if (login == null || login.isEmpty) return;
      await CheckoutRecoveryStore(sessionStore: sessionStore).save(
        ownerLogin: login,
        idempotencyKey: _checkoutAttemptKey,
        fingerprint: _checkoutAttemptFingerprint,
        checkout: _pendingPaymentOrder,
        paymentId: _pendingPaymentId,
        paymentSignature: _pendingPaymentSignature,
      );
    } catch (_) {}
  }

  Future<void> _clearCheckoutRecovery() async {
    try {
      await CheckoutRecoveryStore().clear();
    } catch (_) {}
  }

  Future<void> _loadAddresses() async {
    try {
      final remoteAddresses = await _commerceDataSource.fetchAddresses();
      if (remoteAddresses.isNotEmpty && mounted) {
        setState(() {
          _addresses = remoteAddresses;
          _selectedAddress = remoteAddresses.firstWhere(
            (a) => a.isDefault,
            orElse: () => remoteAddresses.first,
          );
        });
      }
    } catch (_) {}
  }

  void _openAddressSheet() {
    DeliveryAddressBottomSheet.show(
      context: context,
      addresses: _addresses,
      selectedAddress: _selectedAddress,
      onAddressSelected: (address) {
        setState(() {
          _selectedAddress = address;
          _shippingQuote = null;
        });
        _refreshShippingQuote();
      },
      onAddressesUpdated: (updatedList, activeAddress) async {
        setState(() {
          _addresses = updatedList;
          _selectedAddress = activeAddress;
          _shippingQuote = null;
        });
        _refreshShippingQuote();
        try {
          await _commerceDataSource.createAddress(address: activeAddress);
        } catch (_) {}
      },
    );
  }

  List<Map<String, dynamic>> _checkoutItemsFromCart(
    List<dynamic> items,
  ) => items.map((item) {
    final rawId = (item['productId'] ?? item['product_id'] ?? item['id'] ?? '')
        .toString();
    final productId = rawId.contains('::') ? rawId.split('::').first : rawId;
    return <String, dynamic>{
      'productId': productId,
      'plan': item['plan']?.toString() ?? 'Standard',
      'quantity': (item['quantity'] as num?)?.toInt() ?? 1,
    };
  }).toList();

  Future<Map<String, dynamic>?> _refreshShippingQuote({String? token}) async {
    final address = _selectedAddress;
    final items = context.read<CartCubit?>()?.state.items ?? [];
    if (address == null ||
        items.isEmpty ||
        !RegExp(r'^[1-9][0-9]{5}$').hasMatch(address.pinCode)) {
      return null;
    }
    final requestId = ++_shippingQuoteRequestId;
    _shippingQuoteInputKey = _quoteInputKey(items, address);
    final authState = context.read<AuthCubit?>()?.state;
    final activeToken =
        token ??
        authState?.sessionToken ??
        await SecureSessionStore().readToken();
    if (mounted) {
      setState(() {
        _isLoadingQuote = true;
        _shippingQuoteError = null;
      });
    }
    try {
      final quote = await _commerceDataSource.getShippingQuote(
        token: activeToken,
        addressId:
            activeToken != null &&
                activeToken.isNotEmpty &&
                !address.id.startsWith('addr_')
            ? address.id
            : null,
        deliveryPincode: address.pinCode,
        items: _checkoutItemsFromCart(items),
        paymentGateway: _selectedPaymentGateway,
      );
      if (mounted && requestId == _shippingQuoteRequestId) {
        setState(() {
          _shippingQuote = quote;
          _shippingQuoteError = null;
        });
      }
      return quote;
    } catch (error) {
      final message = error is DioException && error.response?.data is Map
          ? ((error.response!.data as Map)['message']?.toString() ??
                'Delivery quote is unavailable.')
          : 'Delivery quote is unavailable. Please try again.';
      if (mounted && requestId == _shippingQuoteRequestId) {
        setState(() {
          _shippingQuote = null;
          _shippingQuoteError = message;
        });
      }
      return null;
    } finally {
      if (mounted && requestId == _shippingQuoteRequestId) {
        setState(() => _isLoadingQuote = false);
      }
    }
  }

  String _quoteInputKey(List<dynamic> items, DeliveryAddress? address) =>
      '${address?.pinCode}|$_selectedPaymentGateway|${_checkoutItemsFromCart(items).map((item) => '${item['productId']}:${item['plan']}:${item['quantity']}').join('|')}';

  Future<void> _handlePlaceOrder() async {
    if (_isSubmitting) return;
    if (_pendingPaymentOrder != null) {
      await _resumePendingCheckout();
      return;
    }
    final address = _selectedAddress;
    final cartState = context.read<CartCubit?>()?.state;
    final items = cartState?.items ?? [];
    if (address == null) {
      AppToast.show(
        context,
        const SnackBar(content: Text('Select a delivery address first.')),
      );
      return;
    }
    if (items.isEmpty) {
      AppToast.show(
        context,
        const SnackBar(
          content: Text('Your cart is empty. Add a product before checkout.'),
        ),
      );
      return;
    }

    final authState = context.read<AuthCubit?>()?.state;
    var token = authState?.sessionToken;
    if (token == null || token.isEmpty) {
      token = await SecureSessionStore().readToken();
    }

    if (token == null || token.isEmpty) {
      if (!mounted) return;
      AppToast.show(
        context,
        const SnackBar(content: Text('Please sign in to place your order.')),
      );
      context.push(RouteNames.signin);
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final checkoutItems = _checkoutItemsFromCart(items);
      final previousQuoteId = _shippingQuote?['quote_id'];
      final quote = await _refreshShippingQuote(token: token);
      if (quote == null) {
        throw StateError(
          _shippingQuoteError ??
              'A live delivery quote is required before checkout.',
        );
      }
      if (previousQuoteId != null && previousQuoteId != quote['quote_id']) {
        if (!mounted) return;
        final fee = (quote['shipping_fee'] as num?)?.toDouble() ?? 0;
        final accepted = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delivery price updated'),
            content: Text(
              'Courier price or availability changed. Delivery is now ₹${fee.toStringAsFixed(0)}. Continue with this quote?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Review'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Continue'),
              ),
            ],
          ),
        );
        if (accepted != true) return;
      }

      final fingerprint =
          '${address.id}|${checkoutItems.map((item) => '${item['productId']}:${item['plan']}:${item['quantity']}').join('|')}';
      if (_checkoutAttemptKey == null ||
          _checkoutAttemptFingerprint != fingerprint) {
        _checkoutAttemptFingerprint = fingerprint;
        _checkoutAttemptKey =
            'checkout_${DateTime.now().microsecondsSinceEpoch}_${address.id.hashCode.abs()}';
      }
      await _persistCheckoutRecovery();

      final result = await _commerceDataSource.checkout(
        token: token,
        idempotencyKey: _checkoutAttemptKey!,
        addressId: address.id.startsWith('addr_') ? null : address.id,
        shippingAddress: address,
        items: checkoutItems,
        paymentGateway: _selectedPaymentGateway,
        shippingQuoteId: quote['quote_id']?.toString(),
      );

      final rawOrder = result['order'] is Map<String, dynamic>
          ? result['order'] as Map<String, dynamic>
          : <String, dynamic>{};
      if (_selectedPaymentGateway == 'razorpay') {
        final intent = result['paymentIntent'];
        if (intent is! Map ||
            intent['intentId'] == null ||
            intent['amount'] == null) {
          throw const FormatException(
            'Backend did not return a valid Razorpay payment order.',
          );
        }
        _pendingPaymentOrder = result;
        _pendingPaymentToken = token;
        _pendingPaymentError = null;
        await _persistCheckoutRecovery();
        _openPendingRazorpayPayment();
        return;
      }
      final placedOrder = CareOrder.fromJson(rawOrder);
      await _clearCheckoutRecovery();

      if (mounted) {
        context.read<CareCubit>().addOrder(placedOrder);
        context.read<CartCubit?>()?.clear();
        _checkoutAttemptKey = null;
        _checkoutAttemptFingerprint = null;
        AppToast.show(
          context,
          SnackBar(
            content: Text('Order #${placedOrder.orderId} placed successfully!'),
          ),
        );
        context.push(RouteNames.orders);
      }
    } catch (e) {
      String errorMessage = 'Failed to place order. Please try again.';
      if (e is DioException) {
        final serverMsg = e.response?.data?['message'];
        if (serverMsg is String && serverMsg.isNotEmpty) {
          errorMessage = serverMsg;
        } else if (e.response?.statusCode == 409) {
          errorMessage = 'Order or courier details changed. Review checkout and try again.';
        }
      } else if (e is StateError) {
        errorMessage = e.message;
      }
      if (mounted) {
        AppToast.show(context, SnackBar(content: Text(errorMessage)));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartState = context.watch<CartCubit?>()?.state;
    final amount = cartState?.subtotal ?? 0;
    final cartItems = cartState?.items ?? [];
    final pendingRawOrder = _pendingPaymentOrder?['order'];
    final pendingOrder = pendingRawOrder is Map ? pendingRawOrder : null;
    final pendingPricing = pendingOrder?['pricing'] is Map
        ? pendingOrder!['pricing'] as Map
        : null;
    final pendingTotal = (pendingPricing?['total'] as num?)?.round();
    final buttonAmount =
        pendingTotal ??
        amount + ((_shippingQuote?['shipping_fee'] as num?)?.round() ?? 0);
    if (_selectedAddress != null &&
        cartItems.isNotEmpty &&
        _shippingQuoteInputKey != _quoteInputKey(cartItems, _selectedAddress) &&
        !_isLoadingQuote) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _refreshShippingQuote();
      });
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Checkout'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_pendingPaymentOrder != null) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F8F8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PAYMENT NEEDS CONFIRMATION',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppColors.secondaryDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Order ${pendingOrder?['order_id'] ?? ''} · ₹${pendingTotal ?? 0}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _pendingPaymentError ??
                          (_pendingPaymentId == null
                              ? 'Your order is saved. We will check its payment status before offering another payment attempt.'
                              : 'Payment was submitted. The app checks Razorpay before offering another payment attempt.'),
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: AppColors.secondaryDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Delivery Address Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'DELIVERY ADDRESS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.secondaryDark,
                    letterSpacing: 0.8,
                  ),
                ),
                GestureDetector(
                  onTap: _openAddressSheet,
                  child: const Text(
                    'Change',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            const Text(
              'Select your verified delivery address. Orders are dispatched with live courier tracking.',
              style: TextStyle(
                fontSize: 11,
                height: 1.35,
                color: AppColors.secondaryDark,
              ),
            ),
            const SizedBox(height: 10),

            // Address Card (Tap to change or add delivery address)
            GestureDetector(
              onTap: _openAddressSheet,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _selectedAddress != null
                        ? AppColors.primary100
                        : AppColors.border,
                    width: _selectedAddress != null ? 1.5 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: _selectedAddress == null
                    ? const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            LucideIcons.mapPin,
                            color: AppColors.primary,
                            size: 25,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Delivery address required',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Add a saved address before placing an order.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.secondaryDark,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            LucideIcons.chevronRight,
                            size: 18,
                            color: AppColors.secondaryDark,
                          ),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primary5,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              LucideIcons.mapPinCheck,
                              color: AppColors.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      _selectedAddress!.name,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primaryDark,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _selectedAddress!.tag.toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF1D4ED8),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _selectedAddress!.phone,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.secondaryDark,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _selectedAddress!.formattedAddress,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            LucideIcons.pencil,
                            size: 16,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 28),

            // Payment Options
            const Text(
              'PAYMENT METHOD',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.secondaryDark,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),
            _PaymentMethodCard(
              title: 'Cash on Delivery',
              subtitle: 'Pay the courier when your order arrives.',
              icon: LucideIcons.walletCards,
              selected: _selectedPaymentGateway == 'cod',
              onTap: _isSubmitting
                  ? null
                  : () {
                      setState(() {
                        _selectedPaymentGateway = 'cod';
                        _shippingQuote = null;
                      });
                      _refreshShippingQuote();
                    },
            ),
            if (!kIsWeb) ...[
              const SizedBox(height: 8),
              _PaymentMethodCard(
                title: 'Pay Online (Razorpay Test Mode)',
                subtitle: RazorpayConfig.keyId.isEmpty
                    ? 'Add RAZORPAY_KEY_ID to flutter_app/.env to enable test checkout.'
                    : 'Cards, UPI and wallets through Razorpay test checkout.',
                icon: LucideIcons.creditCard,
                selected: _selectedPaymentGateway == 'razorpay',
                enabled:
                    RazorpayConfig.keyId.isNotEmpty ||
                    _selectedPaymentGateway == 'razorpay',
                onTap: _isSubmitting || RazorpayConfig.keyId.isEmpty
                    ? null
                    : () {
                        setState(() {
                          _selectedPaymentGateway = 'razorpay';
                          _shippingQuote = null;
                        });
                        _refreshShippingQuote();
                      },
              ),
            ],
            if (_pendingPaymentError != null) ...[
              const SizedBox(height: 8),
              Text(
                _pendingPaymentError!,
                style: const TextStyle(color: Colors.deepOrange, fontSize: 12),
              ),
            ],

            const SizedBox(height: 16),

            // Order Breakdown
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _SummaryRow('Items Total', '₹$amount'),
                  _SummaryRow(
                    'Courier delivery',
                    _isLoadingQuote
                        ? 'Checking…'
                        : _shippingQuote == null
                        ? 'Unavailable'
                        : '₹${((_shippingQuote!['shipping_fee'] as num?) ?? 0).round()}',
                  ),
                  if (_shippingQuote != null)
                    _SummaryRow(
                      'Courier & ETA',
                      '${_shippingQuote!['courier'] ?? 'Available'}${(_shippingQuote!['estimated_delivery'] ?? '').toString().isEmpty ? '' : ' • ${_shippingQuote!['estimated_delivery']}'}',
                    ),
                  if (_shippingQuoteError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _shippingQuoteError!,
                        style: const TextStyle(
                          color: Colors.deepOrange,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  const _SummaryRow('Doctor Review Fee', 'WAIVED'),
                  const Divider(color: AppColors.border, height: 10),
                  _SummaryRow(
                    'Total Payable',
                    '₹${_pendingPaymentOrder != null ? (pendingTotal ?? 0) : buttonAmount}',
                    isTotal: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Place Order Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    _isSubmitting ||
                        (_pendingPaymentOrder == null && _shippingQuote == null)
                    ? null
                    : _handlePlaceOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${_pendingPaymentOrder != null ? 'Check Payment Status' : (_selectedPaymentGateway == 'razorpay' ? 'Pay Securely' : 'Place Order')} • ₹$buttonAmount',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Icon(LucideIcons.arrowRight, size: 20),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),

            // Verified Clinical Order Note
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary5,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary100),
              ),
              child: const Row(
                children: [
                  Icon(
                    LucideIcons.shieldCheck,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Orders are verified with server-determined pricing and inventory is reserved atomically upon placement.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.secondaryDark,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),

            // Policy Links
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                children: [
                  GestureDetector(
                    onTap: () => context.push(RouteNames.terms),
                    child: const Text(
                      'Terms & Conditions',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const Text('·', style: TextStyle(color: AppColors.textMuted)),
                  GestureDetector(
                    onTap: () => launchUrl(
                      Uri.parse(AppUrls.privacyPolicy),
                      mode: LaunchMode.externalApplication,
                    ),
                    child: const Text(
                      'Privacy Policy',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const Text('·', style: TextStyle(color: AppColors.textMuted)),
                  GestureDetector(
                    onTap: () => context.push(RouteNames.returnsRefunds),
                    child: const Text(
                      'Returns & Refunds',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;

  const _SummaryRow(this.label, this.value, {this.isTotal = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 14 : 12,
              fontWeight: isTotal ? FontWeight.w800 : FontWeight.w500,
              color: isTotal ? AppColors.primaryDark : AppColors.secondaryDark,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 16 : 12,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w600,
              color: isTotal ? AppColors.primary : AppColors.primaryDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  const _PaymentMethodCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppColors.primary : AppColors.secondaryDark;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary5 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.secondaryDark,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? LucideIcons.circleCheck : LucideIcons.circle,
              color: color,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
