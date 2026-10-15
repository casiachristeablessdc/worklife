import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider() {
    _isLoading = true;
    _authStateSubscription = _authService.authStateChanges.listen(
      (user) => unawaited(_restoreSession(user)),
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('AUTH STATE ERROR: $error');
        _isInitialized = true;
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  late final StreamSubscription<User?> _authStateSubscription;

  User? _user;
  bool _isLoading = false;
  bool _isOnboardingCompleted = false;
  bool _isAdmin = false;
  bool _isInitialized = false;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _user != null;
  bool get isOnboardingCompleted => _isOnboardingCompleted;
  bool get isAdmin => _isAdmin;
  bool get isInitialized => _isInitialized;

  Future<void> _restoreSession(User? user) async {
    _user = user;

    if (user == null) {
      _isAdmin = false;
      _isOnboardingCompleted = false;
      _isInitialized = true;
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      final token = await user.getIdTokenResult();
      _isAdmin = token.claims?['admin'] == true && user.emailVerified;
    } catch (error) {
      debugPrint('RESTORE CLAIMS ERROR: $error');
      _isAdmin = false;
    }

    try {
      _isOnboardingCompleted = await _firestoreService.isOnboardingCompleted(
        user.uid,
      );
    } catch (error) {
      debugPrint('RESTORE PROFILE ERROR: $error');
      _isOnboardingCompleted = false;
    }

    if (_authService.currentUser?.uid != user.uid) return;
    _isInitialized = true;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> refreshAuthorization() async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    await currentUser.getIdTokenResult(true);
    await _restoreSession(currentUser);
  }

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

      try {
        await user.updateDisplayName(name.trim());
      } catch (error) {
        debugPrint('AUTH DISPLAY NAME UPDATE ERROR: $error');
      }

      _user = user;
      _isAdmin = false;
      _isOnboardingCompleted = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> login({required String email, required String password}) async {
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
      await _restoreSession(user);
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
      await _restoreSession(user);
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

      try {
        await _user!.updateDisplayName(name.trim());
      } catch (error) {
        debugPrint('AUTH DISPLAY NAME UPDATE ERROR: $error');
      }

      _isOnboardingCompleted = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _authService.logout();

    _user = null;
    _isAdmin = false;
    _isOnboardingCompleted = false;

    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_authStateSubscription.cancel());
    super.dispose();
  }
}
