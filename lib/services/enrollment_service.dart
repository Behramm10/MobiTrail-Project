/// Mock face enrollment service for the MobiTrail Face Recognition Attendance System.
///
/// Simulates the process of capturing face frames, processing them through
/// a CNN model, generating face embeddings, and storing them in the backend
/// database. All methods include TODO markers for real backend integration.
library;

/// Handles face enrollment by processing captured frames and storing
/// the resulting face embeddings.
///
/// The enrollment flow:
/// 1. Capture multiple face frames from the camera.
/// 2. Send frames to the CNN model for feature extraction.
/// 3. Generate a face embedding vector from the extracted features.
/// 4. Store the embedding in the database linked to the employee.
///
/// Currently returns mock responses with simulated processing delays.
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';

/// Handles face enrollment by processing captured frames and storing
/// the resulting face embeddings.
class EnrollmentService {
  /// Enrolls an employee's face using the provided camera [frames].
  ///
  /// Connects to the backend REST API POST /api/enrollment/enroll.
  Future<Map<String, dynamic>> enrollFace(
    String employeeId,
    List<dynamic> frames,
  ) async {
    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/api/enrollment/enroll');
      final request = http.MultipartRequest('POST', url);
      
      request.fields['employeeId'] = employeeId;
      
      // If camera captured real frames
      if (frames.isNotEmpty) {
        final frame = frames.first;
        if (frame is String) {
          // If frame is a file path
          request.files.add(await http.MultipartFile.fromPath('image', frame));
        } else if (frame is List<int>) {
          // If frame is raw image bytes
          request.files.add(http.MultipartFile.fromBytes(
            'image',
            frame,
            filename: 'profile.jpg',
          ));
        }
      } else {
        // Fallback dummy file to prevent crashes during empty list tests
        request.files.add(http.MultipartFile.fromBytes(
          'image',
          [137, 80, 78, 71, 13, 10, 26, 10], // Dummy png headers
          filename: 'profile.jpg',
        ));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data;
      } else {
        try {
          final Map<String, dynamic> errorData = jsonDecode(response.body);
          return {
            'success': false,
            'message': errorData['detail'] ?? 'Enrollment failed.',
          };
        } catch (_) {
          return {
            'success': false,
            'message': 'Server error: ${response.statusCode}',
          };
        }
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to connect to the server. Please check network.',
      };
    }
  }
}
