import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../data/auth/auth_service.dart';
import '../../data/models/user_profile.dart';

/// Auth state for go_router redirects and UI.
class AuthController extends ChangeNotifier {
  AuthController({AuthService? service})
      : _service = service ?? AuthService(),
        _useFirebase = true {
    _subscription = _service!.authStateChanges.listen(_onAuthChanged);
  }

  /// Test / offline mode — no Firebase calls.
  AuthController.forTesting({UserProfile? profile})
      : _service = null,
        _useFirebase = false,
        _profile = profile,
        _ready = true;

  final AuthService? _service;
  final bool _useFirebase;

  StreamSubscription<User?>? _subscription;
  UserProfile? _profile;
  bool _ready = false;
  bool _busy = false;
  String? _error;

  UserProfile? get profile => _profile;
  bool get isReady => _ready;
  bool get isSignedIn => _profile != null;
  bool get isBusy => _busy;
  String? get error => _error;
  String get displayName => _profile?.name ?? 'Friend';

  Future<void> _onAuthChanged(User? user) async {
    if (user == null) {
      _profile = null;
      _ready = true;
      notifyListeners();
      return;
    }

    try {
      _profile = await _service!.loadProfile(user.uid);
    } catch (_) {
      _profile = UserProfile(
        uid: user.uid,
        name: user.displayName?.trim().isNotEmpty == true
            ? user.displayName!.trim()
            : 'Friend',
        email: user.email ?? '',
      );
    }
    _ready = true;
    notifyListeners();
  }

  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    if (!_useFirebase) {
      _profile = UserProfile(
        uid: 'test',
        name: name.trim(),
        email: email.trim().toLowerCase(),
      );
      notifyListeners();
      return true;
    }

    return _run(() => _service!.signUp(
          name: name,
          email: email,
          password: password,
        ));
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    if (!_useFirebase) {
      _profile = UserProfile(
        uid: 'test',
        name: 'Friend',
        email: email.trim().toLowerCase(),
      );
      notifyListeners();
      return true;
    }

    return _run(() => _service!.signIn(email: email, password: password));
  }

  Future<void> signOut() async {
    _error = null;
    if (!_useFirebase) {
      _profile = null;
      notifyListeners();
      return;
    }
    await _service!.signOut();
  }

  Future<bool> _run(Future<UserProfile> Function() action) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      _profile = await action();
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _mapAuthError(e);
      return false;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'That email is already registered. Try signing in.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'weak-password':
        return 'Password should be at least 6 characters.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email or password is incorrect.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
