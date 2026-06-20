import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../models/employee_model.dart';
import '../../services/verification_service.dart';
import '../../widgets/camera_preview_widget.dart';
import '../../widgets/face_oval_overlay.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/status_card.dart';

/// Verification phases representing the linear flow through identity check.
enum VerificationPhase { positioning, verifying, result }

/// Face Verification screen – captures a single frame, compares it against the
/// stored embedding, and displays a verified / not-verified result with an
/// animated detection box overlay.
class VerifyScreen extends StatefulWidget {
  const VerifyScreen({super.key});

  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen>
    with SingleTickerProviderStateMixin {
  // ─── STATE ──────────────────────────────────────────────────────────────────
  VerificationPhase _phase = VerificationPhase.positioning;
  CameraController? _cameraController;

  /// `null` before the result is available.
  bool? _verificationSuccess;

  late AnimationController _boxAnimController;
  late Animation<double> _boxScaleAnimation;
  late Animation<double> _boxOpacityAnimation;

  @override
  void initState() {
    super.initState();
    _boxAnimController = AnimationController(
      vsync: this,
      duration: AppConstants.animSlow,
    );
    _boxScaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _boxAnimController, curve: Curves.easeOutBack),
    );
    _boxOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _boxAnimController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _boxAnimController.dispose();
    super.dispose();
  }

  // ─── PHASE TRANSITIONS ──────────────────────────────────────────────────────

  Future<void> _startVerification() async {
    final verificationService =
        Provider.of<VerificationService>(context, listen: false);
    final employeeProvider = Provider.of<EmployeeProvider>(context, listen: false);

    setState(() {
      _phase = VerificationPhase.verifying;
      _verificationSuccess = null;
    });

    String? capturedPath;
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      try {
        final file = await _cameraController!.takePicture();
        capturedPath = file.path;
      } catch (e) {
        debugPrint("Error capturing photo during verification: $e");
      }
    }
    
    final result = await verificationService.verifyFace(
      employeeProvider.employee?.employeeId ?? 'unknown', 
      capturedPath
    );
    final success = result['success'] == true;

    if (!mounted) return;

    // TODO (Backend Integration): If verification succeeds, record attendance
    // timestamp in the backend database with employee ID and location data.

    setState(() {
      _phase = VerificationPhase.result;
      _verificationSuccess = success;
    });

    if (success) {
      employeeProvider.setHasTimedIn(true);
    }

    // Animate the detection box appearance.
    _boxAnimController.forward(from: 0.0);
  }

  /// Reset to positioning phase for a retry.
  void _tryAgain() {
    _boxAnimController.reset();
    setState(() {
      _phase = VerificationPhase.positioning;
      _verificationSuccess = null;
    });
  }

  /// Navigate back to the dashboard.
  void _backToDashboard() {
    Navigator.of(context).pop();
  }

  // ─── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Face Verification'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _backToDashboard,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // ── Camera preview with overlay ─────────────────────────────────
          SizedBox(
            height: _phase == VerificationPhase.result
                ? screenHeight * 0.45
                : screenHeight * 0.60,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Camera feed
                CameraPreviewWidget(
                  onCameraReady: (controller) {
                    _cameraController = controller;
                  },
                ),

                // Show oval guide during positioning & verifying, hide on result
                if (_phase != VerificationPhase.result) const FaceOvalOverlay(),

                // Detection box – shown only in result phase
                if (_phase == VerificationPhase.result &&
                    _verificationSuccess != null)
                  _buildDetectionBox(),

                // Instruction text
                Positioned(
                  bottom: AppConstants.paddingXL,
                  left: AppConstants.paddingM,
                  right: AppConstants.paddingM,
                  child: AnimatedOpacity(
                    duration: AppConstants.animMedium,
                    opacity:
                        _phase == VerificationPhase.result ? 0.0 : 1.0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.paddingM,
                        vertical: AppConstants.paddingS,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusXL),
                      ),
                      child: Text(
                        'Align your face inside the oval',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Phase-specific bottom panel ─────────────────────────────────
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppConstants.radiusXL),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: AnimatedSwitcher(
                duration: AppConstants.animMedium,
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: _buildPhaseContent(theme, isDark),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the content for the current verification phase.
  Widget _buildPhaseContent(ThemeData theme, bool isDark) {
    switch (_phase) {
      case VerificationPhase.positioning:
        return _buildPositioning(theme);
      case VerificationPhase.verifying:
        return _buildVerifying(theme);
      case VerificationPhase.result:
        return _buildResult(theme, isDark);
    }
  }

  // ─── PHASE 1: POSITIONING ─────────────────────────────────────────────────

  Widget _buildPositioning(ThemeData theme) {
    return Padding(
      key: const ValueKey('positioning'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingL,
        vertical: AppConstants.paddingL,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.face_rounded,
            size: AppConstants.iconSizeXL,
            color: AppColors.primary,
          ),
          const SizedBox(height: AppConstants.paddingM),
          Text(
            'Position Your Face',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppConstants.paddingS),
          Text(
            'Center your face in the oval above and press Start when ready.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSubtitle,
            ),
          ),
          const SizedBox(height: AppConstants.paddingXL),
          PrimaryButton(
            text: 'Start Verification',
            onPressed: _startVerification,
            icon: Icons.verified_user_rounded,
          ),
        ],
      ),
    );
  }

  // ─── PHASE 2: VERIFYING ───────────────────────────────────────────────────

  Widget _buildVerifying(ThemeData theme) {
    return Padding(
      key: const ValueKey('verifying'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingL,
        vertical: AppConstants.paddingL,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: AppConstants.iconSizeXL,
            height: AppConstants.iconSizeXL,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: AppConstants.paddingL),
          Text(
            'Verifying...',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppConstants.paddingS),
          Text(
            'Comparing face against registered data.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSubtitle,
            ),
          ),
        ],
      ),
    );
  }

  // ─── PHASE 3: RESULT ─────────────────────────────────────────────────────

  Widget _buildResult(ThemeData theme, bool isDark) {
    final isSuccess = _verificationSuccess == true;

    return Padding(
      key: const ValueKey('result'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingL,
        vertical: AppConstants.paddingL,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Status card
          StatusCard(
            isSuccess: isSuccess,
            title: isSuccess ? 'Attendance Marked Successfully' : 'Verification Failed',
            message: isSuccess
                ? 'Your identity has been confirmed and attendance recorded.'
                : 'Face could not be verified. Please try again.',
            statusText: isSuccess ? 'VERIFIED' : 'NOT VERIFIED',
          ),
          const SizedBox(height: AppConstants.paddingL),

          // Action buttons
          if (isSuccess) ...[
            PrimaryButton(
              text: 'Back to Dashboard',
              onPressed: _backToDashboard,
              icon: Icons.dashboard_rounded,
            ),
          ] else ...[
            PrimaryButton(
              text: 'Try Again',
              onPressed: _tryAgain,
              icon: Icons.refresh_rounded,
            ),
            const SizedBox(height: AppConstants.paddingM),
            SizedBox(
              width: double.infinity,
              height: AppConstants.buttonHeight,
              child: OutlinedButton.icon(
                onPressed: _backToDashboard,
                icon: const Icon(Icons.dashboard_rounded),
                label: const Text('Back to Dashboard'),
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      isDark ? AppColors.textLight : AppColors.textDark,
                  side: BorderSide(
                    color: isDark
                        ? AppColors.borderDark
                        : AppColors.borderLight,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusM),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── DETECTION BOX OVERLAY ────────────────────────────────────────────────

  /// Draws an animated green (success) or red (failure) rectangular detection
  /// box centered on the camera preview where a face would typically appear.
  Widget _buildDetectionBox() {
    final isSuccess = _verificationSuccess == true;
    final boxColor = isSuccess ? AppColors.success : AppColors.error;

    return AnimatedBuilder(
      animation: _boxAnimController,
      builder: (context, child) {
        return Center(
          child: FractionalTranslation(
            translation: const Offset(0, -0.05), // slightly above center
            child: Opacity(
              opacity: _boxOpacityAnimation.value,
              child: Transform.scale(
                scale: _boxScaleAnimation.value,
                child: Container(
                  width: MediaQuery.of(context).size.width *
                      AppConstants.ovalWidthFraction *
                      0.85,
                  height: MediaQuery.of(context).size.width *
                      AppConstants.ovalWidthFraction *
                      1.1,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: boxColor,
                      width: AppConstants.ovalStrokeWidth,
                    ),
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusM),
                  ),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      margin: const EdgeInsets.only(
                        bottom: AppConstants.paddingS,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.paddingM,
                        vertical: AppConstants.paddingXS,
                      ),
                      decoration: BoxDecoration(
                        color: boxColor.withValues(alpha: 0.85),
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusS),
                      ),
                      child: Text(
                        isSuccess ? 'VERIFIED' : 'NOT VERIFIED',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
