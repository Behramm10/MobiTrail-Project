import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/app_utils.dart';
import '../../models/employee_model.dart';
import '../../services/attendance_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/camera_preview_widget.dart';
import '../../widgets/face_oval_overlay.dart';

// ─── STATUS ENUMS ────────────────────────────────────────────────────────────

/// Represents the current state of a Time In or Time Out action.
enum ActionStatus {
  notAttempted,
  inProgress,
  approved,
  waitingForApproval,
  rejected,
  notAvailable,
}

// ─── SCREEN ──────────────────────────────────────────────────────────────────

/// Attendance Actions screen – presents Time In / Time Out cards side by side
/// and manages the full clock-in / clock-out lifecycle including camera
/// verification, status badges, and action locking.
class AttendanceActionsScreen extends StatefulWidget {
  const AttendanceActionsScreen({super.key});

  @override
  State<AttendanceActionsScreen> createState() =>
      _AttendanceActionsScreenState();
}

class _AttendanceActionsScreenState extends State<AttendanceActionsScreen>
    with TickerProviderStateMixin {
  // ─── STATE ────────────────────────────────────────────────────────────────

  ActionStatus _timeInStatus = ActionStatus.notAttempted;
  ActionStatus _timeOutStatus = ActionStatus.notAvailable;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Initialize state from EmployeeProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<EmployeeProvider>(context, listen: false);
      final employee = provider.employee;
      if (employee != null) {
        setState(() {
          if (employee.hasTimedIn) {
            _timeInStatus = _mapStringToStatus(employee.timeInStatus);
            if (employee.hasTimedOut) {
              _timeOutStatus = _mapStringToStatus(employee.timeOutStatus);
            } else {
              _timeOutStatus = ActionStatus.notAttempted;
            }
          }
        });
      }
      _checkAndShowTutorial(employee?.employeeId);
    });
  }

  Future<void> _checkAndShowTutorial(String? employeeId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = employeeId != null ? 'skip_reload_tutorial_$employeeId' : 'skip_reload_tutorial';
    final skipTutorial = prefs.getBool(key) ?? false;
    if (!skipTutorial && mounted) {
      _showTutorialDialog(employeeId);
    }
  }

  void _showTutorialDialog(String? employeeId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusL),
          ),
          elevation: 6,
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.paddingL),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(AppConstants.paddingM),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.refresh_rounded,
                      color: AppColors.primary,
                      size: 40,
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.paddingL),
                Text(
                  'Sync Attendance Status',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: AppConstants.paddingM),
                const Text(
                  'Tap the reload button in the top right corner anytime to sync with the database and view your latest Time In and Time Out timestamps.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSubtitle,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppConstants.paddingXL),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final prefs = await SharedPreferences.getInstance();
                          final key = employeeId != null ? 'skip_reload_tutorial_$employeeId' : 'skip_reload_tutorial';
                          await prefs.setBool(key, true);
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textMuted,
                          side: const BorderSide(color: AppColors.grey300),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppConstants.radiusM),
                          ),
                        ),
                        child: const Text(
                          'Skip Forever',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppConstants.paddingM),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppConstants.radiusM),
                          ),
                        ),
                        child: const Text(
                          'Got It',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ─── TIME IN FLOW ─────────────────────────────────────────────────────────

  Future<void> _handleTimeIn() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => const _CameraVerificationPage(actionType: 'Time In'),
      ),
    );

    if (!mounted || result == null) return;

    final statusStr = result['status'] as String?;
    final timeInTime = result['time_in_time'] as String?;
    final timeOutTime = result['time_out_time'] as String?;

    setState(() {
      if (statusStr == 'APPROVED' || statusStr == 'PRESENT' || statusStr == 'LATE') {
        _timeInStatus = ActionStatus.approved;
        _timeOutStatus = ActionStatus.notAttempted; // unlock Time Out
        Provider.of<EmployeeProvider>(context, listen: false).updateAttendance(
          hasTimedIn: true,
          timeInStatus: statusStr,
          timeInTime: timeInTime,
          timeOutTime: timeOutTime,
        );
      } else if (statusStr == 'WAITING_FOR_APPROVAL' || statusStr == 'PENDING_REVIEW') {
        _timeInStatus = ActionStatus.waitingForApproval;
        _timeOutStatus = ActionStatus.notAttempted; // unlock Time Out
        Provider.of<EmployeeProvider>(context, listen: false).updateAttendance(
          hasTimedIn: true,
          timeInStatus: statusStr,
          timeInTime: timeInTime,
          timeOutTime: timeOutTime,
        );
      } else {
        _timeInStatus = ActionStatus.rejected;
      }
    });
  }

  // ─── TIME OUT FLOW ────────────────────────────────────────────────────────

  Future<void> _handleTimeOut() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => const _CameraVerificationPage(actionType: 'Time Out'),
      ),
    );

    if (!mounted || result == null) return;

    final statusStr = result['status'] as String?;
    final timeInTime = result['time_in_time'] as String?;
    final timeOutTime = result['time_out_time'] as String?;

    setState(() {
      if (statusStr == 'APPROVED' || statusStr == 'PRESENT' || statusStr == 'EARLY_LEAVE') {
        _timeOutStatus = ActionStatus.approved;
        Provider.of<EmployeeProvider>(context, listen: false).updateAttendance(
          hasTimedOut: true,
          timeOutStatus: statusStr,
          timeInTime: timeInTime,
          timeOutTime: timeOutTime,
        );
      } else if (statusStr == 'WAITING_FOR_APPROVAL' || statusStr == 'PENDING_REVIEW') {
        _timeOutStatus = ActionStatus.waitingForApproval;
        Provider.of<EmployeeProvider>(context, listen: false).updateAttendance(
          hasTimedOut: true,
          timeOutStatus: statusStr,
          timeInTime: timeInTime,
          timeOutTime: timeOutTime,
        );
      } else {
        _timeOutStatus = ActionStatus.rejected;
      }
    });
  }

  Future<void> _refreshAttendance() async {
    final provider = Provider.of<EmployeeProvider>(context, listen: false);
    final employee = provider.employee;
    if (employee == null) return;

    AppUtils.showSnackBar(context, 'Refreshing attendance status...', duration: const Duration(seconds: 1));

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final response = await authService.login(employee.name, employee.employeeId);

      if (response['success'] == true) {
        final empData = response['employee'];
        provider.login(
          empData['name'],
          empData['employeeId'],
          hasTimedIn: empData['hasTimedIn'] ?? false,
          hasTimedOut: empData['hasTimedOut'] ?? false,
          timeInStatus: empData['timeInStatus'],
          timeOutStatus: empData['timeOutStatus'],
          timeInTime: empData['timeInTime'],
          timeOutTime: empData['timeOutTime'],
        );
        provider.setEnrolled(empData['isEnrolled'] ?? false);
        
        if (mounted) {
          AppUtils.showSnackBar(context, 'Status refreshed successfully!');
        }
      } else {
        if (mounted) {
          AppUtils.showSnackBar(
            context,
            response['message'] ?? 'Refresh failed',
            isError: true,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppUtils.showSnackBar(
          context,
          'Error refreshing status: $e',
          isError: true,
        );
      }
    }
  }

  ActionStatus _mapStringToStatus(String? status) {
    switch (status) {
      case 'APPROVED':
      case 'PRESENT':
      case 'LATE':
        return ActionStatus.approved;
      case 'WAITING_FOR_APPROVAL':
      case 'PENDING_REVIEW':
        return ActionStatus.waitingForApproval;
      case 'REJECTED':
        return ActionStatus.rejected;
      default:
        return ActionStatus.approved;
    }
  }

  // ─── HELPERS ──────────────────────────────────────────────────────────────

  bool get _isTimeInClickable =>
      _timeInStatus == ActionStatus.notAttempted ||
      _timeInStatus == ActionStatus.rejected;

  bool get _isTimeOutClickable =>
      _timeOutStatus == ActionStatus.notAttempted ||
      _timeOutStatus == ActionStatus.rejected;

  // ─── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<EmployeeProvider>(context);
    final employee = provider.employee;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Reactively update statuses if employee data is loaded/updated
    if (employee != null) {
      if (employee.hasTimedIn) {
        _timeInStatus = _mapStringToStatus(employee.timeInStatus);
        if (employee.hasTimedOut) {
          _timeOutStatus = _mapStringToStatus(employee.timeOutStatus);
        } else if (_timeOutStatus == ActionStatus.notAvailable || _timeOutStatus == ActionStatus.notAttempted) {
          if (_timeOutStatus != ActionStatus.rejected) {
            _timeOutStatus = ActionStatus.notAttempted;
          }
        }
      } else {
        if (_timeInStatus != ActionStatus.rejected) {
          _timeInStatus = ActionStatus.notAttempted;
        }
        _timeOutStatus = ActionStatus.notAvailable;
      }
    }

    Widget bodyContent = SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingL),
        child: Column(
          children: [
            // ── Header info ──────────────────────────────────────────
            _buildHeaderInfo(theme, isDark),
            const SizedBox(height: AppConstants.paddingXL),

            // ── Time In / Time Out Cards ─────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // TIME IN
                Expanded(
                  child: _buildActionCard(
                    theme: theme,
                    isDark: isDark,
                    title: 'Time In',
                    icon: Icons.login_rounded,
                    status: _timeInStatus,
                    isClickable: _isTimeInClickable,
                    onTap: _handleTimeIn,
                    accentColor: AppColors.success,
                    employee: employee,
                  ),
                ),
                const SizedBox(width: AppConstants.paddingM),
                // TIME OUT
                Expanded(
                  child: _buildActionCard(
                    theme: theme,
                    isDark: isDark,
                    title: 'Time Out',
                    icon: Icons.logout_rounded,
                    status: _timeOutStatus,
                    isClickable: _isTimeOutClickable,
                    onTap: _handleTimeOut,
                    accentColor: AppColors.primary,
                    employee: employee,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.paddingL),

            // ── Status summary ───────────────────────────────────────
            _buildStatusSummary(theme, isDark),
          ],
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Actions'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refreshAttendance,
            tooltip: 'Refresh Status',
          ),
        ],
      ),
      body: bodyContent,
    );
  }

  // ─── HEADER INFO ──────────────────────────────────────────────────────────

  Widget _buildHeaderInfo(ThemeData theme, bool isDark) {
    final now = DateTime.now();
    final dateStr = AppUtils.formatDate(now);
    final timeStr = AppUtils.formatTime(now);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingL,
        vertical: AppConstants.paddingM,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark2 : AppColors.grey50,
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today_rounded,
            size: 20,
            color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
          ),
          const SizedBox(width: AppConstants.paddingS),
          Expanded(
            child: Text(
              dateStr,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textLight : AppColors.textDark,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppConstants.paddingM),
          Icon(
            Icons.access_time_rounded,
            size: 20,
            color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
          ),
          const SizedBox(width: AppConstants.paddingXS),
          Text(
            timeStr,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textLight : AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }

  // ─── ACTION CARD ──────────────────────────────────────────────────────────

  Widget _buildActionCard({
    required ThemeData theme,
    required bool isDark,
    required String title,
    required IconData icon,
    required ActionStatus status,
    required bool isClickable,
    required VoidCallback onTap,
    required Color accentColor,
    Employee? employee,
  }) {
    final isDisabled = !isClickable;
    final cardColor = isDisabled
        ? (isDark ? AppColors.surfaceDark.withValues(alpha: 0.5) : AppColors.grey100)
        : (isDark ? AppColors.surfaceDark2 : AppColors.surfaceLight);
    final borderColor = _getBorderColorForStatus(status, isDark);
    final iconColor = isDisabled
        ? AppColors.grey400
        : accentColor;

    return AnimatedContainer(
      duration: AppConstants.animMedium,
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isClickable ? onTap : null,
          borderRadius: BorderRadius.circular(AppConstants.radiusXL),
          splashColor: accentColor.withValues(alpha: 0.1),
          highlightColor: accentColor.withValues(alpha: 0.05),
          child: AnimatedContainer(
            duration: AppConstants.animMedium,
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(AppConstants.radiusXL),
              border: Border.all(color: borderColor, width: 2),
              boxShadow: isClickable
                  ? [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppConstants.paddingL, horizontal: AppConstants.paddingM),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ── Icon ──────────────────────────────────────────
                  _buildIconCircle(icon, iconColor, isDisabled, isDark, isClickable),
                  const SizedBox(height: AppConstants.paddingL),

                  // ── Title ─────────────────────────────────────────
                  Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDisabled
                          ? AppColors.grey400
                          : (isDark ? AppColors.textLight : AppColors.textDark),
                    ),
                  ),
                  const SizedBox(height: AppConstants.paddingM),

                  // ── Status badge ──────────────────────────────────
                  _buildStatusBadge(status, theme),

                  // ── Time display below status ──────────────────────
                  _buildTimeDisplay(status, title, theme, isDark, employee),

                  // ── Tap hint ──────────────────────────────────────
                  if (isClickable) ...[
                    const SizedBox(height: AppConstants.paddingM),
                    Text(
                      'Tap to proceed',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeDisplay(ActionStatus status, String title, ThemeData theme, bool isDark, Employee? employee) {
    if (status != ActionStatus.approved && status != ActionStatus.waitingForApproval) {
      return const SizedBox.shrink();
    }
    
    final timeStr = title == 'Time In' ? employee?.timeInTime : employee?.timeOutTime;
    
    if (timeStr == null || timeStr.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Padding(
      padding: const EdgeInsets.only(top: AppConstants.paddingS),
      child: Text(
        timeStr,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.textLight : AppColors.textDark,
        ),
      ),
    );
  }

  Widget _buildIconCircle(
    IconData icon,
    Color iconColor,
    bool isDisabled,
    bool isDark,
    bool isClickable,
  ) {
    final circle = Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDisabled
            ? (isDark ? AppColors.grey800 : AppColors.grey200)
            : iconColor.withValues(alpha: 0.12),
        border: Border.all(
          color: isDisabled
              ? (isDark ? AppColors.grey700 : AppColors.grey300)
              : iconColor.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Icon(icon, size: 28, color: iconColor),
    );

    if (isClickable) {
      return AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: child,
          );
        },
        child: circle,
      );
    }

    return circle;
  }

  // ─── STATUS BADGE ─────────────────────────────────────────────────────────

  Widget _buildStatusBadge(ActionStatus status, ThemeData theme) {
    final (String label, Color bgColor, Color fgColor, IconData icon) =
        switch (status) {
      ActionStatus.notAttempted => (
          'Not Attempted',
          AppColors.grey200,
          AppColors.grey600,
          Icons.radio_button_unchecked_rounded,
        ),
      ActionStatus.inProgress => (
          'Verifying...',
          AppColors.infoLight,
          AppColors.info,
          Icons.hourglass_top_rounded,
        ),
      ActionStatus.approved => (
          'Approved',
          AppColors.successLight,
          AppColors.successDark,
          Icons.check_circle_rounded,
        ),
      ActionStatus.waitingForApproval => (
          'Waiting For Approval',
          AppColors.warningLight,
          const Color(0xFFB45309),
          Icons.pending_rounded,
        ),
      ActionStatus.rejected => (
          'Rejected',
          AppColors.errorLight,
          AppColors.errorDark,
          Icons.cancel_rounded,
        ),
      ActionStatus.notAvailable => (
          'Not Available',
          AppColors.grey200,
          AppColors.grey500,
          Icons.block_rounded,
        ),
    };

    return AnimatedSwitcher(
      duration: AppConstants.animMedium,
      switchInCurve: Curves.easeOutBack,
      child: Container(
        key: ValueKey(status),
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.paddingM,
          vertical: AppConstants.paddingS,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppConstants.radiusXL),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: fgColor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: fgColor,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── STATUS SUMMARY ───────────────────────────────────────────────────────

  Widget _buildStatusSummary(ThemeData theme, bool isDark) {
    String summaryText;
    Color summaryColor;
    IconData summaryIcon;

    if (_timeOutStatus == ActionStatus.approved) {
      summaryText = 'Attendance cycle completed ✓';
      summaryColor = AppColors.success;
      summaryIcon = Icons.verified_rounded;
    } else if (_timeInStatus == ActionStatus.waitingForApproval ||
        _timeOutStatus == ActionStatus.waitingForApproval) {
      summaryText = 'Waiting for admin approval';
      summaryColor = AppColors.warning;
      summaryIcon = Icons.hourglass_bottom_rounded;
    } else if (_timeInStatus == ActionStatus.approved) {
      summaryText = 'Time In approved — proceed with Time Out';
      summaryColor = AppColors.info;
      summaryIcon = Icons.arrow_forward_rounded;
    } else if (_timeInStatus == ActionStatus.rejected) {
      summaryText = 'Time In rejected — please try again';
      summaryColor = AppColors.error;
      summaryIcon = Icons.refresh_rounded;
    } else {
      summaryText = 'Begin by marking your Time In';
      summaryColor = AppColors.textMuted;
      summaryIcon = Icons.touch_app_rounded;
    }

    return AnimatedSwitcher(
      duration: AppConstants.animMedium,
      child: Container(
        key: ValueKey(summaryText),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.paddingL,
          vertical: AppConstants.paddingM,
        ),
        decoration: BoxDecoration(
          color: summaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppConstants.radiusL),
          border: Border.all(
            color: summaryColor.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(summaryIcon, size: 20, color: summaryColor),
            const SizedBox(width: AppConstants.paddingS),
            Flexible(
              child: Text(
                summaryText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: summaryColor,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── COLOR HELPERS ────────────────────────────────────────────────────────

  Color _getBorderColorForStatus(ActionStatus status, bool isDark) {
    return switch (status) {
      ActionStatus.approved => AppColors.success,
      ActionStatus.waitingForApproval => AppColors.warning,
      ActionStatus.rejected => AppColors.error,
      ActionStatus.notAttempted => isDark ? AppColors.borderDark : AppColors.borderLight,
      ActionStatus.inProgress => AppColors.info,
      ActionStatus.notAvailable => isDark ? AppColors.grey700 : AppColors.grey300,
    };
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CAMERA VERIFICATION PAGE (internal to this feature)
// ═══════════════════════════════════════════════════════════════════════════════

/// A simplified camera verification page that captures a face photo,
/// calls the mock [AttendanceService], and returns the result back to
/// [AttendanceActionsScreen] via Navigator.pop().
class _CameraVerificationPage extends StatefulWidget {
  final String actionType; // 'Time In' or 'Time Out'

  const _CameraVerificationPage({required this.actionType});

  @override
  State<_CameraVerificationPage> createState() =>
      _CameraVerificationPageState();
}

class _CameraVerificationPageState extends State<_CameraVerificationPage> {
  CameraController? _cameraController;
  bool _isVerifying = false;
  String? _statusMessage;

  Future<void> _captureAndVerify() async {
    if (_isVerifying) return;

    setState(() {
      _isVerifying = true;
      _statusMessage = 'Capturing and verifying face...';
    });

    String? capturedPath;
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      try {
        final file = await _cameraController!.takePicture();
        capturedPath = file.path;
      } catch (e) {
        debugPrint('Error capturing photo: $e');
      }
    }

    if (!mounted) return;

    final attendanceService =
        Provider.of<AttendanceService>(context, listen: false);
    final employeeProvider =
        Provider.of<EmployeeProvider>(context, listen: false);
    final employeeId = employeeProvider.employee?.employeeId ?? 'unknown';

    Map<String, dynamic> result;
    if (widget.actionType == 'Time In') {
      result = await attendanceService.timeIn(employeeId, capturedPath);
    } else {
      result = await attendanceService.timeOut(employeeId, capturedPath);
    }

    if (!mounted) return;

    final statusStr = result['status'] as String?;
    if (statusStr == 'APPROVED' || statusStr == 'WAITING_FOR_APPROVAL') {
      // Success! Pop back to the AttendanceActionsScreen with the result
      Navigator.of(context).pop(result);
    } else {
      // Failure or connection error. Stay on screen and allow retry.
      setState(() {
        _isVerifying = false;
        _statusMessage = result['message'] ?? 'Verification failed. Please try again.';
      });
      AppUtils.showSnackBar(context, _statusMessage!, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(widget.actionType),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // ── Camera Preview ────────────────────────────────────────
          SizedBox(
            height: screenHeight * 0.60,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CameraPreviewWidget(
                  onCameraReady: (controller) {
                    _cameraController = controller;
                  },
                ),
                const FaceOvalOverlay(),
                Positioned(
                  bottom: AppConstants.paddingXL,
                  left: AppConstants.paddingM,
                  right: AppConstants.paddingM,
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
                      _isVerifying
                          ? 'Verifying your face...'
                          : 'Align your face inside the oval',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Bottom Panel ─────────────────────────────────────────
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark
                    ? AppColors.surfaceDark
                    : AppColors.surfaceLight,
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
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.paddingL),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isVerifying) ...[
                      const SizedBox(
                        width: 48,
                        height: 48,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.primary),
                        ),
                      ),
                      const SizedBox(height: AppConstants.paddingL),
                      Text(
                        _statusMessage ?? 'Processing...',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ] else ...[
                      Icon(
                        widget.actionType == 'Time In'
                            ? Icons.login_rounded
                            : Icons.logout_rounded,
                        size: AppConstants.iconSizeXL,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: AppConstants.paddingM),
                      Text(
                        'Ready for ${widget.actionType}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppConstants.paddingS),
                      if (_statusMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppConstants.paddingM,
                            vertical: AppConstants.paddingS,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.errorLight.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppConstants.radiusS),
                            border: Border.all(
                              color: AppColors.errorLight.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            _statusMessage!,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.errorDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ] else ...[
                        Text(
                          'Center your face in the oval and tap the button below.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSubtitle,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppConstants.paddingXL),
                      SizedBox(
                        width: double.infinity,
                        height: AppConstants.buttonHeight,
                        child: ElevatedButton.icon(
                          onPressed: _captureAndVerify,
                          icon: const Icon(Icons.camera_alt_rounded),
                          label: Text(
                            'Verify ${widget.actionType}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppConstants.radiusM),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
