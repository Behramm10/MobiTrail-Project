# MobiTrail - Face Recognition Attendance System

MobiTrail is a premium, production-ready Flutter mobile application UI designed for employee face recognition attendance management. This application provides a modern, clean, and minimal corporate user interface styled in accordance with Material 3 design and the MobiTrail company branding guidelines.

This project contains the complete **frontend UI, camera view layers, custom oval overlay, state management, navigation, and mock service placeholders**. It is designed to be easily handed off to a backend/CNN developer for integration.

---

## 📱 Features & Workflows

1. **Splash Screen**: Features a premium animated fade-in of the MobiTrail company logo and branding, automatically transitioning to the Login screen.
2. **Login Screen**: Form-validated entrance for employees using their Full Name and Employee ID.
3. **Dynamic Dashboard**:
   - **Enrollment Phase (New Employees)**: Guides the user to register their face. Displays *only* the **Enroll Face** action and hides attendance options.
   - **Verification Phase (Enrolled Employees)**: Displays the **Verify Attendance** button (with face scan icon) and **Re-Enroll Face** button.
   - **Attendance Status Card**: Displays Today's status dynamically: shows **"Not Marked Yet"** initially, and updates to **"🟢 Present"** with the current system date (e.g., `3 June 2026`) immediately upon successful verification.
4. **Face Enrollment**: Walks the employee through capturing multiple face frames with a real camera feed preview, showing an animated oval alignment guide, countdown ticks, and frame counter.
5. **Face Verification (Attendance Marking)**: Captures a camera frame, checks identity, displays a green face bounding box overlay on success (or red on failure), shows the "Attendance Marked Successfully" card, and updates the local session status.

---

## 🛠️ Tech Stack & Dependencies

* **Core**: Flutter (latest stable version) & Dart
* **Design System**: Material 3
* **State Management**: Provider (for employee, enrollment, and attendance states)
* **Camera Handling**: `camera` package
* **Helper Packages**: `intl` (date formatting), `google_fonts` (Inter typeface), `permission_handler`, `shared_preferences`

---

## 🚀 How to Run the Project

### Prerequisites
* Install the [Flutter SDK](https://docs.flutter.dev/get-started/install) (Ensure it is added to your environment `PATH`).
* Install [Android Studio](https://developer.android.com/studio) or VS Code.
* Set up an Android Emulator or connect a physical Android device with USB Debugging enabled.

---

### Option A: Running via Command Prompt (CMD)

1. Open your Command Prompt and navigate to the project directory:
   ```cmd
   cd c:\Users\Admin\Desktop\MobiTrail
   ```
2. Fetch dependencies:
   ```cmd
   flutter pub get
   ```
3. Check for any static analysis issues (should report "No issues found!"):
   ```cmd
   flutter analyze
   ```
4. Run the application:
   ```cmd
   flutter run
   ```

---

### Option B: Running via Android Studio

1. Launch **Android Studio**.
2. Click **File** ➜ **Open...** and select the `MobiTrail` project folder (`c:\Users\Admin\Desktop\MobiTrail`).
3. Allow the project to sync and index. Android Studio should automatically detect it as a Flutter project.
4. If prompt displays "Dart SDK is not configured", click **Configure Dart SDK** and select your Flutter SDK path.
5. Select your target device/emulator from the dropdown box in the toolbar.
6. Click the green **Run** button (play icon) in the top toolbar to build and run the app.

---

## 🔗 Backend & CNN Model Integration Guide

For the developer integrating the backend, database, and CNN face embeddings: **you do not need to rewrite the UI screens**. You only need to plug your logic into the existing service hooks and model state.

Look for the `// TODO (Backend Integration)` comments in the following files:

### 1. Authentication Integration
* **File**: [`lib/services/auth_service.dart`](file:///c:/Users/Admin/Desktop/MobiTrail/lib/services/auth_service.dart)
* **Tasks**:
  * Replace the mock login delay with a secure HTTP POST request to your authentication backend endpoint.
  * Retrieve and return the real employee metadata, including their enrollment status (`isEnrolled` flag) from your remote database.

### 2. Face Enrollment (Generating Face Embeddings)
* **File**: [`lib/services/enrollment_service.dart`](file:///c:/Users/Admin/Desktop/MobiTrail/lib/services/enrollment_service.dart)
* **Tasks**:
  * Replace the mock delay inside `enrollFace`.
  * Send the captured camera frames (passed from [`lib/features/enroll/enroll_screen.dart`](file:///c:/Users/Admin/Desktop/MobiTrail/lib/features/enroll/enroll_screen.dart)) to your CNN preprocessing pipeline.
  * Generate the facial embedding vector and save it to your database (e.g., PostgreSQL/pgvector, SQLite locally, or a remote database server).

### 3. Face Verification & Attendance Marking
* **File**: [`lib/services/verification_service.dart`](file:///c:/Users/Admin/Desktop/MobiTrail/lib/services/verification_service.dart)
* **Tasks**:
  * Replace the mock delay inside `verifyFace`.
  * Compare the captured verification frame (passed from [`lib/features/verify/verify_screen.dart`](file:///c:/Users/Admin/Desktop/MobiTrail/lib/features/verify/verify_screen.dart)) against the stored embeddings for the logged-in user.
  * Calculate the similarity score (cosine distance). If it passes your threshold, return `success: true`.
  * Record the attendance timestamp, device location, and verification details in your backend attendance records database.

### 4. Application State Updates
* The UI listens to state modifications via the [`EmployeeProvider`](file:///c:/Users/Admin/Desktop/MobiTrail/lib/models/employee_model.dart) class:
  * Calling `setEnrolled(true)` updates the dashboard layout from "Not Enrolled" state to the verification flow layout.
  * Calling `setAttendanceMarked(true)` updates the Dashboard's attendance status card from "Not Marked Yet" to "🟢 Present" instantly.
