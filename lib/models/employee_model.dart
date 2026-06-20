/// Employee model and provider for the MobiTrail Face Recognition Attendance System.
///
/// This file contains the [Employee] data model representing a user in the system,
/// and the [EmployeeProvider] which manages employee state, authentication status,
/// and theme preferences using the Provider pattern.
library;

import 'package:flutter/material.dart';

/// Represents an employee in the MobiTrail attendance system.
///
/// Each employee has a [name], a unique [employeeId], and an [isEnrolled] flag
/// indicating whether their face has been enrolled for recognition.
class Employee {
  /// The full name of the employee.
  final String name;

  /// The unique identifier for the employee.
  final String employeeId;

  /// Whether the employee's face has been enrolled for recognition.
  ///
  /// Defaults to `false` until enrollment is completed successfully.
  final bool isEnrolled;

  /// Whether the employee has timed in today.
  final bool hasTimedIn;

  /// Whether the employee has timed out today.
  final bool hasTimedOut;

  /// The time in status today.
  final String? timeInStatus;

  /// The time out status today.
  final String? timeOutStatus;

  /// The time in timestamp today.
  final String? timeInTime;

  /// The time out timestamp today.
  final String? timeOutTime;

  /// Creates an [Employee] instance.
  ///
  /// [name] and [employeeId] are required. [isEnrolled] defaults to `false`.
  const Employee({
    required this.name,
    required this.employeeId,
    this.isEnrolled = false,
    this.hasTimedIn = false,
    this.hasTimedOut = false,
    this.timeInStatus,
    this.timeOutStatus,
    this.timeInTime,
    this.timeOutTime,
  });

  /// Creates a copy of this [Employee] with the given fields replaced.
  Employee copyWith({
    String? name,
    String? employeeId,
    bool? isEnrolled,
    bool? hasTimedIn,
    bool? hasTimedOut,
    String? timeInStatus,
    String? timeOutStatus,
    String? timeInTime,
    String? timeOutTime,
  }) {
    return Employee(
      name: name ?? this.name,
      employeeId: employeeId ?? this.employeeId,
      isEnrolled: isEnrolled ?? this.isEnrolled,
      hasTimedIn: hasTimedIn ?? this.hasTimedIn,
      hasTimedOut: hasTimedOut ?? this.hasTimedOut,
      timeInStatus: timeInStatus ?? this.timeInStatus,
      timeOutStatus: timeOutStatus ?? this.timeOutStatus,
      timeInTime: timeInTime ?? this.timeInTime,
      timeOutTime: timeOutTime ?? this.timeOutTime,
    );
  }

  /// Creates an [Employee] from a JSON map.
  ///
  /// Used when deserializing API responses.
  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      name: json['name'] as String,
      employeeId: json['employeeId'] as String,
      isEnrolled: json['isEnrolled'] as bool? ?? false,
      hasTimedIn: json['hasTimedIn'] as bool? ?? false,
      hasTimedOut: json['hasTimedOut'] as bool? ?? false,
      timeInStatus: json['timeInStatus'] as String?,
      timeOutStatus: json['timeOutStatus'] as String?,
      timeInTime: json['timeInTime'] as String?,
      timeOutTime: json['timeOutTime'] as String?,
    );
  }

  /// Converts this [Employee] to a JSON map.
  ///
  /// Used when serializing for API requests or local storage.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'employeeId': employeeId,
      'isEnrolled': isEnrolled,
      'hasTimedIn': hasTimedIn,
      'hasTimedOut': hasTimedOut,
      'timeInStatus': timeInStatus,
      'timeOutStatus': timeOutStatus,
      'timeInTime': timeInTime,
      'timeOutTime': timeOutTime,
    };
  }

  @override
  String toString() =>
      'Employee(name: $name, employeeId: $employeeId, isEnrolled: $isEnrolled, hasTimedIn: $hasTimedIn, hasTimedOut: $hasTimedOut)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Employee &&
        other.name == name &&
        other.employeeId == employeeId &&
        other.isEnrolled == isEnrolled &&
        other.hasTimedIn == hasTimedIn &&
        other.hasTimedOut == hasTimedOut;
  }

  @override
  int get hashCode => Object.hash(name, employeeId, isEnrolled, hasTimedIn, hasTimedOut);
}

/// Manages employee state, authentication status, and theme preferences.
///
/// This provider serves as the central state management hub for:
/// - User authentication (login/logout)
/// - Face enrollment status tracking
/// - App theme mode (light/dark/system) preferences
///
/// Consumers can listen for changes via [ChangeNotifier].
class EmployeeProvider extends ChangeNotifier {
  /// The currently logged-in employee, or `null` if no user is authenticated.
  Employee? _employee;

  /// The current theme mode for the application. Always returns light mode.
  final ThemeMode _themeMode = ThemeMode.light;

  /// Returns the currently logged-in [Employee], or `null`.
  Employee? get employee => _employee;

  /// Whether an employee is currently logged in.
  bool get isLoggedIn => _employee != null;

  /// Whether the current employee's face has been enrolled.
  ///
  /// Returns `false` if no employee is logged in.
  bool get isEnrolled => _employee?.isEnrolled ?? false;

  /// Whether the employee has timed in today.
  bool get hasTimedIn => _employee?.hasTimedIn ?? false;

  /// Whether the employee has timed out today.
  bool get hasTimedOut => _employee?.hasTimedOut ?? false;

  /// The current [ThemeMode] preference.
  ThemeMode get themeMode => _themeMode;

  /// Logs in an employee with the given [name] and [employeeId].
  ///
  /// Creates a new [Employee] instance and notifies listeners.
  void login(
    String name,
    String employeeId, {
    bool hasTimedIn = false,
    bool hasTimedOut = false,
    String? timeInStatus,
    String? timeOutStatus,
    String? timeInTime,
    String? timeOutTime,
  }) {
    _employee = Employee(
      name: name,
      employeeId: employeeId,
      hasTimedIn: hasTimedIn,
      hasTimedOut: hasTimedOut,
      timeInStatus: timeInStatus,
      timeOutStatus: timeOutStatus,
      timeInTime: timeInTime,
      timeOutTime: timeOutTime,
    );
    notifyListeners();
  }

  /// Updates the enrollment status of the current employee.
  ///
  /// Does nothing if no employee is currently logged in.
  void setEnrolled(bool value) {
    if (_employee == null) return;
    _employee = _employee!.copyWith(isEnrolled: value);
    notifyListeners();
  }

  /// Updates the time in status of the current employee.
  void setHasTimedIn(bool value) {
    if (_employee == null) return;
    _employee = _employee!.copyWith(hasTimedIn: value);
    notifyListeners();
  }

  /// Updates the time out status of the current employee.
  void setHasTimedOut(bool value) {
    if (_employee == null) return;
    _employee = _employee!.copyWith(hasTimedOut: value);
    notifyListeners();
  }

  /// Updates the attendance information of the current employee.
  void updateAttendance({
    bool? hasTimedIn,
    bool? hasTimedOut,
    String? timeInStatus,
    String? timeOutStatus,
    String? timeInTime,
    String? timeOutTime,
  }) {
    if (_employee == null) return;
    _employee = _employee!.copyWith(
      hasTimedIn: hasTimedIn ?? _employee!.hasTimedIn,
      hasTimedOut: hasTimedOut ?? _employee!.hasTimedOut,
      timeInStatus: timeInStatus ?? _employee!.timeInStatus,
      timeOutStatus: timeOutStatus ?? _employee!.timeOutStatus,
      timeInTime: timeInTime ?? _employee!.timeInTime,
      timeOutTime: timeOutTime ?? _employee!.timeOutTime,
    );
    notifyListeners();
  }

  /// Logs out the current employee by clearing all employee data.
  void logout() {
    _employee = null;
    notifyListeners();
  }
}
