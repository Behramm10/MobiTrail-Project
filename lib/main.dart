import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'features/splash/splash_screen.dart';
import 'models/employee_model.dart';
import 'services/auth_service.dart';
import 'services/enrollment_service.dart';
import 'services/verification_service.dart';
import 'services/attendance_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait for consistent enterprise UX
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const MobiTrailApp());
}

class MobiTrailApp extends StatelessWidget {
  const MobiTrailApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ---------------------------------------------------------------------------
        // TODO (Backend Integration): Replace mock services with real API-backed
        // implementations when backend is ready.
        // ---------------------------------------------------------------------------
        ChangeNotifierProvider(create: (_) => EmployeeProvider()),
        Provider(create: (_) => AuthService()),
        Provider(create: (_) => EnrollmentService()),
        Provider(create: (_) => VerificationService()),
        Provider(create: (_) => AttendanceService()),
      ],
      child: Consumer<EmployeeProvider>(
        builder: (context, employeeProvider, _) {
          return MaterialApp(
            title: 'MobiTrail',
            debugShowCheckedModeBanner: false,
            themeMode: ThemeMode.light,
            theme: AppTheme.lightTheme,
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
