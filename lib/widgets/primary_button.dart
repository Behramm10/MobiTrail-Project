import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';

/// A premium, reusable primary button for the MobiTrail app.
///
/// Supports filled and outlined variants, an optional leading icon,
/// and a loading state with an animated circular indicator.
/// Respects both light and dark themes via [Theme.of(context)].
///
/// Example usage:
/// ```dart
/// PrimaryButton(
///   text: 'Verify',
///   onPressed: () => _handleVerify(),
///   icon: Icons.check,
/// )
/// ```
class PrimaryButton extends StatelessWidget {
  /// The label displayed on the button.
  final String text;

  /// Called when the button is pressed. When `null`, the button is disabled.
  final VoidCallback? onPressed;

  /// When `true`, a [CircularProgressIndicator] replaces the label/icon.
  final bool isLoading;

  /// When `true`, renders an outlined variant instead of filled.
  final bool isOutlined;

  /// An optional icon displayed to the left of the text.
  final IconData? icon;

  /// Optional explicit width. If `null`, the button stretches to fill the
  /// available width.
  final double? width;

  const PrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.icon,
    this.width,
  });

  /// Whether the button should be considered disabled (null callback or loading).
  bool get _isDisabled => onPressed == null || isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final borderRadius = BorderRadius.circular(AppConstants.radiusL);

    // ── Content (icon + text, or spinner) ──────────────────────────────────
    final Widget content = AnimatedSwitcher(
      duration: AppConstants.animFast,
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      child: isLoading
          ? const SizedBox(
              key: ValueKey('loading'),
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Row(
              key: const ValueKey('content'),
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20),
                  const SizedBox(width: AppConstants.paddingS),
                ],
                Text(
                  text,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    color: isOutlined
                        ? AppColors.primary
                        : Colors.white,
                  ),
                ),
              ],
            ),
    );

    // ── Button styles ─────────────────────────────────────────────────────
    final filledStyle = ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      disabledBackgroundColor:
          isDark ? AppColors.grey800 : AppColors.grey300,
      disabledForegroundColor:
          isDark ? AppColors.grey600 : AppColors.grey500,
      elevation: _isDisabled ? 0 : 2,
      shadowColor: AppColors.primary.withValues(alpha: 0.35),
      minimumSize: Size(width ?? double.infinity, AppConstants.buttonHeight),
      shape: RoundedRectangleBorder(borderRadius: borderRadius),
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingL,
      ),
    );

    final outlinedStyle = OutlinedButton.styleFrom(
      foregroundColor: AppColors.primary,
      disabledForegroundColor:
          isDark ? AppColors.grey600 : AppColors.grey500,
      side: BorderSide(
        color: _isDisabled
            ? (isDark ? AppColors.grey700 : AppColors.grey300)
            : AppColors.primary,
        width: 1.5,
      ),
      minimumSize: Size(width ?? double.infinity, AppConstants.buttonHeight),
      shape: RoundedRectangleBorder(borderRadius: borderRadius),
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingL,
      ),
    );

    // ── Build ─────────────────────────────────────────────────────────────
    final Widget button = isOutlined
        ? OutlinedButton(
            onPressed: _isDisabled ? null : onPressed,
            style: outlinedStyle,
            child: content,
          )
        : ElevatedButton(
            onPressed: _isDisabled ? null : onPressed,
            style: filledStyle,
            child: content,
          );

    return AnimatedOpacity(
      opacity: _isDisabled ? 0.65 : 1.0,
      duration: AppConstants.animFast,
      child: SizedBox(
        width: width ?? double.infinity,
        height: AppConstants.buttonHeight,
        child: button,
      ),
    );
  }
}
