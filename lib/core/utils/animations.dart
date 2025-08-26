import 'package:flutter/material.dart';
import 'package:flutter/services.dart' as services;

/// Centralized animations utility for consistent micro-interactions
/// Following Newport's premium brand: subtle, elegant, purposeful
class AppAnimations {
  AppAnimations._();

  // ANIMATION DURATIONS
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration slower = Duration(milliseconds: 800);

  // ANIMATION CURVES
  static const Curve easeOut = Curves.easeOut;
  static const Curve easeIn = Curves.easeIn;
  static const Curve easeInOut = Curves.easeInOut;
  static const Curve bounce = Curves.elasticOut;
  static const Curve premium = Curves.easeOutCubic;

  /// Premium button press animation with haptic feedback
  static void buttonPress({
    required VoidCallback onPressed,
    AppHapticFeedback feedback = AppHapticFeedback.light,
  }) {
    _triggerHaptic(feedback);
    onPressed();
  }

  /// Scale animation for button press
  static Widget pressableScale({
    required Widget child,
    required VoidCallback onPressed,
    double scaleDown = 0.95,
    Duration duration = fast,
    AppHapticFeedback feedback = AppHapticFeedback.light,
  }) {
    return _PressableScale(
      scaleDown: scaleDown,
      duration: duration,
      feedback: feedback,
      onPressed: onPressed,
      child: child,
    );
  }

  /// Staggered list animation
  static Widget staggeredList({
    required Widget child,
    required int index,
    Duration delay = const Duration(milliseconds: 50),
    Duration duration = normal,
    double offset = 50.0,
  }) {
    return _StaggeredAnimation(
      index: index,
      delay: delay,
      duration: duration,
      offset: offset,
      child: child,
    );
  }

  /// Fade in animation
  static Widget fadeIn({
    required Widget child,
    Duration duration = normal,
    Duration delay = Duration.zero,
    Curve curve = easeOut,
  }) {
    return _FadeInAnimation(
      duration: duration,
      delay: delay,
      curve: curve,
      child: child,
    );
  }

  /// Slide from bottom animation
  static Widget slideFromBottom({
    required Widget child,
    Duration duration = normal,
    Duration delay = Duration.zero,
    double offset = 50.0,
    Curve curve = premium,
  }) {
    return _SlideFromBottomAnimation(
      duration: duration,
      delay: delay,
      offset: offset,
      curve: curve,
      child: child,
    );
  }

  /// Skeleton loader animation
  static Widget skeleton({
    required double width,
    required double height,
    BorderRadius? borderRadius,
    Duration duration = const Duration(milliseconds: 1200),
  }) {
    return _SkeletonLoader(
      width: width,
      height: height,
      borderRadius: borderRadius ?? BorderRadius.circular(8),
      duration: duration,
    );
  }

  /// Success ripple animation
  static void showSuccessRipple(BuildContext context) {
    _triggerHaptic(AppHapticFeedback.medium);
    // Additional success animation logic can be added here
  }

  /// Error shake animation
  static void showErrorShake(BuildContext context) {
    _triggerHaptic(AppHapticFeedback.heavy);
    // Additional error animation logic can be added here
  }

  /// Page transition animation
  static PageRouteBuilder premiumPageRoute<T>({
    required Widget child,
    Duration duration = normal,
    RouteTransitionsBuilder? transitionsBuilder,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: transitionsBuilder ?? _defaultPageTransition,
    );
  }

  /// Default page transition
  static Widget _defaultPageTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: premium,
      )),
      child: FadeTransition(
        opacity: animation,
        child: child,
      ),
    );
  }

  /// Helper method to trigger haptic feedback
  static void _triggerHaptic(AppHapticFeedback feedback) {
    switch (feedback) {
      case AppHapticFeedback.light:
        services.HapticFeedback.lightImpact();
        break;
      case AppHapticFeedback.medium:
        services.HapticFeedback.mediumImpact();
        break;
      case AppHapticFeedback.heavy:
        services.HapticFeedback.heavyImpact();
        break;
      case AppHapticFeedback.selection:
        services.HapticFeedback.selectionClick();
        break;
    }
  }
}

/// Enum for haptic feedback types
enum AppHapticFeedback { light, medium, heavy, selection }

/// Pressable scale widget with haptic feedback
class _PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;
  final double scaleDown;
  final Duration duration;
  final AppHapticFeedback feedback;

  const _PressableScale({
    required this.child,
    required this.onPressed,
    required this.scaleDown,
    required this.duration,
    required this.feedback,
  });

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleDown,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AppAnimations.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        AppAnimations._triggerHaptic(widget.feedback);
        widget.onPressed();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: widget.child,
          );
        },
      ),
    );
  }
}

/// Staggered animation widget
class _StaggeredAnimation extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration delay;
  final Duration duration;
  final double offset;

  const _StaggeredAnimation({
    required this.child,
    required this.index,
    required this.delay,
    required this.duration,
    required this.offset,
  });

  @override
  State<_StaggeredAnimation> createState() => _StaggeredAnimationState();
}

class _StaggeredAnimationState extends State<_StaggeredAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AppAnimations.easeOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, widget.offset),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AppAnimations.premium,
    ));

    // Start animation with staggered delay
    Future.delayed(widget.delay * widget.index, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: _slideAnimation.value,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: widget.child,
          ),
        );
      },
    );
  }
}

/// Fade in animation widget
class _FadeInAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final Curve curve;

  const _FadeInAnimation({
    required this.child,
    required this.duration,
    required this.delay,
    required this.curve,
  });

  @override
  State<_FadeInAnimation> createState() => _FadeInAnimationState();
}

class _FadeInAnimationState extends State<_FadeInAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));

    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: widget.child,
        );
      },
    );
  }
}

/// Slide from bottom animation widget
class _SlideFromBottomAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final double offset;
  final Curve curve;

  const _SlideFromBottomAnimation({
    required this.child,
    required this.duration,
    required this.delay,
    required this.offset,
    required this.curve,
  });

  @override
  State<_SlideFromBottomAnimation> createState() => _SlideFromBottomAnimationState();
}

class _SlideFromBottomAnimationState extends State<_SlideFromBottomAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, widget.offset),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AppAnimations.easeOut,
    ));

    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: _slideAnimation.value,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: widget.child,
          ),
        );
      },
    );
  }
}

/// Skeleton loader widget
class _SkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;
  final Duration duration;

  const _SkeletonLoader({
    required this.width,
    required this.height,
    required this.borderRadius,
    required this.duration,
  });

  @override
  State<_SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<_SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.grey.shade300,
                Colors.grey.shade100,
                Colors.grey.shade300,
              ],
              stops: [
                0.0,
                _animation.value,
                1.0,
              ],
            ),
          ),
        );
      },
    );
  }
} 