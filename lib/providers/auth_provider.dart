import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  User? _user;
  bool _isLoading = false;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _user != null;

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

      _user = credential.user;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    _user = null;
    notifyListeners();
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
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}
}