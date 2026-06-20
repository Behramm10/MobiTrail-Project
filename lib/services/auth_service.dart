/// Mock authentication service for the MobiTrail Face Recognition Attendance System.
///
/// Provides simulated login and logout functionality with realistic delays
/// to mimic network latency. All methods include TODO markers indicating
/// where real backend API calls should be integrated.
library;

/// Handles employee authentication against the backend.
///
/// Currently uses mock data with simulated network delays.
/// Replace mock implementations with real API calls when the backend is ready.
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';

/// Handles employee authentication against the backend.
class AuthService {
  /// Authenticates an employee with the given [name] and [employeeId].
  ///
  /// Connects to the backend REST API POST /api/auth/login.
  Future<Map<String, dynamic>> login(String name, String employeeId) async {
    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/api/auth/login');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'employeeId': employeeId,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data;
      } else {
        return {
          'success': false,
          'message': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to connect to the server. Please check network.',
      };
    }
  }

  /// Logs out the currently authenticated employee.
  Future<void> logout() async {
    // In local REST session model, we clear local states. 
    // If backend needs explicit JWT invalidation, we can invoke it here.
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}
