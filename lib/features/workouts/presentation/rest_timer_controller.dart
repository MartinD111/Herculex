import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock.dart';

class RestTimerState {
  final DateTime? endsAt;
  final int targetSeconds;
  final String? exerciseName;

  const RestTimerState({this.endsAt, this.targetSeconds = 0, this.exerciseName});

  bool get isRunning => endsAt != null;

  int remainingSecondsFrom(DateTime now) {
    if (endsAt == null) return 0;
    final diff = endsAt!.difference(now).inSeconds;
    return diff > 0 ? diff : 0;
  }

  double progressFrom(DateTime now) {
    if (endsAt == null || targetSeconds == 0) return 0;
    final remaining = remainingSecondsFrom(now);
    return 1 - (remaining / targetSeconds);
  }

  static const idle = RestTimerState();
}

class RestTimerController extends Notifier<RestTimerState> {
  Timer? _ticker;

  @override
  RestTimerState build() {
    ref.onDispose(() => _ticker?.cancel());
    return RestTimerState.idle;
  }

  void start({required int seconds, String? exerciseName}) {
    _ticker?.cancel();
    final clock = ref.read(clockProvider);
    state = RestTimerState(
      endsAt: clock.now().add(Duration(seconds: seconds)),
      targetSeconds: seconds,
      exerciseName: exerciseName,
    );
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final remaining = state.remainingSecondsFrom(clock.now());
      if (remaining <= 0) {
        cancel();
      } else {
        // Trigger rebuild by nudging state (cheaply).
        state = RestTimerState(
          endsAt: state.endsAt,
          targetSeconds: state.targetSeconds,
          exerciseName: state.exerciseName,
        );
      }
    });
  }

  void addSeconds(int delta) {
    if (!state.isRunning) return;
    state = RestTimerState(
      endsAt: state.endsAt!.add(Duration(seconds: delta)),
      targetSeconds: state.targetSeconds + delta,
      exerciseName: state.exerciseName,
    );
  }

  void cancel() {
    _ticker?.cancel();
    _ticker = null;
    state = RestTimerState.idle;
  }
}

final restTimerProvider =
    NotifierProvider<RestTimerController, RestTimerState>(RestTimerController.new);
