import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';

/// A reusable camera preview widget that handles initialisation, permissions,
/// error states, and cleanup.
///
/// On devices without a camera (e.g. emulators) a dark placeholder with a
/// camera icon is shown so the rest of the UI can still be exercised.
///
/// Example usage:
/// ```dart
/// CameraPreviewWidget(
///   onCameraReady: (controller) {
///     // controller is ready – start streaming / capture frames
///   },
///   showOverlay: true,
/// )
/// ```
class CameraPreviewWidget extends StatefulWidget {
  /// Called once the [CameraController] has been initialised and is ready
  /// for use (e.g. frame streaming).
  final Function(CameraController)? onCameraReady;

  /// Whether to apply the rounded-corner clip overlay.
  final bool showOverlay;

  /// The accent colour used for loading indicators and border highlights.
  final Color overlayColor;

  const CameraPreviewWidget({
    super.key,
    this.onCameraReady,
    this.showOverlay = true,
    this.overlayColor = AppColors.primary,
  });

  @override
  State<CameraPreviewWidget> createState() => _CameraPreviewWidgetState();
}

class _CameraPreviewWidgetState extends State<CameraPreviewWidget>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isInitialising = true;
  String? _errorMessage;
  bool _isCameraActionInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeCameraSync();
    super.dispose();
  }

  void _disposeCameraSync() {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      controller.dispose();
    }
  }

  /// React to app lifecycle changes – re-initialise after resume.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null) return;

    if (state == AppLifecycleState.inactive) {
      _disposeCamera();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  // ─── Camera lifecycle ──────────────────────────────────────────────────

  Future<void> _initCamera() async {
    if (_isCameraActionInProgress) return;
    _isCameraActionInProgress = true;

    setState(() {
      _isInitialising = true;
      _errorMessage = null;
    });

    try {
      if (_controller != null) {
        await _controller!.dispose();
        _controller = null;
      }

      if (!mounted) {
        _isCameraActionInProgress = false;
        return;
      }

      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        setState(() {
          _isInitialising = false;
          _errorMessage = 'No cameras available on this device.';
        });
        _isCameraActionInProgress = false;
        return;
      }

      // Prefer the front camera for face recognition.
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      if (!mounted) {
        await controller.dispose();
        _isCameraActionInProgress = false;
        return;
      }

      _controller = controller;
      await _controller!.initialize();

      if (!mounted) {
        await _controller?.dispose();
        _controller = null;
        _isCameraActionInProgress = false;
        return;
      }

      setState(() {
        _isInitialising = false;
      });

      // Notify parent that the controller is ready.
      widget.onCameraReady?.call(_controller!);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitialising = false;
          _errorMessage = _mapCameraError(e);
        });
      }
    } finally {
      _isCameraActionInProgress = false;
    }
  }

  Future<void> _disposeCamera() async {
    if (_isCameraActionInProgress) return;
    _isCameraActionInProgress = true;
    try {
      if (_controller != null) {
        await _controller!.dispose();
        _controller = null;
      }
    } catch (e) {
      debugPrint('Error disposing camera: $e');
    } finally {
      _isCameraActionInProgress = false;
    }
  }

  /// Maps common camera exceptions to user-friendly messages.
  String _mapCameraError(dynamic error) {
    if (error is CameraException) {
      switch (error.code) {
        case 'CameraAccessDenied':
        case 'CameraAccessDeniedWithoutPrompt':
        case 'CameraAccessRestricted':
          return 'Camera permission denied. Please grant access in Settings.';
        default:
          return error.description ?? 'Camera error: ${error.code}';
      }
    }
    return 'Unable to initialise the camera.\n$error';
  }

  // ─── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final borderRadius = widget.showOverlay
        ? BorderRadius.circular(AppConstants.radiusL)
        : BorderRadius.zero;

    Widget content;

    if (_isInitialising) {
      content = _buildLoading(context);
    } else if (_errorMessage != null) {
      content = _buildError(context);
    } else if (_controller != null && _controller!.value.isInitialized) {
      content = _buildPreview();
    } else {
      content = _buildPlaceholder(context);
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: content,
    );
  }

  /// Camera preview with correct aspect ratio.
  Widget _buildPreview() {
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _controller!.value.previewSize!.height,
          height: _controller!.value.previewSize!.width,
          child: CameraPreview(_controller!),
        ),
      ),
    );
  }

  /// Loading indicator while the camera initialises.
  Widget _buildLoading(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? AppColors.surfaceDark : AppColors.grey100,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor:
                  AlwaysStoppedAnimation<Color>(widget.overlayColor),
              strokeWidth: 2.5,
            ),
            const SizedBox(height: AppConstants.paddingM),
            Text(
              'Initialising camera…',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textMuted,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  /// Error state with retry option.
  Widget _buildError(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      color: isDark ? AppColors.surfaceDark : AppColors.grey100,
      padding: const EdgeInsets.all(AppConstants.paddingL),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Fallback camera icon on a dark circle – useful on emulators.
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.grey800
                    : AppColors.grey300,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.camera_alt_outlined,
                size: 40,
                color: isDark
                    ? AppColors.textMutedDark
                    : AppColors.textSubtitle,
              ),
            ),
            const SizedBox(height: AppConstants.paddingM),
            Text(
              'Camera Unavailable',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textLight : AppColors.textDark,
              ),
            ),
            const SizedBox(height: AppConstants.paddingS),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppConstants.paddingL),
            TextButton.icon(
              onPressed: _initCamera,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: TextButton.styleFrom(
                foregroundColor: widget.overlayColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Static placeholder shown when no camera is detected (emulators).
  Widget _buildPlaceholder(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? AppColors.backgroundDark : AppColors.grey900,
      child: Center(
        child: Icon(
          Icons.camera_alt_rounded,
          size: 64,
          color: AppColors.grey600.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
