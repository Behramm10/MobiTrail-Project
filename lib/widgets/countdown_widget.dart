import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';

/// An animated countdown widget that displays numbers counting down from
/// [from] to 1 and then calls [onComplete].
///
/// Each number pops in with a scale-up + fade animation, accompanied by
/// a circular progress ring that shrinks per tick.
///
/// Example usage:
/// ```dart
/// CountdownWidget(
///   from: 5,
///   onComplete: () => _startCapture(),
///   color: AppColors.primary,
/// )
/// ```
class CountdownWidget extends StatefulWidget {
  /// The number to start counting down from (inclusive).
  final int from;

  /// Called once the countdown reaches zero.
  final VoidCallback onComplete;

  /// Optional accent colour for the number and progress ring.
  /// Defaults to [AppColors.primary].
  final Color? color;

  const CountdownWidget({
    super.key,
    required this.from,
    required this.onComplete,
    this.color,
  });

  @override
  State<CountdownWidget> createState() => _CountdownWidgetState();
}

class _CountdownWidgetState extends State<CountdownWidget>
    with TickerProviderStateMixin {
  late int _currentNumber;

  /// Controls the 1-second tick and also drives the ring progress.
  late AnimationController _tickController;

  /// Scale animation – pops in large then settles.
  late Animation<double> _scaleAnimation;

  /// Fade animation – fades in quickly.
  late Animation<double> _fadeAnimation;

  Color get _color => widget.color ?? AppColors.primary;

  @override
  void initState() {
    super.initState();
    _currentNumber = widget.from;
    _initTickController();
    _tickController.forward();
  }

  void _initTickController() {
    _tickController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..addStatusListener(_onTickComplete);

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.3)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.3, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 65,
      ),
    ]).animate(_tickController);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _tickController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
      ),
    );
  }

  void _onTickComplete(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;

    if (_currentNumber <= 1) {
      widget.onComplete();
      return;
    }

    setState(() {
      _currentNumber--;
    });

    _tickController.reset();
    _tickController.forward();
  }

  @override
  void dispose() {
    _tickController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _tickController,
      builder: (context, _) {
        // Overall progress: 0.0 → 1.0 across the entire countdown.
        final double overallProgress =
            (widget.from - _currentNumber + _tickController.value) /
                widget.from;

        return SizedBox(
          width: 160,
          height: 160,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // ── Background ring ───────────────────────────────────
              CustomPaint(
                size: const Size(160, 160),
                painter: _ProgressRingPainter(
                  progress: 1.0 - overallProgress,
                  color: _color,
                  trackColor: isDark
                      ? AppColors.grey800
                      : AppColors.grey200,
                  strokeWidth: 5,
                ),
              ),

              // ── Number ────────────────────────────────────────────
              FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Text(
                    '$_currentNumber',
                    style: theme.textTheme.displayLarge?.copyWith(
                      fontSize: 64,
                      fontWeight: FontWeight.w700,
                      color: _color,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Progress Ring Painter
// ═══════════════════════════════════════════════════════════════════════════════

class _ProgressRingPainter extends CustomPainter {
  final double progress; // 1.0 → full ring, 0.0 → empty
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  _ProgressRingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Track (full circle, muted)
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Active arc
    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // start at 12 o'clock
      sweepAngle,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}


