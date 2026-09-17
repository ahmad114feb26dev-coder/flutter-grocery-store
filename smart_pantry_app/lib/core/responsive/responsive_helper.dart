import 'package:flutter/material.dart';
import 'breakpoints.dart';

/// Helper class and utilities for responsive sizing and layout decisions.
class ResponsiveHelper {
  ResponsiveHelper._();

  static DeviceScreenType getDeviceType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppBreakpoints.mobileMax) {
      return DeviceScreenType.mobile;
    } else if (width < AppBreakpoints.tabletMax) {
      return DeviceScreenType.tablet;
    } else {
      return DeviceScreenType.desktop;
    }
  }

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < AppBreakpoints.mobileMax;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= AppBreakpoints.mobileMax && width < AppBreakpoints.tabletMax;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= AppBreakpoints.tabletMax;

  /// Selects value based on current device type
  static T value<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    required T desktop,
  }) {
    final type = getDeviceType(context);
    switch (type) {
      case DeviceScreenType.mobile:
        return mobile;
      case DeviceScreenType.tablet:
        return tablet ?? desktop;
      case DeviceScreenType.desktop:
        return desktop;
    }
  }
}

/// Extension on [BuildContext] for clean, readable responsive code.
extension ResponsiveContextExtensions on BuildContext {
  /// True if viewport width is < 650px
  bool get isMobile => ResponsiveHelper.isMobile(this);

  /// True if viewport width is between 650px and 1100px
  bool get isTablet => ResponsiveHelper.isTablet(this);

  /// True if viewport width is >= 1100px
  bool get isDesktop => ResponsiveHelper.isDesktop(this);

  /// Device classification
  DeviceScreenType get deviceType => ResponsiveHelper.getDeviceType(this);

  /// Total screen width from MediaQuery
  double get screenWidth => MediaQuery.of(this).size.width;

  /// Total screen height from MediaQuery
  double get screenHeight => MediaQuery.of(this).size.height;

  /// Returns a responsive value based on device category
  T responsiveValue<T>({
    required T mobile,
    T? tablet,
    required T desktop,
  }) {
    return ResponsiveHelper.value<T>(
      this,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
    );
  }

  /// Adaptive screen padding: 16 on mobile, 24 on tablet, 32 on desktop
  EdgeInsets get responsivePadding {
    return responsiveValue(
      mobile: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      tablet: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      desktop: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
    );
  }

  /// Adaptive grid cross axis count
  int responsiveGridCount({
    int mobile = 1,
    int? tablet,
    int desktop = 4,
  }) {
    return responsiveValue<int>(
      mobile: mobile,
      tablet: tablet ?? (desktop > 2 ? 2 : mobile),
      desktop: desktop,
    );
  }

  /// Dynamically scaled font size that won't overflow on small mobile screens
  double responsiveFontSize(double baseMobile, {double? tablet, double? desktop}) {
    return responsiveValue<double>(
      mobile: baseMobile,
      tablet: tablet ?? (baseMobile * 1.15),
      desktop: desktop ?? (baseMobile * 1.3),
    );
  }
}

/// A wrapper widget that constrains content to a maximum width on wide displays (Web/Desktop)
/// while allowing full fluid width with safe padding on smaller screens.
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry alignment;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = AppBreakpoints.maxContentWidth,
    this.padding,
    this.alignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    final effectivePadding = padding ?? context.responsivePadding;

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: effectivePadding,
          child: child,
        ),
      ),
    );
  }
}
