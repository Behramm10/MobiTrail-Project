import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';

/// A result card that displays either a **success** or **failure** state with
/// an icon, title, message, status badge, and optional action button.
///
/// The card slides up with a fade-in entrance animation on first build.
///
/// Example usage:
/// ```dart
/// StatusCard(
///   isSuccess: true,
///   title: 'Verification Successful',
///   message: 'Your identity has been confirmed.',
///   statusText: 'VERIFIED',
///   actionText: 'Continue',
///   onAction: () => _proceed(),
/// )
/// ```
class StatusCard extends StatefulWidget {
  /// Whether the card represents a successful result.
  final bool isSuccess;

  /// The headline text (e.g. "Verification Successful").
  final String title;

  /// A supporting description displayed below the title.
  final String message;

  /// Short text shown inside a status badge (e.g. "VERIFIED").
  final String statusText;

  /// Called when the action button is pressed. If `null` no button is shown.
  final VoidCallback? onAction;

  /// Label for the optional action button (e.g. "Continue").
  final String? actionText;

  const StatusCard({
    super.key,
    required this.isSuccess,
    required this.title,
    required this.message,
    required this.statusText,
    this.onAction,
    this.actionText,
  });

  @override
  State<StatusCard> createState() => _StatusCardState();
}

class _StatusCardState extends State<StatusCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: AppConstants.animSlow,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ── Colour helpers ─────────────────────────────────────────────────────
  Color get _accent =>
      widget.isSuccess ? AppColors.success : AppColors.error;

  Color get _accentLight =>
      widget.isSuccess ? AppColors.successLight : AppColors.errorLight;

  Color get _accentDark =>
      widget.isSuccess ? AppColors.successDark : AppColors.errorDark;

  IconData get _icon =>
      widget.isSuccess ? Icons.check_circle_rounded : Icons.error_rounded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(AppConstants.radiusL),
            border: Border.all(
              color: _accent.withValues(alpha: isDark ? 0.4 : 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _accent.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingL,
            vertical: AppConstants.paddingL,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Icon ──────────────────────────────────────────────
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: _accentLight.withValues(alpha: isDark ? 0.15 : 1.0),
                  shape: BoxShape.circle,
                ),
                child: Icon(_icon, size: 40, color: _accent),
              ),

              const SizedBox(height: AppConstants.paddingM),

              // ── Title ─────────────────────────────────────────────
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.textLight : AppColors.textDark,
                ),
              ),

              const SizedBox(height: AppConstants.paddingS),

              // ── Message ───────────────────────────────────────────
              Text(
                widget.message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSubtitle,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: AppConstants.paddingM),

              // ── Status badge ──────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.paddingM,
                  vertical: AppConstants.paddingS,
                ),
                decoration: BoxDecoration(
                  color: _accentLight.withValues(alpha: isDark ? 0.15 : 1.0),
                  borderRadius:
                      BorderRadius.circular(AppConstants.radiusXXL),
                  border: Border.all(
                    color: _accent.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  widget.statusText,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: _accentDark,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),

              // ── Action button ─────────────────────────────────────
              if (widget.onAction != null &&
                  widget.actionText != null) ...[
                const SizedBox(height: AppConstants.paddingL),
                SizedBox(
                  width: double.infinity,
                  height: AppConstants.buttonHeight,
                  child: ElevatedButton(
                    onPressed: widget.onAction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusL),
                      ),
                    ),
                    child: Text(
                      widget.actionText!,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
