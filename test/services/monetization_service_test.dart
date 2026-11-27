import 'package:flutter_test/flutter_test.dart';
import 'package:itscans/core/constants.dart';
import 'package:itscans/services/monetization_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('freeScanLimit matches AppConstants.freeScanLimit (400)', () {
    expect(MonetizationService.freeScanLimit, AppConstants.freeScanLimit);
    expect(MonetizationService.freeScanLimit, 400);
  });

  test('increments scan count and persists premium/ad flags', () async {
    final service = MonetizationService();

    expect(await service.getScanCount(), 0);
    await service.incrementScanCount();
    await service.incrementScanCount();
    expect(await service.getScanCount(), 2);

    expect(await service.isAdSupported(), isFalse);
    await service.setAdSupported(true);
    expect(await service.isAdSupported(), isTrue);

    expect(await service.hasUnlockedPremium(), isFalse);
    await service.setPremiumUnlocked(true);
    expect(await service.hasUnlockedPremium(), isTrue);

    await service.addPurchasedScans(400);
    expect(await service.getPurchasedScans(), 400);
  });
}
