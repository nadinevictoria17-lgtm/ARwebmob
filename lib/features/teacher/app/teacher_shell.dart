import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/theme/theme_mode_provider.dart';
import '../auth/teacher_auth_providers.dart';

/// Adaptive shell for the Teacher Web target.
///
/// Three layouts, chosen by viewport width:
/// - `>= 1000`: full-width `NavigationRail` with icon + label.
/// - `720–999`: icon-only `NavigationRail` (labels dropped, destinations
///   stay reachable by icon + tooltip via `Text` label acting as the
///   rail's built-in tooltip source).
/// - `< 720`: an `AppBar` + `Drawer` — the rail's fixed side column doesn't
///   fit a narrow/tablet-portrait viewport, so navigation moves behind a
///   hamburger menu, the same pattern the rest of the web reaches for at
///   this breakpoint.
///
/// A light/dark toggle (see `theme_mode_provider.dart`) lives in the rail's
/// leading slot on wide layouts and the `AppBar`'s actions on narrow ones.
class TeacherShell extends ConsumerWidget {
  const TeacherShell({
    super.key,
    required this.child,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final Widget child;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  static const _labels = [
    'Dashboard',
    'Lessons',
    'Quizzes',
    'Students',
    'Reports',
    'Access Codes',
    'Teacher Access',
  ];

  static const _icons = [
    LucideIcons.layoutDashboard,
    LucideIcons.bookOpen,
    LucideIcons.clipboardList,
    LucideIcons.users,
    LucideIcons.lineChart,
    LucideIcons.keyRound,
    LucideIcons.shieldCheck,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < 720;
    final isExtended = width >= 1000;

    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final themeToggle = IconButton(
      tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
      icon: Icon(isDark ? LucideIcons.sun : LucideIcons.moon),
      onPressed: () => toggleThemeMode(ref),
    );

    final teacherEmail = ref.watch(currentTeacherEmailProvider).valueOrNull;

    final destinations = [
      for (var i = 0; i < _labels.length; i++)
        NavigationRailDestination(
          icon: Icon(_icons[i]),
          label: Text(_labels[i]),
        ),
    ];

    final clampedIndex = selectedIndex.clamp(0, _labels.length - 1);

    if (isCompact) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_labels[clampedIndex]),
          actions: [themeToggle, const SizedBox(width: 8)],
        ),
        drawer: Drawer(
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      for (var i = 0; i < _labels.length; i++)
                        ListTile(
                          leading: Icon(_icons[i]),
                          title: Text(_labels[i]),
                          selected: i == clampedIndex,
                          onTap: () {
                            Navigator.of(context).pop();
                            onDestinationSelected(i);
                          },
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                _AccountFooter(email: teacherEmail),
              ],
            ),
          ),
        ),
        body: child,
      );
    }

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: clampedIndex,
            onDestinationSelected: onDestinationSelected,
            labelType: isExtended
                ? NavigationRailLabelType.all
                : NavigationRailLabelType.none,
            // Item Analysis intentionally has no rail entry of its own: it
            // is inherently quiz-scoped (there is no standalone "all item
            // analysis" list to land on), so it's reachable only via the
            // quiz table's per-row icon button, which always carries the
            // quiz id/title it needs. A rail entry with no real independent
            // destination would either silently redirect elsewhere or need
            // an explanatory hint bolted onto another screen — an honest
            // "quiz-scoped only" affordance beats either.
            leading: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: themeToggle,
            ),
            // Account/sign-out — previously missing entirely (there was no
            // way to sign out of Teacher Web short of clearing cookies).
            // Bottom-anchored via `trailing` + `Expanded`/`Align`, the
            // standard NavigationRail idiom for pinning content to the
            // rail's foot regardless of how many destinations are above it.
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _RailSignOutButton(email: teacherEmail),
                ),
              ),
            ),
            destinations: destinations,
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
  final confirmed = await showShadDialog<bool>(
    context: context,
    builder: (context) => ShadDialog.alert(
      title: const Text('Sign out?'),
      description: const Text(
        "You'll need to sign in again to manage lessons, quizzes, and "
        'students.',
      ),
      actions: [
        ShadButton.outline(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ShadButton.destructive(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Sign out'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await ref.read(authServiceProvider).signOut();
  }
}

/// Wide-rail sign-out affordance: an icon button, with the signed-in
/// teacher's email as its tooltip so identity is still discoverable even
/// though the rail has no room for a persistent text label.
class _RailSignOutButton extends ConsumerWidget {
  const _RailSignOutButton({required this.email});

  final String? email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Tooltip(
      message: email == null ? 'Sign out' : 'Signed in as $email · Sign out',
      child: IconButton(
        icon: const Icon(LucideIcons.logOut),
        onPressed: () => _confirmSignOut(context, ref),
      ),
    );
  }
}

/// Compact-drawer footer: shows who's signed in and a full-width sign-out
/// row, mirroring [_RailSignOutButton] for the narrow layout where a
/// tooltip-only affordance wouldn't be discoverable (no hover on touch).
class _AccountFooter extends ConsumerWidget {
  const _AccountFooter({required this.email});

  final String? email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = ShadTheme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (email != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Icon(
                  LucideIcons.userRound,
                  size: 16,
                  color: scheme.mutedForeground,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    email!,
                    style: ShadTheme.of(context).textTheme.small,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ListTile(
          leading: Icon(LucideIcons.logOut, color: scheme.destructive),
          title: Text('Sign out', style: TextStyle(color: scheme.destructive)),
          onTap: () => _confirmSignOut(context, ref),
        ),
      ],
    );
  }
}
