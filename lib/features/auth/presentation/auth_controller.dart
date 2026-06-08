import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../domain/app_user.dart';

class AuthController extends AsyncNotifier<AppUser?> {
  @override
  Future<AppUser?> build() async {
    final repo = ref.watch(localAuthRepositoryProvider);
    return repo.currentUser;
  }

  Future<void> signIn({required String displayName}) async {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) {
      state = AsyncError(
        ArgumentError('Display name cannot be empty'),
        StackTrace.current,
      );
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(localAuthRepositoryProvider);
      return repo.signIn(displayName: trimmed);
    });
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(localAuthRepositoryProvider);
      return repo.signInWithGoogle();
    });
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(localAuthRepositoryProvider);
      await repo.signOut();
      return null;
    });
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AppUser?>(AuthController.new);
