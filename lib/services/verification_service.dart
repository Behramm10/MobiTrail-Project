/// Mock face verification service for the MobiTrail Face Recognition Attendance System.
///
/// Simulates the process of capturing a face frame, comparing it against
/// stored face embeddings using a CNN model, and recording the attendance
/// timestamp. Uses [AppConstants] to control mock verification outcomes.
library;


import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../core/constants/app_constants.dart';

/// Handles face verification by comparing a captured frame against
/// stored face embeddings for attendance marking.
class VerificationService {
  /// Verifies an employee's face against their stored embedding.
  ///
  /// Connects to the backend REST API POST /api/verification/verify.
  /// Acquires device GPS coordinates before sending.
  Future<Map<String, dynamic>> verifyFace(
    String employeeId,
    dynamic frame,
  ) async {
    double latitude = 0.0;
    double longitude = 0.0;

    // --- Acquire GPS Location ---
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return {
          'success': false,
          'confidence': 0.0,
          'message': 'GPS Location services are disabled. Please enable GPS.',
          'timestamp': DateTime.now().toIso8601String(),
        };
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return {
            'success': false,
            'confidence': 0.0,
            'message': 'GPS permissions denied. Geofencing check is mandatory.',
            'timestamp': DateTime.now().toIso8601String(),
          };
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return {
          'success': false,
          'confidence': 0.0,
          'message': 'Location permissions are permanently denied. Enable in Settings.',
          'timestamp': DateTime.now().toIso8601String(),
        };
      }

      // Fetch position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
      latitude = position.latitude;
      longitude = position.longitude;
    } catch (e) {
      return {
        'success': false,
        'confidence': 0.0,
        'message': 'Failed to obtain GPS coordinates: $e',
        'timestamp': DateTime.now().toIso8601String(),
      };
    }

    // --- Perform API Request ---
    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/api/verification/verify');
      final request = http.MultipartRequest('POST', url);

      request.fields['employeeId'] = employeeId;
      request.fields['latitude'] = latitude.toString();
      request.fields['longitude'] = longitude.toString();

      if (frame != null) {
        if (frame is String) {
          // If frame is a file path path
          request.files.add(await http.MultipartFile.fromPath('image', frame));
        } else if (frame is List<int>) {
          // If frame is raw image bytes
          request.files.add(http.MultipartFile.fromBytes(
            'image',
            frame,
            filename: 'verification.jpg',
          ));
        }
      } else {
        // Fallback dummy file to prevent crashes during empty verify captures
        request.files.add(http.MultipartFile.fromBytes(
          'image',
          [137, 80, 78, 71, 13, 10, 26, 10], // Dummy png headers
          filename: 'verification.jpg',
        ));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 403) {
        // Both match results and geofence rejections (403) are valid JSON payloads
        final Map<String, dynamic> data = jsonDecode(response.body);
        return {
          'success': data['success'] ?? false,
          'confidence': data['confidence'] ?? 0.0,
          'message': data['message'] ?? 'Verification completed.',
          'timestamp': data['timestamp'] ?? DateTime.now().toIso8601String(),
        };
      } else {
        try {
          final Map<String, dynamic> errorData = jsonDecode(response.body);
          return {
            'success': false,
            'confidence': 0.0,
            'message': errorData['detail'] ?? 'Verification failed.',
            'timestamp': DateTime.now().toIso8601String(),
          };
        } catch (_) {
          return {
            'success': false,
            'confidence': 0.0,
            'message': 'Server error: ${response.statusCode}',
            'timestamp': DateTime.now().toIso8601String(),
          };
        }
      }
    } catch (e) {
      return {
        'success': false,
        'confidence': 0.0,
        'message': 'Failed to connect to the server. Please check network.',
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }
}
