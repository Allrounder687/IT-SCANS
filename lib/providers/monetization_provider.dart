import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/monetization_service.dart';

class MonetizationProvider extends ChangeNotifier {
  final MonetizationService _service = MonetizationService();
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  bool _isLoading = true;
  int _scanCount = 0;
  bool _isPremium = false;
  bool _isAdSupported = false;
  int _purchasedScans = 0;

  static const String premiumProductId = 'scan_pack_400';
  ProductDetails? _premiumProduct;

  bool get isLoading => _isLoading;
  int get scanCount => _scanCount;
  bool get isPremium => _isPremium;
  bool get isAdSupported => _isAdSupported;
  int get purchasedScans => _purchasedScans;
  
  bool get canScan => _isPremium || _isAdSupported || _scanCount < (MonetizationService.freeScanLimit + _purchasedScans);
  int get remainingFreeScans => (MonetizationService.freeScanLimit + _purchasedScans) - _scanCount;
  ProductDetails? get premiumProduct => _premiumProduct;

  MonetizationProvider() {
    _init();
  }

  Future<void> _init() async {
    _scanCount = await _service.getScanCount();
    _isPremium = await _service.hasUnlockedPremium();
    _isAdSupported = await _service.isAdSupported();
    _purchasedScans = await _service.getPurchasedScans();

    _subscription = _service.purchaseStream.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription.cancel();
    }, onError: (error) {
      // handle error
    });

    await _loadProducts();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> incrementScanCount() async {
    if (!_isPremium && !_isAdSupported) {
      await _service.incrementScanCount();
      _scanCount = await _service.getScanCount();
      notifyListeners();
    }
  }

  Future<void> chooseAdSupportedTier() async {
    await _service.setAdSupported(true);
    _isAdSupported = true;
    notifyListeners();
  }

  Future<void> _loadProducts() async {
    final bool isAvailable = await _service.isStoreAvailable();
    if (!isAvailable) {
      return;
    }

    final ProductDetailsResponse response = await InAppPurchase.instance.queryProductDetails({premiumProductId});
    if (response.productDetails.isNotEmpty) {
      _premiumProduct = response.productDetails.first;
    }
  }

  Future<void> purchasePremium() async {
    if (_premiumProduct != null) {
      await _service.buyConsumablePack(_premiumProduct!);
    }
  }

  Future<void> restorePurchases() async {
    await _service.restorePurchases();
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.purchased || 
          purchaseDetails.status == PurchaseStatus.restored) {
        if (purchaseDetails.productID == premiumProductId) {
          // Increment consumable scans
          await _service.addPurchasedScans(400);
          _purchasedScans = await _service.getPurchasedScans();
          notifyListeners();
        }
      }
      
      if (purchaseDetails.status != PurchaseStatus.pending) {
        await _service.completePurchase(purchaseDetails);
      }
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
