/// Mock attendance service for the MobiTrail Attendance Actions workflow.
///
/// Provides placeholder [timeIn] and [timeOut] methods that return
/// mock similarity scores. The actual CNN model integration, embedding
/// comparison, and database persistence will be implemented by the
/// backend developer.
library;

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../core/constants/app_constants.dart';

/// Handles time-in and time-out attendance actions.
class AttendanceService {
  Future<Map<String, dynamic>> _performAction(String actionUrl, String employeeId, String? imagePath) async {
    double latitude = 0.0;
    double longitude = 0.0;

    // --- Acquire GPS Location ---
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return {
          'success': false,
          'similarityScore': 0.0,
          'status': 'REJECTED',
          'message': 'GPS Location services are disabled. Please enable GPS.',
        };
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return {
            'success': false,
            'similarityScore': 0.0,
            'status': 'REJECTED',
            'message': 'GPS permissions denied. Geofencing check is mandatory.',
          };
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return {
          'success': false,
          'similarityScore': 0.0,
          'status': 'REJECTED',
          'message': 'Location permissions are permanently denied. Enable in Settings.',
        };
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
      latitude = position.latitude;
      longitude = position.longitude;
    } catch (e) {
      return {
        'success': false,
        'similarityScore': 0.0,
        'status': 'REJECTED',
        'message': 'Failed to obtain GPS coordinates: $e',
      };
    }

    // --- Perform API Request ---
    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}$actionUrl');
      final request = http.MultipartRequest('POST', url);

      request.fields['employeeId'] = employeeId;
      request.fields['latitude'] = latitude.toString();
      request.fields['longitude'] = longitude.toString();

      if (imagePath != null) {
        request.files.add(await http.MultipartFile.fromPath('image', imagePath));
      } else {
        request.files.add(http.MultipartFile.fromBytes(
          'image',
          [137, 80, 78, 71, 13, 10, 26, 10], // Dummy png headers
          filename: 'verification.jpg',
        ));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 403) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return {
          'success': data['success'] ?? false,
          'similarityScore': (data['confidence'] ?? 0.0) * 100, // API returns 0-1, UI expects 0-100
          'status': data['attendance_status'] ?? (data['success'] == true ? 'APPROVED' : 'REJECTED'),
          'message': data['message'] ?? 'Verification completed.',
          'time_in_time': data['time_in_time'] as String?,
          'time_out_time': data['time_out_time'] as String?,
        };
      } else {
        try {
          final Map<String, dynamic> errorData = jsonDecode(response.body);
          return {
            'success': false,
            'similarityScore': 0.0,
            'status': 'REJECTED',
            'message': errorData['detail'] ?? 'Verification failed.',
          };
        } catch (_) {
          return {
            'success': false,
            'similarityScore': 0.0,
            'status': 'REJECTED',
            'message': 'Server error: ${response.statusCode}',
          };
        }
      }
    } catch (e) {
      return {
        'success': false,
        'similarityScore': 0.0,
        'status': 'REJECTED',
        'message': 'Failed to connect to the server. Please check network.',
      };
    }
  }

  /// Perform a Time In action for the given [employeeId].
  Future<Map<String, dynamic>> timeIn(String employeeId, String? imagePath) async {
    return _performAction('/api/attendance/time-in', employeeId, imagePath);
  }

  /// Perform a Time Out action for the given [employeeId].
  Future<Map<String, dynamic>> timeOut(String employeeId, String? imagePath) async {
    return _performAction('/api/attendance/time-out', employeeId, imagePath);
  }
}
