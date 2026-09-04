import 'package:flutter/foundation.dart';

import '../../data/auth/auth_service.dart';
import '../../data/models/user_profile.dart';

/// Auth state for go_router redirects and UI (PostgreSQL via FastAPI).
class AuthController extends ChangeNotifier {
  AuthController({AuthService? service})
    : _service = service ?? AuthService(),
      _useApi = true;

  /// Test / offline mode — no network calls.
  AuthController.forTesting({UserProfile? profile})
    : _service = null,
      _useApi = false,
      _profile = profile,
      _ready = true;

  final AuthService? _service;
  final bool _useApi;

  UserProfile? _profile;
  bool _ready = false;
  bool _busy = false;
  String? _error;

  UserProfile? get profile => _profile;
  bool get isReady => _ready;
  bool get isSignedIn => _profile != null || (_service?.hasToken ?? false);
  bool get isBusy => _busy;
  String? get error => _error;
  String get displayName => _profile?.name ?? 'Friend';
  String? get accessToken => _service?.token;
  String? get forecastLocationId => _profile?.forecastLocationId;
  String get forecastLocationName =>
      _profile?.forecastLocationName ?? 'Selangor';

  /// Restore a saved token from disk and mark the router ready.
  ///
  /// Does not wait on `/auth/me` — [refreshProfile] loads the name afterwards
  /// so the shell can paint while Cloud SQL is still answering.
  Future<void> restoreSession() async {
    if (!_useApi) {
      _ready = true;
      notifyListeners();
      return;
    }
    try {
      await _service!.restoreSession();
    } catch (_) {
      _profile = null;
    } finally {
      _ready = true;
      notifyListeners();
    }
  }

  Future<void> refreshProfile() async {
    if (!_useApi || !(_service?.hasToken ?? false)) return;
    try {
      _profile = await _service!.loadCurrentUser();
    } catch (_) {
      _profile = null;
    }
    if (hasListeners) notifyListeners();
  }

  Future<void> bootstrap() async {
    await restoreSession();
    await refreshProfile();
  }

  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    if (!_useApi) {
      _profile = UserProfile(
        uid: 'test',
        name: name.trim(),
        email: email.trim().toLowerCase(),
      );
      notifyListeners();
      return true;
    }

    return _run(
      () => _service!.signUp(name: name, email: email, password: password),
    );
  }

  Future<bool> signIn({required String email, required String password}) async {
    if (!_useApi) {
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
    if (!_useApi) {
      _profile = null;
      notifyListeners();
      return;
    }
    await _service!.signOut();
    _profile = null;
    notifyListeners();
  }

  Future<bool> _run(Future<UserProfile> Function() action) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      _profile = await action();
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      final String msg = e.toString();
      if (msg.contains('SocketException') ||
          msg.contains('ClientException') ||
          msg.contains('TimeoutException')) {
        _error = 'Cannot reach the API. Check internet, then try again.';
      } else {
        _error = msg;
      }
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
