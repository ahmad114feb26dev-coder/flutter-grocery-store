import 'package:flutter/material.dart';
import 'breakpoints.dart';

typedef ResponsiveWidgetBuilder = Widget Function(BuildContext context, BoxConstraints constraints);

/// A foundational responsive layout wrapper using [LayoutBuilder].
///
/// Conditionally renders [mobileLayout], [tabletLayout], and [desktopLayout]
/// based on available screen width. Also includes built-in max-width constraints
/// for Web and Desktop on ultrawide monitors.
class ResponsiveLayout extends StatelessWidget {
  /// Layout rendered on screens < 650px (Phones / compact viewports)
  final ResponsiveWidgetBuilder mobileLayout;

  /// Optional layout rendered on screens between 650px and 1100px (Tablets / Foldables).
  /// If null, falls back to [desktopLayout] or [mobileLayout].
  final ResponsiveWidgetBuilder? tabletLayout;

  /// Layout rendered on screens >= 1100px (Desktop / Web / Laptops)
  final ResponsiveWidgetBuilder desktopLayout;

  /// Maximum content width constraint on Desktop/Web to avoid awkward stretching on 4K/Ultrawide displays.
  final double maxContentWidth;

  /// Whether to automatically center the desktop/tablet content within [maxContentWidth].
  final bool centerContent;

  /// Optional background color
  final Color? backgroundColor;

  const ResponsiveLayout({
    super.key,
    required this.mobileLayout,
    this.tabletLayout,
    required this.desktopLayout,
    this.maxContentWidth = AppBreakpoints.maxContentWidth,
    this.centerContent = true,
    this.backgroundColor,
  });

  /// Simplified constructor that accepts pre-built [Widget]s instead of builder callbacks.
  factory ResponsiveLayout.widgets({
    Key? key,
    required Widget mobile,
    Widget? tablet,
    required Widget desktop,
    double maxContentWidth = AppBreakpoints.maxContentWidth,
    bool centerContent = true,
    Color? backgroundColor,
  }) {
    return ResponsiveLayout(
      key: key,
      mobileLayout: (ctx, constraints) => mobile,
      tabletLayout: tablet != null ? (ctx, constraints) => tablet : null,
      desktopLayout: (ctx, constraints) => desktop,
      maxContentWidth: maxContentWidth,
      centerContent: centerContent,
      backgroundColor: backgroundColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          Widget content;

          if (constraints.maxWidth < AppBreakpoints.mobileMax) {
            content = mobileLayout(context, constraints);
          } else if (constraints.maxWidth < AppBreakpoints.tabletMax) {
            if (tabletLayout != null) {
              content = tabletLayout!(context, constraints);
            } else {
              content = desktopLayout(context, constraints);
            }
          } else {
            content = desktopLayout(context, constraints);
          }

          // Apply ultrawide constraint when not on mobile
          if (centerContent && constraints.maxWidth >= AppBreakpoints.mobileMax) {
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                child: content,
              ),
            );
          }

          return content;
        },
      ),
    );
  }
}
