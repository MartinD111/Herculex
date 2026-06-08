import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/admin/presentation/admin_dashboard_view.dart';
import '../features/admin/presentation/admin_insert_recipe_view.dart';
import '../features/admin/presentation/admin_insert_workout_view.dart';
import '../features/auth/domain/app_user.dart';
import '../features/auth/presentation/landing_view.dart';
import '../features/auth/presentation/login_view.dart';
import '../features/auth/presentation/splash_view.dart';
import '../features/onboarding/presentation/onboarding_view.dart';
import '../features/profile/domain/profile.dart';
import '../features/shell/main_scaffold.dart';
import '../features/workouts/presentation/workout_history_view.dart';
import 'providers.dart';

/// Bridges a Riverpod stream into a [Listenable] so [GoRouter.refreshListenable]
/// re-evaluates the redirect every time auth or profile state changes.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen<AsyncValue<AppUser?>>(authStateProvider, (_, _) => notifyListeners());
    ref.listen<AsyncValue<Profile?>>(profileProvider, (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final authAsync = ref.read(authStateProvider);
      final profileAsync = ref.read(profileProvider);

      // While either is still loading, sit on /splash.
      if (authAsync.isLoading || profileAsync.isLoading) {
        return state.matchedLocation == '/splash' ? null : '/splash';
      }

      final user = authAsync.asData?.value;
      final profile = profileAsync.asData?.value;
      final loc = state.matchedLocation;

      final isAuthFlow = loc == '/landing' || loc == '/login' || loc == '/splash';

      if (user == null) {
        return isAuthFlow && loc != '/splash' ? null : '/landing';
      }

      // Special-case admin login: name === "admin" routes into admin tools.
      if (user.displayName.toLowerCase() == 'admin') {
        if (loc.startsWith('/admin')) return null;
        return '/admin';
      }

      // User exists but onboarding not complete → /onboarding.
      if (profile == null) {
        return loc == '/onboarding' ? null : '/onboarding';
      }

      // Authenticated + onboarded: bounce out of auth/onboarding screens.
      if (isAuthFlow || loc == '/onboarding') return '/app';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashView()),
      GoRoute(path: '/landing', builder: (_, _) => const LandingView()),
      GoRoute(path: '/login', builder: (_, _) => const LoginView()),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingView()),
      GoRoute(path: '/app', builder: (_, _) => const MainScaffold()),
      GoRoute(path: '/admin', builder: (_, _) => const AdminDashboardView()),
      GoRoute(path: '/admin/workout', builder: (_, _) => const AdminInsertWorkoutView()),
      GoRoute(path: '/admin/recipe', builder: (_, _) => const AdminInsertRecipeView()),
      GoRoute(
        path: '/workout-history/:id',
        builder: (_, state) => WorkoutHistoryView(
          sessionId: int.parse(state.pathParameters['id']!),
        ),
      ),
    ],
  );
});
