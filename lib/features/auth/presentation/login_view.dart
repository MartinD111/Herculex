import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/colors.dart';
import '../../../widgets/glass_container.dart';
import '../../../widgets/premium_button.dart';
import '../../../widgets/premium_text_field.dart';
import 'auth_controller.dart';

/// Local-only "login" — just captures a display name and creates the on-device
/// user record. Replaced by Google Sign-In via Firebase Auth in a later phase.
class LoginView extends ConsumerStatefulWidget {
  const LoginView({super.key});

  @override
  ConsumerState<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginView> {
  final _nameCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter your name');
      return;
    }
    setState(() => _error = null);
    await ref.read(authControllerProvider.notifier).signIn(displayName: name);
    if (!mounted) return;
    // Router redirect picks it up from here (→ /onboarding or /app).
    final state = ref.read(authControllerProvider);
    state.whenOrNull(error: (err, _) {
      setState(() => _error = err.toString());
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authControllerProvider);
    final loading = authState.isLoading;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/landing'),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: GlassContainer(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.monitor_heart, size: 64, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text("Welcome to Herculex", style: theme.textTheme.displayMedium),
                const SizedBox(height: 8),
                Text(
                  "Stored on this device. Cloud sync arrives in a later update.",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),
                PremiumTextField(
                  controller: _nameCtrl,
                  hintText: "Your name",
                  prefixIcon: Icons.person_outline,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.redAccent),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: PremiumButton(
                    text: loading ? "..." : "Continue",
                    onTap: loading ? () {} : _continue,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        "or",
                        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.secondary),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: PremiumButton(
                    text: loading ? "..." : "Sign in with Google",
                    icon: Icons.account_circle_outlined,
                    isPrimary: false,
                    onTap: loading
                        ? () {}
                        : () async {
                            await ref.read(authControllerProvider.notifier).signInWithGoogle();
                            if (!mounted) return;
                            final state = ref.read(authControllerProvider);
                            state.whenOrNull(error: (err, _) {
                              setState(() => _error = err.toString());
                            });
                          },
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Tip: use 'admin' to open the admin tools.",
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.secondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
