import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/clock.dart';
import '../domain/app_user.dart';

/// On-device "auth" for personal/internal testing.
/// A single local profile is stored in shared_preferences as JSON.
/// When Firebase Auth lands, this repo gets replaced by a FirebaseAuthRepository
/// behind the same interface — call sites don't change.
class LocalAuthRepository {
  static const _kUserKey = 'herculex.auth.user';

  final SharedPreferences _prefs;
  final Clock _clock;
  final _controller = StreamController<AppUser?>.broadcast();

  LocalAuthRepository(this._prefs, this._clock) {
    // Emit current state on listen.
    _controller.onListen = () => _controller.add(currentUser);
  }

  AppUser? get currentUser {
    final raw = _prefs.getString(_kUserKey);
    if (raw == null) return null;
    try {
      return AppUser.decode(raw);
    } catch (_) {
      return null;
    }
  }

  Stream<AppUser?> authStateChanges() => _controller.stream;

  Future<AppUser> signIn({required String displayName}) async {
    final existing = currentUser;
    final user = existing?.copyWith(displayName: displayName) ??
        AppUser(
          id: const Uuid().v4(),
          displayName: displayName,
          createdAt: _clock.now(),
        );
    await _prefs.setString(_kUserKey, user.encode());
    _controller.add(user);
    return user;
  }

  Future<void> signOut() async {
    await _prefs.remove(_kUserKey);
    _controller.add(null);
  }

  void dispose() => _controller.close();
}
