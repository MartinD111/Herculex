import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:herculex/app/app.dart';
import 'package:herculex/app/providers.dart';

void main() {
  testWidgets('First launch (no profile) boots into onboarding', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const HerculexApp(),
      ),
    );

    // Let the splash → onboarding redirect resolve.
    await tester.pumpAndSettle();

    // On-device only: there is no landing/login screen — onboarding is first.
    expect(find.text('What is your primary goal?'), findsOneWidget);
  });
}
