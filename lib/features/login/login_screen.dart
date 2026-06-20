import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/app_utils.dart';
import '../../models/employee_model.dart';
import '../../services/auth_service.dart';
import '../../widgets/primary_button.dart';
import '../dashboard/dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _employeeIdController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _employeeIdController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    AppUtils.hideKeyboard(context);

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final employeeProvider = Provider.of<EmployeeProvider>(context, listen: false);

      // TODO (Backend Integration): Replace with actual API authentication
      final response = await authService.login(
        _nameController.text.trim().toUpperCase(),
        _employeeIdController.text.trim(),
      );

      if (response['success'] == true) {
        final empData = response['employee'];
        employeeProvider.login(
          empData['name'],
          empData['employeeId'],
          hasTimedIn: empData['hasTimedIn'] ?? false,
          hasTimedOut: empData['hasTimedOut'] ?? false,
          timeInStatus: empData['timeInStatus'],
          timeOutStatus: empData['timeOutStatus'],
          timeInTime: empData['timeInTime'],
          timeOutTime: empData['timeOutTime'],
        );
        employeeProvider.setEnrolled(empData['isEnrolled'] ?? false);

        if (!mounted) return;
        AppUtils.navigateReplace(context, const DashboardScreen());
      } else {
        if (!mounted) return;
        AppUtils.showSnackBar(
          context,
          response['message'] ?? 'Login failed',
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppUtils.showSnackBar(
        context,
        'An error occurred. Please try again.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => AppUtils.hideKeyboard(context),
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppConstants.paddingL),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset(
                    AppConstants.logoPath,
                    height: 100,
                  ),
                  const SizedBox(height: AppConstants.paddingXL),
                  Text(
                    'Welcome',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displaySmall,
                  ),
                  const SizedBox(height: AppConstants.paddingXS),
                  Text(
                    AppConstants.attendancePortal,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppConstants.paddingXL),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppConstants.paddingL),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _nameController,
                              keyboardType: TextInputType.name,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.person_outline),
                                labelText: 'Full Name',
                                hintText: 'Enter your full name',
                              ),
                              validator: AppUtils.validateName,
                              enabled: !_isLoading,
                            ),
                            const SizedBox(height: AppConstants.paddingM),
                            TextFormField(
                              controller: _employeeIdController,
                              keyboardType: TextInputType.text,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _handleLogin(),
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.badge_outlined),
                                labelText: 'Employee ID',
                                hintText: 'Enter your employee ID',
                              ),
                              validator: AppUtils.validateEmployeeId,
                              enabled: !_isLoading,
                            ),
                            const SizedBox(height: AppConstants.paddingXL),
                            PrimaryButton(
                              text: 'Continue',
                              onPressed: _handleLogin,
                              isLoading: _isLoading,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
