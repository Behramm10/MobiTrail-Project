import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/app_utils.dart';
import '../../models/employee_model.dart';
import '../../services/auth_service.dart';
import '../enroll/enroll_screen.dart';
import '../login/login_screen.dart';
import '../attendance/attendance_actions_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Future<void> _handleLogout(BuildContext context) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final employeeProvider = Provider.of<EmployeeProvider>(context, listen: false);

    await authService.logout();
    employeeProvider.logout();
    
    if (!context.mounted) return;
    AppUtils.navigateClearStack(context, const LoginScreen());
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EmployeeProvider>(
      builder: (context, provider, child) {
        final employee = provider.employee;
        final isEnrolled = provider.isEnrolled;

        if (employee == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        return Scaffold(
          appBar: AppBar(
            leading: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Image.asset(AppConstants.logoPath),
            ),
            title: const Text('Dashboard'),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout_rounded),
                onPressed: () => _handleLogout(context),
                tooltip: 'Logout',
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppConstants.paddingL),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Card
                _buildHeaderCard(context, employee.name, employee.employeeId),
                const SizedBox(height: AppConstants.paddingL),

                // State-dependent content (Enrolled vs Not Enrolled)
                if (!isEnrolled) ...[
                  _buildNotEnrolledState(context),
                ] else ...[
                  _buildEnrolledState(context),
                  const SizedBox(height: AppConstants.paddingL),
                  _buildSummaryCard(context, provider.hasTimedIn),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderCard(BuildContext context, String name, String empId) {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingM),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: AppColors.primary,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: AppConstants.paddingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.titleLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ID: $empId',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Active',
                style: TextStyle(
                  color: AppColors.successDark,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotEnrolledState(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        side: const BorderSide(color: AppColors.primary, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingL),
        child: Column(
          children: [
            const Icon(Icons.face_retouching_natural_rounded, size: 64, color: AppColors.primary),
            const SizedBox(height: AppConstants.paddingM),
            Text(
              'Face Enrollment Required',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.paddingS),
            Text(
              'You need to register your face data before you can mark attendance.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.paddingL),
            ElevatedButton.icon(
              onPressed: () => AppUtils.navigateTo(context, const EnrollScreen()),
              icon: const Icon(Icons.camera_alt_rounded),
              label: const Text('Enroll Face Now'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                minimumSize: const Size(double.infinity, AppConstants.buttonHeight),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnrolledState(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(
          child: Chip(
            avatar: Icon(Icons.check_circle_rounded, color: AppColors.successDark, size: 18),
            label: Text('Face Enrolled'),
            backgroundColor: AppColors.successLight,
            labelStyle: TextStyle(color: AppColors.successDark, fontWeight: FontWeight.bold),
            side: BorderSide.none,
          ),
        ),
        const SizedBox(height: AppConstants.paddingL),
        
        ElevatedButton.icon(
          onPressed: () => AppUtils.navigateTo(context, const AttendanceActionsScreen()),
          icon: const Icon(Icons.face_retouching_natural_rounded, size: 28),
          label: const Text('Verify Attendance', style: TextStyle(fontSize: 18)),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 64),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusL),
            ),
          ),
        ),
        const SizedBox(height: AppConstants.paddingM),
        
        OutlinedButton.icon(
          onPressed: () => AppUtils.navigateTo(context, const EnrollScreen()),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Re-Enroll Face'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, AppConstants.buttonHeight),
            foregroundColor: AppColors.textDark,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(BuildContext context, bool isAttendanceMarked) {
    final theme = Theme.of(context);
    final todayStr = DateFormat('d MMMM y').format(DateTime.now());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Attendance Status',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textSubtitle,
              ),
            ),
            const SizedBox(height: AppConstants.paddingM),
            if (isAttendanceMarked) ...[
              Text(
                '🟢 Present',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                ),
              ),
            ] else ...[
              Text(
                'Not Marked Yet',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSubtitle,
                ),
              ),
            ],
            const SizedBox(height: AppConstants.paddingM),
            Text(
              'Date: $todayStr',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
