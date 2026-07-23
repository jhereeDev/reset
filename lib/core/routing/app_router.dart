import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/habits/presentation/habit_form_screen.dart';
import '../../features/habits/presentation/habit_list_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/profile/presentation/about_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/providers/preferences_providers.dart';
import '../../features/progress/presentation/habit_detail_screen.dart';
import '../../features/progress/presentation/progress_screen.dart';
import '../../features/reset/presentation/plan_preview_screen.dart';
import '../../features/reset/presentation/reset_screen.dart';
import '../../features/today/presentation/today_screen.dart';
import '../widgets/app_shell.dart';

abstract final class AppRoutes {
  static const onboarding = '/onboarding';
  static const today = '/today';
  static const reset = '/reset';
  static const progress = '/progress';
  static const profile = '/profile';
  static const habitNew = '/habits/new';
  static const habits = '/habits';
  static const about = '/profile/about';

  static String habitEdit(String id) => '/habits/$id/edit';

  static String habitDetail(String id) => '/progress/habit/$id';

  static String planPreview(String presetId) => '/reset/preview/$presetId';
}

final routerProvider = Provider<GoRouter>((ref) {
  final onboarded = ValueNotifier<bool>(
    ref.read(preferencesProvider.select((p) => p.onboardingComplete)),
  );
  ref
    ..listen(
      preferencesProvider.select((p) => p.onboardingComplete),
      (_, next) => onboarded.value = next,
    )
    ..onDispose(onboarded.dispose);

  final router = GoRouter(
    initialLocation: AppRoutes.today,
    refreshListenable: onboarded,
    redirect: (context, state) {
      final onOnboarding = state.matchedLocation == AppRoutes.onboarding;
      if (!onboarded.value && !onOnboarding) return AppRoutes.onboarding;
      if (onboarded.value && onOnboarding) return AppRoutes.today;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.today,
                builder: (context, state) => const TodayScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.reset,
                builder: (context, state) => const ResetScreen(),
                routes: [
                  GoRoute(
                    path: 'preview/:presetId',
                    builder: (context, state) => PlanPreviewScreen(
                      presetId: state.pathParameters['presetId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.progress,
                builder: (context, state) => const ProgressScreen(),
                routes: [
                  GoRoute(
                    path: 'habit/:id',
                    builder: (context, state) =>
                        HabitDetailScreen(habitId: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'about',
                    builder: (context, state) => const AboutScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.habits,
        builder: (context, state) => const HabitListScreen(),
      ),
      GoRoute(
        path: AppRoutes.habitNew,
        builder: (context, state) => const HabitFormScreen(),
      ),
      GoRoute(
        path: '/habits/:id/edit',
        builder: (context, state) =>
            HabitFormScreen(habitId: state.pathParameters['id']),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
