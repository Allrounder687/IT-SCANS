import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class MonetizationService {
  static const String _scanCountKey = 'itscans_scan_count';
  static const String _premiumUnlockedKey = 'itscans_premium_unlocked';
  
  // Production limit per PRODUCT.md
  static const int freeScanLimit = 400; 
  
  final InAppPurchase _iap = InAppPurchase.instance;

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
    return await _iap.isAvailable();
  }

  Future<void> buyPremiumUnlock(ProductDetails productDetails) async {
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);
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
