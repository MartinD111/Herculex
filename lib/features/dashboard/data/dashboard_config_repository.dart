import 'package:shared_preferences/shared_preferences.dart';

import '../domain/dashboard_config.dart';

/// Persists the editable dashboard layout (V2 §18) in SharedPreferences as a
/// single compact string under [_key].
class DashboardConfigRepository {
  static const _key = 'dashboard_config_v1';
  final SharedPreferences _prefs;

  DashboardConfigRepository(this._prefs);

  DashboardConfig load() => DashboardConfig.decode(_prefs.getString(_key));

  Future<void> save(DashboardConfig config) async {
    await _prefs.setString(_key, config.encode());
  }
}
