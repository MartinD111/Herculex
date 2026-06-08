import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class WearSyncService {
  static const MethodChannel _channel = MethodChannel('com.example.herculex/wear');

  Future<void> syncMacros(int calories, int protein) async {
    try {
      await _channel.invokeMethod('syncMacros', {
        'calories': calories,
        'protein': protein,
      });
      debugPrint('Successfully invoked syncMacros channel');
    } on PlatformException catch (e) {
      debugPrint('Failed to sync macros to wear: ${e.message}');
    }
  }
}
