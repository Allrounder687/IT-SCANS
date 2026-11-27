import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';

class MonetizationService {
  static const String _scanCountKey = 'itscans_scan_count';
  static const String _premiumUnlockedKey = 'itscans_premium_unlocked';

  static const int freeScanLimit = AppConstants.freeScanLimit;
  static const String _adSupportedKey = 'is_ad_supported';
  static const String _purchasedScansKey = 'purchased_scans';

  InAppPurchase get _iap => InAppPurchase.instance;

  Future<int> getScanCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_scanCountKey) ?? 0;
  }

  Future<void> incrementScanCount() async {
    final prefs = await SharedPreferences.getInstance();
    final currentCount = await getScanCount();
    await prefs.setInt(_scanCountKey, currentCount + 1);
  }

  Future<bool> hasUnlockedPremium() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_premiumUnlockedKey) ?? false;
  }

  Future<void> setPremiumUnlocked(bool unlocked) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_premiumUnlockedKey, unlocked);
  }

  Stream<List<PurchaseDetails>> get purchaseStream => _iap.purchaseStream;

  Future<bool> isStoreAvailable() async {
    return _iap.isAvailable();
  }

  Future<bool> isAdSupported() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_adSupportedKey) ?? false;
  }

  Future<void> setAdSupported(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_adSupportedKey, value);
  }

  Future<int> getPurchasedScans() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_purchasedScansKey) ?? 0;
  }

  Future<void> addPurchasedScans(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_purchasedScansKey) ?? 0;
    await prefs.setInt(_purchasedScansKey, current + amount);
  }

  Future<void> buyConsumablePack(ProductDetails productDetails) async {
    final PurchaseParam purchaseParam =
        PurchaseParam(productDetails: productDetails);
    await _iap.buyConsumable(
      purchaseParam: purchaseParam,
      autoConsume: true,
    );
  }

  Future<void> buySubscription(ProductDetails productDetails) async {
    final PurchaseParam purchaseParam =
        PurchaseParam(productDetails: productDetails);
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<void> completePurchase(PurchaseDetails purchaseDetails) async {
    if (purchaseDetails.pendingCompletePurchase) {
      await _iap.completePurchase(purchaseDetails);
    }
  }

  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }
}
