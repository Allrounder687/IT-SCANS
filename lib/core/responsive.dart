import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Device-adaptive layout metrics derived from actual screen dimensions and
/// safe-area insets so UI spacing never relies on single-device constants.
class AppLayout {
  final Size screenSize;
  final EdgeInsets viewPadding;

  const AppLayout._(this.screenSize, this.viewPadding);

  factory AppLayout.of(BuildContext context) {
    return AppLayout._(
      MediaQuery.sizeOf(context),
      MediaQuery.paddingOf(context),
    );
  }

  double get width => screenSize.width;
  double get height => screenSize.height;

  bool get isNarrow => width < 360;
  bool get isCompactHeight => height < 720;
  bool get isTablet => width >= 600;
  bool get isWide => width >= 900;

  double get horizontalPadding {
    if (isTablet) return 24;
    if (isNarrow) return 12;
    return (width * 0.04).clamp(14.0, 20.0);
  }

  double get topGap => isCompactHeight ? 4.0 : 8.0;
  double get sectionGap => isCompactHeight ? 8.0 : 12.0;
  double get tightGap => isCompactHeight ? 6.0 : 8.0;

  double get searchBarHeight => isCompactHeight ? 38.0 : 42.0;
  double get chipHeight => isCompactHeight ? 30.0 : 34.0;

  double get cardPadding => isNarrow ? 10.0 : (isTablet ? 14.0 : 12.0);
  double get cardSpacing => isCompactHeight ? 8.0 : 10.0;

  double get thumbWidth => isNarrow ? 40.0 : 44.0;
  double get thumbHeight => isNarrow ? 54.0 : 58.0;

  double get scanButtonHeight => isCompactHeight ? 48.0 : 52.0;

  /// Bottom clearance so scrollable lists clear the floating Scan button cleanly.
  double get floatingDockClearance => scanButtonHeight + 24.0;

  int get gridColumns {
    if (isWide) return 4;
    if (isTablet) return 3;
    return 2;
  }

  double get gridAspectRatio => isNarrow ? 0.72 : 0.78;

  double get greetingFontSize => (width * 0.056).clamp(18.0, 24.0);
  double get sectionTitleFontSize => (width * 0.046).clamp(16.0, 20.0);
  double get exportTitleFontSize => (width * 0.055).clamp(18.0, 24.0);

  double clampValue(double min, double fractionOfHeight, double max) {
    return math.min(max, math.max(min, height * fractionOfHeight));
  }
}
