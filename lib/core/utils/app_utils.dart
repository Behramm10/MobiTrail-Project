import 'package:flutter/material.dart';

/// Utility helpers for the MobiTrail application.
class AppUtils {
  AppUtils._();

  // ─── NAVIGATION ──────────────────────────────────────────────────────────────

  /// Push a new screen with a smooth Material page transition.
  static Future<T?> navigateTo<T>(BuildContext context, Widget page) {
    return Navigator.push<T>(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  /// Replace the current screen (no back navigation).
  static Future<T?> navigateReplace<T>(BuildContext context, Widget page) {
    return Navigator.pushReplacement<T, dynamic>(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  /// Clear entire navigation stack and push a new screen (e.g., logout).
  static Future<T?> navigateClearStack<T>(BuildContext context, Widget page) {
    return Navigator.pushAndRemoveUntil<T>(
      context,
      MaterialPageRoute(builder: (_) => page),
      (route) => false,
    );
  }

  // ─── RESPONSIVE ──────────────────────────────────────────────────────────────

  /// Returns screen width.
  static double screenWidth(BuildContext context) =>
      MediaQuery.of(context).size.width;

  /// Returns screen height.
  static double screenHeight(BuildContext context) =>
      MediaQuery.of(context).size.height;

  /// Returns true if the device is in landscape mode.
  static bool isLandscape(BuildContext context) =>
      MediaQuery.of(context).orientation == Orientation.landscape;

  /// Returns true if the screen width qualifies as a tablet (>=600dp).
  static bool isTablet(BuildContext context) => screenWidth(context) >= 600;

  // ─── KEYBOARD ────────────────────────────────────────────────────────────────

  /// Dismiss the on-screen keyboard.
  static void hideKeyboard(BuildContext context) {
    FocusScope.of(context).unfocus();
  }

  // ─── DATE / TIME ─────────────────────────────────────────────────────────────

  /// Format a [DateTime] as a human-readable date string.
  static String formatDate(DateTime dt) {
    return '${_dayOfWeek(dt.weekday)}, ${dt.day} ${_monthName(dt.month)} ${dt.year}';
  }

  /// Format a [DateTime] as a human-readable time string.
  static String formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $period';
  }

  static String _dayOfWeek(int day) {
    const days = [
      'Mon', 'Tue', 'Wed', 'Thu',
      'Fri', 'Sat', 'Sun',
    ];
    return days[day - 1];
  }

  static String _monthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return months[month - 1];
  }

  // ─── VALIDATION ──────────────────────────────────────────────────────────────

  /// Validates that a name field is non-empty and has at least 2 characters.
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Full name is required';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }

  /// Validates that an employee ID field is non-empty and at least 3 characters.
  static String? validateEmployeeId(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Employee ID is required';
    }
    if (value.trim().length < 3) {
      return 'Employee ID must be at least 3 characters';
    }
    return null;
  }

  // ─── SNACKBAR ────────────────────────────────────────────────────────────────

  /// Show a themed snackbar message.
  static void showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
    Duration duration = const Duration(seconds: 3),
  }) {
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: isError
              ? theme.colorScheme.error
              : theme.colorScheme.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: duration,
          margin: const EdgeInsets.all(16),
        ),
      );
  }
}
