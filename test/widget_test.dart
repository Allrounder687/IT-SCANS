import 'package:flutter_test/flutter_test.dart';
import 'package:itscans/app.dart';

void main() {
  testWidgets('App boots and shows the home screen', (tester) async {
    await tester.pumpWidget(const ItScansApp());
    expect(find.textContaining('IT SCANS'), findsOneWidget);
  });
}
