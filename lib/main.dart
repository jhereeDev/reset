import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'core/backup/backup_service.dart';

/// Crash reporting is opt-in at build time:
/// `flutter build ... --dart-define=SENTRY_DSN=https://...`
/// Without a DSN the app runs with zero telemetry. When enabled we send
/// crash reports only — no performance traces, no PII, no analytics.
const _sentryDsn = String.fromEnvironment('SENTRY_DSN');

Future<void> main() async {
  if (_sentryDsn.isEmpty) {
    await _run();
    return;
  }
  await SentryFlutter.init((options) {
    options.dsn = _sentryDsn;
    options.tracesSampleRate = 0; // crashes only, no performance telemetry
    options.sendDefaultPii = false;
    options.attachScreenshot = false;
  }, appRunner: _run);
}

Future<void> _run() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );

  // Notification init is best-effort; the app runs fine without it.
  await container.read(notificationServiceProvider).init();

  runApp(
    UncontrolledProviderScope(container: container, child: const ResetApp()),
  );

  // Fire-and-forget: snapshot today's data once per day. Never blocks
  // startup and never throws.
  unawaited(container.read(backupServiceProvider).runDailyBackup());
}
