import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_strings.dart';
import '../core/routing/app_router.dart';
import '../core/theme/app_theme.dart';
import 'providers.dart';
import '../features/profile/providers/preferences_providers.dart';

class ResetApp extends ConsumerStatefulWidget {
  const ResetApp({super.key});

  @override
  ConsumerState<ResetApp> createState() => _ResetAppState();
}

class _ResetAppState extends ConsumerState<ResetApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // The midnight-rollover Timer runs on monotonic time, so it misses
      // wall-clock jumps and can be delayed by deep sleep. Re-deriving the
      // date key on every resume keeps "today" correct; providers only
      // notify dependents when the value actually changed.
      ref.invalidate(todayKeyProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(preferencesProvider.select((p) => p.themeMode));
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
