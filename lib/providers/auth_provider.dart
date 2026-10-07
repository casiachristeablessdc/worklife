import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  User? _user;
  bool _isLoading = false;
  bool _isOnboardingCompleted = false;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _user != null;
  bool get isOnboardingCompleted => _isOnboardingCompleted;

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final credential = await _authService.register(
        email: email,
        password: password,
      );

      final user = credential.user;

      if (user == null) {
        throw Exception('Registration failed. Please try again.');
      }

      await _firestoreService.createUserProfile(
        userId: user.uid,
        name: name,
        email: email,
      );

      _user = user;
      _isOnboardingCompleted = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final credential = await _authService.login(
        email: email,
        password: password,
      );

      final user = credential.user;

      if (user == null) {
        throw Exception('Login failed. Please try again.');
      }

      _user = user;
      _isOnboardingCompleted =
          await _firestoreService.isOnboardingCompleted(user.uid);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();

    try {
      final credential = await _authService.signInWithGoogle();

      if (credential == null) {
        return;
      }

      final user = credential.user;

      if (user == null) {
        throw Exception('Google sign-in failed. Please try again.');
      }

      await _firestoreService.userDocument(user.uid).set({
        'name': user.displayName ?? '',
        'email': user.email ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _user = user;
      _isOnboardingCompleted =
          await _firestoreService.isOnboardingCompleted(user.uid);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> completeOnboarding({
    required String name,
    required String jobTitle,
    required String company,
    required String workStartTime,
    required String workEndTime,
    required List<String> workdays,
    required int commuteMinutes,
    required List<String> hobbies,
    required List<String> personalLife,
    required List<String> sideQuests,
    required List<String> customHobbies,
    required List<String> customSideQuests,
  }) async {
    if (_user == null) {
      throw Exception('No authenticated user.');
    }

    _isLoading = true;
    notifyListeners();

    try {
      await _firestoreService.updateUserProfile(
        userId: _user!.uid,
        name: name,
        jobTitle: jobTitle,
        company: company,
        workStartTime: workStartTime,
        workEndTime: workEndTime,
        workdays: workdays,
        commuteMinutes: commuteMinutes,
        hobbies: hobbies,
        personalLife: personalLife,
        sideQuests: sideQuests,
        customHobbies: customHobbies,
        customSideQuests: customSideQuests,
        onboardingCompleted: true,
      );

      _isOnboardingCompleted = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _authService.logout();

    _user = null;
    _isOnboardingCompleted = false;

    notifyListeners();
  }
}