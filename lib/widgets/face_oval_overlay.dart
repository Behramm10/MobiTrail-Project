import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';

/// A face-guide overlay that draws an oval cutout in the centre of the
/// available space. The area outside the oval is darkened so the camera
/// feed shows through the oval only.
///
/// Features:
/// - Animated pulsing border around the oval
/// - Optional animated scan line sweeping vertically
/// - Optional instruction text rendered below the oval
/// - Optional detection-box overlay (green / red) when a face is detected
///
/// Example usage:
/// ```dart
/// FaceOvalOverlay(
///   borderColor: AppColors.success,
///   showScanLine: true,
///   instruction: 'Position your face inside the oval',
/// )
/// ```
class FaceOvalOverlay extends StatefulWidget {
  /// The colour of the oval border.
  final Color borderColor;

  /// The stroke width of the oval border.
  final double strokeWidth;

  /// Whether an animated scan-line sweeps vertically inside the oval.
  final bool showScanLine;

  /// Optional instructional text shown below the oval.
  final String? instruction;

  /// When non-null, a detection box of this colour is drawn over the oval.
  final Color? detectionBoxColor;

  const FaceOvalOverlay({
    super.key,
    this.borderColor = AppColors.primary,
    this.strokeWidth = 3.0,
    this.showScanLine = false,
    this.instruction,
    this.detectionBoxColor,
  });

  @override
  State<FaceOvalOverlay> createState() => _FaceOvalOverlayState();
}

class _FaceOvalOverlayState extends State<FaceOvalOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  late final AnimationController _scanController;
  late final Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();

    // ── Pulse animation for the oval border ──────────────────────────────
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // ── Scan-line animation ──────────────────────────────────────────────
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.easeInOut),
    );

    if (widget.showScanLine) {
      _scanController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant FaceOvalOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showScanLine && !_scanController.isAnimating) {
      _scanController.repeat();
    } else if (!widget.showScanLine && _scanController.isAnimating) {
      _scanController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnimation, _scanAnimation]),
      builder: (context, _) {
        return CustomPaint(
          painter: _FaceOvalPainter(
            borderColor: widget.borderColor,
            strokeWidth: widget.strokeWidth,
            pulseValue: _pulseAnimation.value,
            scanProgress:
                widget.showScanLine ? _scanAnimation.value : null,
            detectionBoxColor: widget.detectionBoxColor,
          ),
          child: _buildInstruction(context),
        );
      },
    );
  }

  /// Renders the optional instruction text below the oval area.
  Widget _buildInstruction(BuildContext context) {
    if (widget.instruction == null) return const SizedBox.expand();

    return SizedBox.expand(
      child: Column(
        children: [
          // Push instruction below the oval
          // Oval occupies ~80 % of height, centred → bottom edge at ~90 %
          const Spacer(flex: 92),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.paddingXL,
            ),
            child: Text(
              widget.instruction!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    shadows: const [
                      Shadow(
                        blurRadius: 4,
                        color: Colors.black54,
                      ),
                    ],
                  ),
            ),
          ),
          const Spacer(flex: 8),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Custom Painter
// ═══════════════════════════════════════════════════════════════════════════════

class _FaceOvalPainter extends CustomPainter {
  final Color borderColor;
  final double strokeWidth;
  final double pulseValue;
  final double? scanProgress;
  final Color? detectionBoxColor;

  _FaceOvalPainter({
    required this.borderColor,
    required this.strokeWidth,
    required this.pulseValue,
    this.scanProgress,
    this.detectionBoxColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final ovalWidth = size.width * AppConstants.ovalWidthFraction;
    final ovalHeight = size.height * AppConstants.ovalHeightFraction;

    final ovalRect = Rect.fromCenter(
      center: center,
      width: ovalWidth,
      height: ovalHeight,
    );

    // ── 1. Darkened overlay with oval cut-out ────────────────────────────
    final overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(ovalRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(
      overlayPath,
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );

    // ── 2. Dashed oval border with pulse ─────────────────────────────────
    _drawDashedOval(canvas, ovalRect);

    // ── 3. Optional scan line ────────────────────────────────────────────
    if (scanProgress != null) {
      _drawScanLine(canvas, ovalRect);
    }

    // ── 4. Optional detection box ────────────────────────────────────────
    if (detectionBoxColor != null) {
      _drawDetectionBox(canvas, ovalRect);
    }
  }

  /// Draws a dashed oval border with pulsing opacity.
  void _drawDashedOval(Canvas canvas, Rect ovalRect) {
    final paint = Paint()
      ..color = borderColor.withValues(alpha: pulseValue)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const int dashCount = 60;
    const double gapFraction = 0.35;
    const double dashAngle =
        (2 * math.pi) / dashCount * (1 - gapFraction);
    const double gapAngle = (2 * math.pi) / dashCount * gapFraction;

    final path = Path();
    double currentAngle = -math.pi / 2; // start at top

    for (int i = 0; i < dashCount; i++) {
      path.addArc(ovalRect, currentAngle, dashAngle);
      currentAngle += dashAngle + gapAngle;
    }

    canvas.drawPath(path, paint);

    // Subtle outer glow
    final glowPaint = Paint()
      ..color = borderColor.withValues(alpha: pulseValue * 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    canvas.drawOval(ovalRect, glowPaint);
  }

  /// Draws a horizontal scan line sweeping vertically inside the oval.
  void _drawScanLine(Canvas canvas, Rect ovalRect) {
    final y = ovalRect.top + ovalRect.height * scanProgress!;

    // Calculate horizontal extent of the oval at the current y
    final relY = (y - ovalRect.center.dy) / (ovalRect.height / 2);
    if (relY.abs() > 1.0) return;

    final halfWidth =
        (ovalRect.width / 2) * math.sqrt(1 - relY * relY);
    final x1 = ovalRect.center.dx - halfWidth;
    final x2 = ovalRect.center.dx + halfWidth;

    final scanPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          borderColor.withValues(alpha: 0.0),
          borderColor.withValues(alpha: 0.6),
          borderColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTRB(x1, y - 1, x2, y + 1));

    canvas.drawLine(Offset(x1, y), Offset(x2, y), scanPaint..strokeWidth = 2);
  }

  /// Draws a rounded-rectangle detection box inside the oval.
  void _drawDetectionBox(Canvas canvas, Rect ovalRect) {
    final boxRect = ovalRect.deflate(ovalRect.width * 0.08);
    final rrect = RRect.fromRectAndRadius(
      boxRect,
      const Radius.circular(AppConstants.radiusM),
    );

    final boxPaint = Paint()
      ..color = detectionBoxColor!.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawRRect(rrect, boxPaint);

    // Corner accents
    _drawCornerAccents(canvas, boxRect, detectionBoxColor!);
  }

  /// Small L-shaped corner accents to reinforce the detection-box feel.
  void _drawCornerAccents(Canvas canvas, Rect rect, Color color) {
    const double len = 20;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    // Top-left
    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(len, 0), paint);
    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(0, len), paint);

    // Top-right
    canvas.drawLine(rect.topRight, rect.topRight + const Offset(-len, 0), paint);
    canvas.drawLine(rect.topRight, rect.topRight + const Offset(0, len), paint);

    // Bottom-left
    canvas.drawLine(
        rect.bottomLeft, rect.bottomLeft + const Offset(len, 0), paint);
    canvas.drawLine(
        rect.bottomLeft, rect.bottomLeft + const Offset(0, -len), paint);

    // Bottom-right
    canvas.drawLine(
        rect.bottomRight, rect.bottomRight + const Offset(-len, 0), paint);
    canvas.drawLine(
        rect.bottomRight, rect.bottomRight + const Offset(0, -len), paint);
  }

  @override
  bool shouldRepaint(covariant _FaceOvalPainter oldDelegate) {
    return oldDelegate.pulseValue != pulseValue ||
        oldDelegate.scanProgress != scanProgress ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.detectionBoxColor != detectionBoxColor;
  }
}


