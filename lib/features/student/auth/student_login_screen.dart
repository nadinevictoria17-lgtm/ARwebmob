import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../teacher/students/student_id_format.dart';
import 'student_auth_providers.dart';

/// Student sign-in gate.
///
/// Shown before `main.dart`'s `ShadApp.router` for the signed-in student app
/// is reachable — `main.dart` wraps this screen in its own `ShadApp`
/// instance (mirroring the Teacher Web sign-in gate), so this screen itself
/// only ever builds a `Scaffold`, never its own top-level app widget.
class StudentLoginScreen extends HookConsumerWidget {
  const StudentLoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(studentAuthViewModelProvider);
    final auth = ref.read(studentAuthViewModelProvider.notifier);
    final idController = useTextEditingController(text: authState.idOrEmail);
    final passwordController = useTextEditingController(
      text: authState.password,
    );
    final obscurePassword = useState(true);
    final scheme = ShadTheme.of(context).colorScheme;

    Future<void> onSubmit() async {
      auth.idOrEmail = idController.text;
      auth.password = passwordController.text;
      await auth.submit();
    }

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 420;
            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isNarrow ? 20 : 24,
                  vertical: 32,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Brand/hero moment — mirrors the Teacher Web sign-in
                      // screen's icon badge + tagline + subject-accent dots,
                      // so both surfaces read as the same product.
                      Center(
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: (scheme.custom['physics'] ?? scheme.primary)
                                .withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            LucideIcons.flaskConical,
                            size: 32,
                            color: scheme.custom['physics'] ?? scheme.primary,
                          ),
                        ),
                      ).animate().fadeIn(duration: 240.ms),
                      const SizedBox(height: 16),
                      Text(
                        'AR Science Explorer',
                        style: ShadTheme.of(context).textTheme.h3,
                        textAlign: TextAlign.center,
                      ).animate().fadeIn(duration: 240.ms, delay: 30.ms),
                      const SizedBox(height: 6),
                      Text(
                        'Use your 6-digit student ID (or full '
                        '@arscience.school email) to sign in.',
                        style: ShadTheme.of(context).textTheme.muted,
                        textAlign: TextAlign.center,
                      ).animate().fadeIn(duration: 240.ms, delay: 50.ms),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (final key in [
                            'chemistry',
                            'biology',
                            'physics',
                          ]) ...[
                            Container(
                              width: 7,
                              height: 7,
                              margin: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.custom[key] ?? scheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 28),
                      ShadCard(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (authState.errorMessage != null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: scheme.destructive.withValues(
                                        alpha: 0.08,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          LucideIcons.circleAlert,
                                          size: 18,
                                          color: scheme.destructive,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            authState.errorMessage!,
                                            style: TextStyle(
                                              color: scheme.destructive,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                Text(
                                  'Student ID',
                                  style: ShadTheme.of(context).textTheme.small,
                                ),
                                const SizedBox(height: 6),
                                ShadInput(
                                  controller: idController,
                                  placeholder: const Text(
                                    '12-3456 or name@arscience.school',
                                  ),
                                  leading: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    child: Icon(
                                      LucideIcons.idCard,
                                      size: 16,
                                      color: scheme.mutedForeground,
                                    ),
                                  ),
                                  keyboardType: TextInputType.text,
                                  textInputAction: TextInputAction.next,
                                  inputFormatters: [StudentIdInputFormatter()],
                                  onChanged: (value) => auth.idOrEmail = value,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Password',
                                  style: ShadTheme.of(context).textTheme.small,
                                ),
                                const SizedBox(height: 6),
                                ShadInput(
                                  controller: passwordController,
                                  placeholder: const Text('••••••••'),
                                  leading: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    child: Icon(
                                      LucideIcons.lock,
                                      size: 16,
                                      color: scheme.mutedForeground,
                                    ),
                                  ),
                                  trailing: ShadIconButton.ghost(
                                    icon: Icon(
                                      obscurePassword.value
                                          ? LucideIcons.eye
                                          : LucideIcons.eyeOff,
                                      size: 16,
                                      color: scheme.mutedForeground,
                                    ),
                                    onPressed: () => obscurePassword.value =
                                        !obscurePassword.value,
                                  ),
                                  obscureText: obscurePassword.value,
                                  textInputAction: TextInputAction.done,
                                  onChanged: (value) => auth.password = value,
                                  onSubmitted: (_) => onSubmit(),
                                ),
                                const SizedBox(height: 20),
                                ShadButton(
                                  width: double.infinity,
                                  leading: authState.isSubmitting
                                      ? null
                                      : const Icon(LucideIcons.logIn, size: 18),
                                  onPressed: authState.isSubmitting
                                      ? null
                                      : onSubmit,
                                  child: Text(
                                    authState.isSubmitting
                                        ? 'Signing in…'
                                        : 'Sign in',
                                  ),
                                ),
                              ],
                            ),
                          )
                          .animate()
                          .fadeIn(duration: 260.ms, delay: 80.ms)
                          .slideY(
                            begin: 0.04,
                            end: 0,
                            duration: 260.ms,
                            delay: 80.ms,
                          ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
