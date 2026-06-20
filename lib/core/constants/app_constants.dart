/// MobiTrail Application Constants
class AppConstants {
  AppConstants._();

  // ─── APP INFO ────────────────────────────────────────────────────────────────
  static const String appName = 'MobiTrail';
  static const String appTagline = 'Face Attendance System';
  static const String appVersion = '1.0.0';
  static const String companyName = 'MobiTrail Technologies';
  static const String attendancePortal = 'Employee Attendance App';
  
  // ─── NETWORK CONFIG ──────────────────────────────────────────────────────────
  // 10.0.2.2 points to localhost from Android Emulator. 
  // Change to server IP for physical device testing.
  static const String apiBaseUrl = 'http://192.168.1.54:8000';

  // ─── ASSET PATHS ─────────────────────────────────────────────────────────────
  static const String logoPath = 'assets/images/mobitrail_logo.png';

  // ─── SPLASH ──────────────────────────────────────────────────────────────────
  static const int splashDurationSeconds = 3;

  // ─── ENROLLMENT ──────────────────────────────────────────────────────────────
  static const int enrollmentFrameCount = 5;
  static const int enrollmentCountdownSeconds = 5;

  // ─── VERIFICATION ────────────────────────────────────────────────────────────
  /// Simulated verification delay in milliseconds
  static const int verificationDelayMs = 3000;

  // ─── MOCK DATA ───────────────────────────────────────────────────────────────
  /// TODO (Backend Integration): Replace with actual API call to verify employee
  static const bool mockEnrolled = true;

  /// TODO (Backend Integration): Replace with actual CNN face verification result
  static const bool mockVerificationSuccess = true;

  // ─── UI SIZING ───────────────────────────────────────────────────────────────
  static const double paddingXS = 4.0;
  static const double paddingS = 8.0;
  static const double paddingM = 16.0;
  static const double paddingL = 24.0;
  static const double paddingXL = 32.0;
  static const double paddingXXL = 48.0;

  static const double radiusS = 8.0;
  static const double radiusM = 12.0;
  static const double radiusL = 16.0;
  static const double radiusXL = 24.0;
  static const double radiusXXL = 32.0;

  static const double buttonHeight = 56.0;
  static const double iconSizeM = 24.0;
  static const double iconSizeL = 32.0;
  static const double iconSizeXL = 48.0;

  // ─── FACE OVAL ───────────────────────────────────────────────────────────────
  static const double ovalWidthFraction = 0.65;
  static const double ovalHeightFraction = 0.80;
  static const double ovalStrokeWidth = 3.0;

  // ─── ANIMATION DURATIONS ─────────────────────────────────────────────────────
  static const Duration animFast = Duration(milliseconds: 200);
  static const Duration animMedium = Duration(milliseconds: 400);
  static const Duration animSlow = Duration(milliseconds: 700);
  static const Duration animVerySlow = Duration(milliseconds: 1000);
}
