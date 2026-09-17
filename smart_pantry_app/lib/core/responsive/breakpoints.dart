/// Breakpoint definitions for consistent screen classification across Web, Tablet, and Mobile.
class AppBreakpoints {
  AppBreakpoints._();

  /// Maximum width for mobile devices (< 650px)
  static const double mobileMax = 650.0;

  /// Maximum width for tablet devices (< 1100px)
  static const double tabletMax = 1100.0;

  /// Default maximum content width for Web/Desktop on ultrawide monitors
  static const double maxContentWidth = 1280.0;

  /// Compact content width for forms / modals
  static const double maxFormWidth = 600.0;
}

/// Device categories
enum DeviceScreenType {
  mobile,
  tablet,
  desktop,
}
