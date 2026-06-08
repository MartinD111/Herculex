import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/profile.dart';

class LocalProfileRepository {
  static const _kProfileKey = 'herculex.profile';

  final SharedPreferences _prefs;
  final _controller = StreamController<Profile?>.broadcast();

  LocalProfileRepository(this._prefs) {
    _controller.onListen = () {
      scheduleMicrotask(() {
        if (!_controller.isClosed) {
          _controller.add(currentProfile);
        }
      });
    };
  }

  Profile? get currentProfile {
    final raw = _prefs.getString(_kProfileKey);
    if (raw == null) return null;
    try {
      return Profile.decode(raw);
    } catch (_) {
      return null;
    }
  }

  Stream<Profile?> watch() => _controller.stream;

  Future<void> save(Profile profile) async {
    await _prefs.setString(_kProfileKey, profile.encode());
    _controller.add(profile);
  }

  Future<void> clear() async {
    await _prefs.remove(_kProfileKey);
    _controller.add(null);
  }

  void dispose() => _controller.close();
}
