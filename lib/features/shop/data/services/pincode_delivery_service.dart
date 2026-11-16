import '../../../../core/storage/app_local_cache.dart';

/// PIN validation and remembered destination only. Courier availability, price,
/// COD support, and delivery estimates must come from the backend quote API.
class PincodeDeliveryService {
  static const String _pincodeCacheKey = 'user_pincode_cache_v1';
  static final RegExp _pincodeRegex = RegExp(r'^[1-9][0-9]{5}$');

  static bool isValidPincode(String pincode) =>
      _pincodeRegex.hasMatch(pincode.trim());

  static Future<void> rememberPincode(String pincode) async {
    if (isValidPincode(pincode)) {
      await AppLocalCache.instance.put(_pincodeCacheKey, pincode.trim());
    }
  }

  static String? getSavedPincode() =>
      AppLocalCache.instance.getString(_pincodeCacheKey);
}
