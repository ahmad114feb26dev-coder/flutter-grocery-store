import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Available animation presets for scroll-triggered reveals
enum RevealAnimationType {
  /// Smooth opacity fade
  fade,

  /// Fade + upward slide (Modern web standard)
  slideUp,

  /// Fade + downward slide
  slideDown,

  /// Fade + slide in from right to left
  slideLeft,

  /// Fade + slide in from left to right
  slideRight,

  /// Fade + gentle scale up from 90% to 100%
  scaleUp,

  /// Subtle tilt/perspective flip
  flipUp,

  /// Custom effects provided by [ScrollReveal.customEffects]
  custom,
}

/// A clean, high-performance Flutter Web & Mobile wrapper widget that triggers
/// smooth entrance animations using `flutter_animate` when scrolled into view.
///
/// Example:
/// ```dart
/// ScrollReveal(
///   type: RevealAnimationType.slideUp,
///   delay: const Duration(milliseconds: 100),
///   child: MySectionCard(),
/// )
/// ```
///
/// Or with the extension:
/// ```dart
/// MySectionCard().scrollReveal(
///   type: RevealAnimationType.slideUp,
///   delay: 150.ms,
/// )
/// ```
class ScrollReveal extends StatefulWidget {
  /// The widget to animate when it becomes visible
  final Widget child;

  /// Animation preset type (defaults to [RevealAnimationType.slideUp])
  final RevealAnimationType type;

  /// Duration of the entrance animation (defaults to 650ms)
  final Duration duration;

  /// Optional delay before starting the animation once visible (great for staggered lists)
  final Duration delay;

  /// Animation curve (defaults to [Curves.easeOutCubic] for silky-smooth motion)
  final Curve curve;

  /// Fraction of widget that must enter the viewport before triggering (0.0 to 1.0).
  /// Defaults to 0.12 (12% visibility), ensuring animations start promptly as user scrolls.
  final double visibilityThreshold;

  /// If true (default), the animation plays once when first entering the viewport and stays.
  /// If false, it reverses when scrolled out and replays when scrolled back in.
  final bool animateOnce;

  /// Magnitude of slide displacement (e.g. 0.15 = 15% of widget height/width)
  final double slideOffset;

  /// Custom list of [Effect]s if [type] is [RevealAnimationType.custom]
  final List<Effect>? customEffects;

  /// Key used by [VisibilityDetector]. If null, a unique Key is created automatically.
  final Key? detectorKey;

  /// Optional callback triggered when the widget enters viewport
  final VoidCallback? onVisible;

  const ScrollReveal({
    super.key,
    required this.child,
    this.type = RevealAnimationType.slideUp,
    this.duration = const Duration(milliseconds: 650),
    this.delay = Duration.zero,
    this.curve = Curves.easeOutCubic,
    this.visibilityThreshold = 0.12,
    this.animateOnce = true,
    this.slideOffset = 0.15,
    this.customEffects,
    this.detectorKey,
    this.onVisible,
  });

  /// Convenience constructor for Slide Up + Fade
  const ScrollReveal.slideUp({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 650),
    this.delay = Duration.zero,
    this.curve = Curves.easeOutCubic,
    this.visibilityThreshold = 0.12,
    this.animateOnce = true,
    this.slideOffset = 0.15,
    this.detectorKey,
    this.onVisible,
  })  : type = RevealAnimationType.slideUp,
        customEffects = null;

  /// Convenience constructor for Slide Down + Fade
  const ScrollReveal.slideDown({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 650),
    this.delay = Duration.zero,
    this.curve = Curves.easeOutCubic,
    this.visibilityThreshold = 0.12,
    this.animateOnce = true,
    this.slideOffset = 0.15,
    this.detectorKey,
    this.onVisible,
  })  : type = RevealAnimationType.slideDown,
        customEffects = null;

  /// Convenience constructor for Slide Left + Fade (from right to left)
  const ScrollReveal.slideLeft({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 650),
    this.delay = Duration.zero,
    this.curve = Curves.easeOutCubic,
    this.visibilityThreshold = 0.12,
    this.animateOnce = true,
    this.slideOffset = 0.15,
    this.detectorKey,
    this.onVisible,
  })  : type = RevealAnimationType.slideLeft,
        customEffects = null;

  /// Convenience constructor for Slide Right + Fade (from left to right)
  const ScrollReveal.slideRight({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 650),
    this.delay = Duration.zero,
    this.curve = Curves.easeOutCubic,
    this.visibilityThreshold = 0.12,
    this.animateOnce = true,
    this.slideOffset = 0.15,
    this.detectorKey,
    this.onVisible,
  })  : type = RevealAnimationType.slideRight,
        customEffects = null;

  /// Convenience constructor for Scale Up + Fade
  const ScrollReveal.scaleUp({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 600),
    this.delay = Duration.zero,
    this.curve = Curves.easeOutBack,
    this.visibilityThreshold = 0.12,
    this.animateOnce = true,
    this.detectorKey,
    this.onVisible,
  })  : type = RevealAnimationType.scaleUp,
        slideOffset = 0,
        customEffects = null;

  /// Convenience constructor for Pure Fade
  const ScrollReveal.fade({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 550),
    this.delay = Duration.zero,
    this.curve = Curves.easeOut,
    this.visibilityThreshold = 0.10,
    this.animateOnce = true,
    this.detectorKey,
    this.onVisible,
  })  : type = RevealAnimationType.fade,
        slideOffset = 0,
        customEffects = null;

  /// Call this once in `main()` for instant, responsive web scroll detection
  static void configureWebScrollInterval({Duration interval = const Duration(milliseconds: 50)}) {
    VisibilityDetectorController.instance.updateInterval = interval;
  }

  @override
  State<ScrollReveal> createState() => _ScrollRevealState();
}

class _ScrollRevealState extends State<ScrollReveal> {
  late final Key _key;
  bool _isVisible = false;
  bool _hasTriggered = false;

  @override
  void initState() {
    super.initState();
    _key = widget.detectorKey ?? UniqueKey();
  }

  void _handleVisibilityChanged(VisibilityInfo info) {
    if (!mounted) return;

    final visible = info.visibleFraction >= widget.visibilityThreshold;

    if (visible) {
      if (!_isVisible) {
        setState(() {
          _isVisible = true;
          _hasTriggered = true;
        });
        widget.onVisible?.call();
      }
    } else {
      if (!widget.animateOnce && _isVisible) {
        setState(() {
          _isVisible = false;
        });
      }
    }
  }

  List<Effect> _buildEffects() {
    if (widget.type == RevealAnimationType.custom && widget.customEffects != null) {
      return widget.customEffects!;
    }

    final duration = widget.duration;
    final curve = widget.curve;
    final delay = widget.delay;
    final offset = widget.slideOffset;

    switch (widget.type) {
      case RevealAnimationType.fade:
        return [
          FadeEffect(
            duration: duration,
            delay: delay,
            curve: curve,
            begin: 0.0,
            end: 1.0,
          ),
        ];

      case RevealAnimationType.slideUp:
        return [
          FadeEffect(
            duration: duration,
            delay: delay,
            curve: curve,
            begin: 0.0,
            end: 1.0,
          ),
          SlideEffect(
            duration: duration,
            delay: delay,
            curve: curve,
            begin: Offset(0, offset),
            end: Offset.zero,
          ),
        ];

      case RevealAnimationType.slideDown:
        return [
          FadeEffect(
            duration: duration,
            delay: delay,
            curve: curve,
            begin: 0.0,
            end: 1.0,
          ),
          SlideEffect(
            duration: duration,
            delay: delay,
            curve: curve,
            begin: Offset(0, -offset),
            end: Offset.zero,
          ),
        ];

      case RevealAnimationType.slideLeft:
        return [
          FadeEffect(
            duration: duration,
            delay: delay,
            curve: curve,
            begin: 0.0,
            end: 1.0,
          ),
          SlideEffect(
            duration: duration,
            delay: delay,
            curve: curve,
            begin: Offset(offset, 0),
            end: Offset.zero,
          ),
        ];

      case RevealAnimationType.slideRight:
        return [
          FadeEffect(
            duration: duration,
            delay: delay,
            curve: curve,
            begin: 0.0,
            end: 1.0,
          ),
          SlideEffect(
            duration: duration,
            delay: delay,
            curve: curve,
            begin: Offset(-offset, 0),
            end: Offset.zero,
          ),
        ];

      case RevealAnimationType.scaleUp:
        return [
          FadeEffect(
            duration: duration,
            delay: delay,
            curve: Curves.easeOut,
            begin: 0.0,
            end: 1.0,
          ),
          ScaleEffect(
            duration: duration,
            delay: delay,
            curve: curve,
            begin: const Offset(0.90, 0.90),
            end: const Offset(1.0, 1.0),
          ),
        ];

      case RevealAnimationType.flipUp:
        return [
          FadeEffect(
            duration: duration,
            delay: delay,
            curve: curve,
            begin: 0.0,
            end: 1.0,
          ),
          SlideEffect(
            duration: duration,
            delay: delay,
            curve: curve,
            begin: Offset(0, offset * 0.7),
            end: Offset.zero,
          ),
          FlipEffect(
            duration: duration,
            delay: delay,
            curve: curve,
            begin: 0.15,
            end: 0,
            direction: Axis.horizontal,
          ),
        ];

      case RevealAnimationType.custom:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = (widget.animateOnce ? _hasTriggered : _isVisible) ? 1.0 : 0.0;

    return VisibilityDetector(
      key: _key,
      onVisibilityChanged: _handleVisibilityChanged,
      child: Animate(
        target: target,
        effects: _buildEffects(),
        child: widget.child,
      ),
    );
  }
}

/// Extension methods on [Widget] for convenient, fluent scroll reveal wrapping.
extension ScrollRevealExtension on Widget {
  /// Wraps any widget in a [ScrollReveal] entrance animation.
  ///
  /// Example:
  /// ```dart
  /// MyCard().scrollReveal(
  ///   type: RevealAnimationType.slideUp,
  ///   delay: 100.ms,
  /// )
  /// ```
  Widget scrollReveal({
    Key? key,
    RevealAnimationType type = RevealAnimationType.slideUp,
    Duration duration = const Duration(milliseconds: 650),
    Duration delay = Duration.zero,
    Curve curve = Curves.easeOutCubic,
    double visibilityThreshold = 0.12,
    bool animateOnce = true,
    double slideOffset = 0.15,
    List<Effect>? customEffects,
    VoidCallback? onVisible,
  }) {
    return ScrollReveal(
      key: key,
      type: type,
      duration: duration,
      delay: delay,
      curve: curve,
      visibilityThreshold: visibilityThreshold,
      animateOnce: animateOnce,
      slideOffset: slideOffset,
      customEffects: customEffects,
      onVisible: onVisible,
      child: this,
    );
  }

  /// Shortcut for Slide Up scroll reveal
  Widget scrollSlideUp({
    Key? key,
    Duration duration = const Duration(milliseconds: 650),
    Duration delay = Duration.zero,
    Curve curve = Curves.easeOutCubic,
    double visibilityThreshold = 0.12,
    bool animateOnce = true,
    double slideOffset = 0.15,
    VoidCallback? onVisible,
  }) {
    return ScrollReveal.slideUp(
      key: key,
      duration: duration,
      delay: delay,
      curve: curve,
      visibilityThreshold: visibilityThreshold,
      animateOnce: animateOnce,
      slideOffset: slideOffset,
      onVisible: onVisible,
      child: this,
    );
  }

  /// Shortcut for Slide Down scroll reveal
  Widget scrollSlideDown({
    Key? key,
    Duration duration = const Duration(milliseconds: 650),
    Duration delay = Duration.zero,
    Curve curve = Curves.easeOutCubic,
    double visibilityThreshold = 0.12,
    bool animateOnce = true,
    double slideOffset = 0.15,
    VoidCallback? onVisible,
  }) {
    return ScrollReveal.slideDown(
      key: key,
      duration: duration,
      delay: delay,
      curve: curve,
      visibilityThreshold: visibilityThreshold,
      animateOnce: animateOnce,
      slideOffset: slideOffset,
      onVisible: onVisible,
      child: this,
    );
  }

  /// Shortcut for Slide in from Left scroll reveal
  Widget scrollSlideRight({
    Key? key,
    Duration duration = const Duration(milliseconds: 650),
    Duration delay = Duration.zero,
    Curve curve = Curves.easeOutCubic,
    double visibilityThreshold = 0.12,
    bool animateOnce = true,
    double slideOffset = 0.15,
    VoidCallback? onVisible,
  }) {
    return ScrollReveal.slideRight(
      key: key,
      duration: duration,
      delay: delay,
      curve: curve,
      visibilityThreshold: visibilityThreshold,
      animateOnce: animateOnce,
      slideOffset: slideOffset,
      onVisible: onVisible,
      child: this,
    );
  }

  /// Shortcut for Slide in from Right scroll reveal
  Widget scrollSlideLeft({
    Key? key,
    Duration duration = const Duration(milliseconds: 650),
    Duration delay = Duration.zero,
    Curve curve = Curves.easeOutCubic,
    double visibilityThreshold = 0.12,
    bool animateOnce = true,
    double slideOffset = 0.15,
    VoidCallback? onVisible,
  }) {
    return ScrollReveal.slideLeft(
      key: key,
      duration: duration,
      delay: delay,
      curve: curve,
      visibilityThreshold: visibilityThreshold,
      animateOnce: animateOnce,
      slideOffset: slideOffset,
      onVisible: onVisible,
      child: this,
    );
  }

  /// Shortcut for Scale Up scroll reveal
  Widget scrollScaleUp({
    Key? key,
    Duration duration = const Duration(milliseconds: 600),
    Duration delay = Duration.zero,
    Curve curve = Curves.easeOutBack,
    double visibilityThreshold = 0.12,
    bool animateOnce = true,
    VoidCallback? onVisible,
  }) {
    return ScrollReveal.scaleUp(
      key: key,
      duration: duration,
      delay: delay,
      curve: curve,
      visibilityThreshold: visibilityThreshold,
      animateOnce: animateOnce,
      onVisible: onVisible,
      child: this,
    );
  }

  /// Shortcut for Pure Fade scroll reveal
  Widget scrollFade({
    Key? key,
    Duration duration = const Duration(milliseconds: 550),
    Duration delay = Duration.zero,
    Curve curve = Curves.easeOut,
    double visibilityThreshold = 0.10,
    bool animateOnce = true,
    VoidCallback? onVisible,
  }) {
    return ScrollReveal.fade(
      key: key,
      duration: duration,
      delay: delay,
      curve: curve,
      visibilityThreshold: visibilityThreshold,
      animateOnce: animateOnce,
      onVisible: onVisible,
      child: this,
    );
  }
}
