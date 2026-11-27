import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itscans/core/responsive.dart';

void main() {
  testWidgets('AppLayout adapts padding and grid columns to screen sizes',
      (tester) async {
    late AppLayout narrowLayout;
    late AppLayout phoneLayout;
    late AppLayout tabletLayout;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(320, 568)),
        child: Builder(
          builder: (context) {
            narrowLayout = AppLayout.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(412, 915)),
        child: Builder(
          builder: (context) {
            phoneLayout = AppLayout.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(768, 1024)),
        child: Builder(
          builder: (context) {
            tabletLayout = AppLayout.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(narrowLayout.isNarrow, isTrue);
    expect(narrowLayout.isCompactHeight, isTrue);
    expect(narrowLayout.gridColumns, 2);
    expect(narrowLayout.horizontalPadding, 12);

    expect(phoneLayout.isCompactHeight, isFalse);
    expect(phoneLayout.gridColumns, 2);

    expect(tabletLayout.isTablet, isTrue);
    expect(tabletLayout.gridColumns, 3);
    expect(tabletLayout.horizontalPadding, 24);
  });
}
