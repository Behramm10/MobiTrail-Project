import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../models/employee_model.dart';
import '../../services/enrollment_service.dart';
import '../../widgets/camera_preview_widget.dart';
import '../../widgets/countdown_widget.dart';
import '../../widgets/face_oval_overlay.dart';
import '../../widgets/primary_button.dart';

/// Enrollment phases representing the linear flow through face registration.
enum EnrollmentPhase { positioning, capturing, processing, complete }

/// Face Enrollment screen – walks the employee through capturing multiple face
/// frames, simulates CNN embedding generation, and marks the user as enrolled.
class EnrollScreen extends StatefulWidget {
  const EnrollScreen({super.key});

  @override
  State<EnrollScreen> createState() => _EnrollScreenState();
}

class _EnrollScreenState extends State<EnrollScreen>
    with SingleTickerProviderStateMixin {
  // ─── STATE ──────────────────────────────────────────────────────────────────
  EnrollmentPhase _phase = EnrollmentPhase.positioning;
  int _currentFrame = 0;
  final int _totalFrames = AppConstants.enrollmentFrameCount;
  CameraController? _cameraController;
  String? _capturedImagePath;

  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(
        seconds: AppConstants.enrollmentCountdownSeconds,
      ),
    );
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  // ─── PHASE TRANSITIONS ──────────────────────────────────────────────────────

  /// Start the capture sequence: countdown ➜ frame capture ➜ processing.
  void _startCapture() {
    setState(() {
      _phase = EnrollmentPhase.capturing;
      _currentFrame = 0;
    });
    _progressController.forward(from: 0.0);
    _simulateFrameCapture();
  }

  /// Simulate capturing [_totalFrames] frames at regular intervals.
  Future<void> _simulateFrameCapture() async {
    final intervalMs =
        (AppConstants.enrollmentCountdownSeconds * 1000) ~/ _totalFrames;

    for (int i = 1; i <= _totalFrames; i++) {
      await Future.delayed(Duration(milliseconds: intervalMs));
      if (!mounted) return;

      if (i == _totalFrames) {
        if (_cameraController != null && _cameraController!.value.isInitialized) {
          try {
            final file = await _cameraController!.takePicture();
            _capturedImagePath = file.path;
          } catch (e) {
            debugPrint("Error capturing photo during enrollment: $e");
          }
        }
      }

      setState(() => _currentFrame = i);
    }

    // All frames captured – move to processing.
    if (mounted) _processFrames();
  }

  /// Simulates sending captured frames to the CNN model for embedding
  /// generation.
  Future<void> _processFrames() async {
    setState(() => _phase = EnrollmentPhase.processing);

    final enrollmentService =
        Provider.of<EnrollmentService>(context, listen: false);
    final employeeProvider = Provider.of<EmployeeProvider>(context, listen: false);
    
    final result = await enrollmentService.enrollFace(
      employeeProvider.employee?.employeeId ?? 'unknown',
      _capturedImagePath != null ? [_capturedImagePath] : [],
    );

    if (!mounted) return;

    if (result['success'] == true) {
      setState(() => _phase = EnrollmentPhase.complete);
      // Mark employee as enrolled.
      Provider.of<EmployeeProvider>(context, listen: false).setEnrolled(true);
    } else {
      setState(() => _phase = EnrollmentPhase.positioning);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Enrollment failed.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  /// Return to the dashboard after successful enrollment.
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
        title: const Text('Face Enrollment'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // ── Camera preview with oval overlay ──────────────────────────────
          SizedBox(
            height: screenHeight * 0.60,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Camera feed
                CameraPreviewWidget(
                  onCameraReady: (controller) {
                    _cameraController = controller;
                  },
                ),

                // Face oval guide
                const FaceOvalOverlay(),

                // Instruction text
                Positioned(
                  bottom: AppConstants.paddingXL,
                  left: AppConstants.paddingM,
                  right: AppConstants.paddingM,
                  child: AnimatedOpacity(
                    duration: AppConstants.animMedium,
                    opacity: _phase == EnrollmentPhase.complete ? 0.0 : 1.0,
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

          // ── Phase-specific bottom panel ───────────────────────────────────
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

  /// Builds the content for the current enrollment phase.
  Widget _buildPhaseContent(ThemeData theme, bool isDark) {
    switch (_phase) {
      case EnrollmentPhase.positioning:
        return _buildPositioning(theme);
      case EnrollmentPhase.capturing:
        return _buildCapturing(theme, isDark);
      case EnrollmentPhase.processing:
        return _buildProcessing(theme);
      case EnrollmentPhase.complete:
        return _buildComplete(theme, isDark);
    }
  }

  // ─── PHASE 1: POSITIONING ─────────────────────────────────────────────────

  Widget _buildPositioning(ThemeData theme) {
    return Center(
      key: const ValueKey('positioning'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.paddingL,
          vertical: AppConstants.paddingM,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
              text: 'Start Capture',
              onPressed: _startCapture,
              icon: Icons.camera_alt_rounded,
            ),
          ],
        ),
      ),
    );
  }

  // ─── PHASE 2: CAPTURING ───────────────────────────────────────────────────

  Widget _buildCapturing(ThemeData theme, bool isDark) {
    final progress = _totalFrames > 0 ? _currentFrame / _totalFrames : 0.0;

    return Center(
      key: const ValueKey('capturing'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.paddingL,
          vertical: AppConstants.paddingM,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Capturing Frames',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppConstants.paddingM),

            // Countdown widget
            CountdownWidget(
              from: AppConstants.enrollmentCountdownSeconds,
              onComplete: () {
                // Frame capture handles the transition; countdown is visual-only.
              },
            ),
            const SizedBox(height: AppConstants.paddingM),

            // Frame progress text
            Text(
              'Frame $_currentFrame of $_totalFrames',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppConstants.paddingM),

            // Animated progress bar
            AnimatedBuilder(
              animation: _progressAnimation,
              builder: (context, child) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(AppConstants.radiusS),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: isDark
                        ? AppColors.surfaceDark2
                        : AppColors.grey200,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ─── PHASE 3: PROCESSING ─────────────────────────────────────────────────

  Widget _buildProcessing(ThemeData theme) {
    return Center(
      key: const ValueKey('processing'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.paddingL,
          vertical: AppConstants.paddingM,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
              'Processing...',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppConstants.paddingS),
            Text(
              'Generating face embeddings. Please wait.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSubtitle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── PHASE 4: COMPLETE ───────────────────────────────────────────────────

  Widget _buildComplete(ThemeData theme, bool isDark) {
    return Center(
      key: const ValueKey('complete'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.paddingL,
          vertical: AppConstants.paddingM,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Success icon
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.successLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 40,
                color: AppColors.successDark,
              ),
            ),
            const SizedBox(height: AppConstants.paddingL),
            Text(
              'Enrollment Successful',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.success,
              ),
            ),
            const SizedBox(height: AppConstants.paddingS),
            Text(
              'Your face has been registered successfully.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSubtitle,
              ),
            ),
            const SizedBox(height: AppConstants.paddingXL),
            PrimaryButton(
              text: 'Back to Dashboard',
              onPressed: _backToDashboard,
              icon: Icons.dashboard_rounded,
            ),
          ],
        ),
      ),
    );
  }
}
