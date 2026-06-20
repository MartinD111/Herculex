import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Shows / updates / cancels a persistent "Workout in progress" notification
/// whenever the app is backgrounded during an active session.
///
/// Call [init] once at startup, [showOrUpdate] when the session is active and
/// the app goes to background, and [cancel] when the session ends or the app
/// returns to foreground.
class WorkoutNotificationService {
  WorkoutNotificationService._();
  static final WorkoutNotificationService instance =
      WorkoutNotificationService._();

  static const _channelId = 'workout_live';
  static const _notifId = 1;

  final _plugin = FlutterLocalNotificationsPlugin();
  Timer? _ticker;

  Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iOS = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _guard(() async {
      await _plugin.initialize(
        const InitializationSettings(android: android, iOS: iOS),
      );

      // Request permission on Android 13+.
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    });
  }

  /// Runs a notification-plugin call, swallowing platform-channel failures so a
  /// missing channel (tests) or a device that blocks notifications can never
  /// crash the app. Errors are logged in debug only.
  Future<void> _guard(Future<void> Function() body) async {
    try {
      await body();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('WorkoutNotificationService: notification call skipped ($e)');
      }
    }
  }

  /// Start ticking a live notification that updates the elapsed time every
  /// second. Safe to call multiple times — restarts the ticker if already running.
  void showOrUpdate({
    required DateTime startedAt,
    required String exerciseName,
  }) {
    _ticker?.cancel();
    _post(startedAt: startedAt, exerciseName: exerciseName);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _post(startedAt: startedAt, exerciseName: exerciseName);
    });
  }

  Future<void> _post({
    required DateTime startedAt,
    required String exerciseName,
  }) async {
    final elapsed = _fmt(DateTime.now().difference(startedAt));
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      'Live Workout',
      channelDescription: 'Shows elapsed time during an active workout',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,           // cannot be dismissed by swipe
      onlyAlertOnce: true,     // no sound/vibration on updates
      showWhen: false,
      icon: '@mipmap/ic_launcher',
    );
    const iOSDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: false,
      presentSound: false,
    );
    await _guard(() => _plugin.show(
          _notifId,
          'Workout  $elapsed',
          exerciseName,
          const NotificationDetails(android: androidDetails, iOS: iOSDetails),
        ));
  }

  /// Stop the ticker and dismiss the notification.
  Future<void> cancel() async {
    _ticker?.cancel();
    _ticker = null;
    await _guard(() => _plugin.cancel(_notifId));
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}
