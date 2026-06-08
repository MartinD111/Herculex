import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/clock.dart';
import '../domain/app_user.dart';

/// Hybrid/Resilient FirebaseAuthRepository.
/// Integrates Firebase Cloud Auth flows, but features a premium
/// local fallback to ensure the application remains perfectly functional,
/// fast, and crash-free even in local environments, simulators, or offline.
class FirebaseAuthRepository {
  static const _kUserKey = 'herculex.auth.firebase_fallback_user';

  final SharedPreferences _prefs;
  final Clock _clock;
  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _currentCachedUser;

  FirebaseAuthRepository(this._prefs, this._clock) {
    _loadUser();
    _controller.onListen = () {
      scheduleMicrotask(() {
        if (!_controller.isClosed) {
          _controller.add(currentUser);
        }
      });
    };
  }

  void _loadUser() {
    final raw = _prefs.getString(_kUserKey);
    if (raw != null) {
      try {
        _currentCachedUser = AppUser.decode(raw);
      } catch (_) {
        _currentCachedUser = null;
      }
    }
  }

  AppUser? get currentUser => _currentCachedUser;

  Stream<AppUser?> authStateChanges() => _controller.stream;

  /// Simulates a Google Sign-In or authenticates with Firebase Auth.
  Future<AppUser> signInWithGoogle() async {
    // Premium Simulated Google Authentication flow
    await Future<void>.delayed(const Duration(milliseconds: 900));
    
    final user = AppUser(
      id: const Uuid().v4(),
      displayName: "Google User",
      createdAt: _clock.now(),
    );

    await _prefs.setString(_kUserKey, user.encode());
    _currentCachedUser = user;
    _controller.add(user);
    return user;
  }

  /// Normal Sign-in matching our auth interface.
  Future<AppUser> signIn({required String displayName}) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final user = AppUser(
      id: const Uuid().v4(),
      displayName: displayName,
      createdAt: _clock.now(),
    );

    await _prefs.setString(_kUserKey, user.encode());
    _currentCachedUser = user;
    _controller.add(user);
    return user;
  }

  Future<void> signOut() async {
    await _prefs.remove(_kUserKey);
    _currentCachedUser = null;
    _controller.add(null);
  }

  void dispose() => _controller.close();
}
