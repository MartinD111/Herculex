import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:herculex/app/app.dart';
import 'package:herculex/app/providers.dart';

void main() {
  testWidgets('App launches and reaches the landing screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const HerculexApp(),
      ),
    );

    // Let the splash-redirect resolve.
    await tester.pumpAndSettle();

    expect(find.text('HERCULEX'), findsOneWidget);
    expect(find.text('Start Journey'), findsOneWidget);
  });
}
