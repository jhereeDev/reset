import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../badge_defs.dart' as defs;
import '../badge_providers.dart';

/// Invisible widget mounted in the app shell. Watches for newly unlocked
/// badges and celebrates each exactly once with a dialog.
class BadgeCelebrationListener extends ConsumerStatefulWidget {
  const BadgeCelebrationListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<BadgeCelebrationListener> createState() =>
      _BadgeCelebrationListenerState();
}

class _BadgeCelebrationListenerState
    extends ConsumerState<BadgeCelebrationListener> {
  bool _showing = false;

  @override
  Widget build(BuildContext context) {
    ref.listen(newBadgesProvider, (previous, next) {
      // Only celebrate transitions that happen while the app is in use —
      // and never stack dialogs.
      if (next.isEmpty || _showing) return;
      _showing = true;
      final ids = next.toList();
      // Deferred: celebrating marks badges seen, which rebuilds the very
      // provider this listener watches — doing that synchronously would
      // rebuild it twice in one frame (Riverpod forbids it).
      WidgetsBinding.instance.addPostFrameCallback((_) => _celebrate(ids));
    });
    return widget.child;
  }

  Future<void> _celebrate(List<String> ids) async {
    try {
      // Mark seen immediately so a crash/close can't re-celebrate forever.
      await ref.read(seenBadgesProvider.notifier).markSeen(ids);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      await showDialog<void>(
        context: context,
        builder: (context) => _BadgeDialog(ids: ids),
      );
    } finally {
      _showing = false;
    }
  }
}

class _BadgeDialog extends StatelessWidget {
  const _BadgeDialog({required this.ids});

  final List<String> ids;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badges = ids.map(defs.BadgeCatalog.byId).toList();

    return AlertDialog(
      title: Text(
        badges.length == 1 ? 'Trophy unlocked!' : 'Trophies unlocked!',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final badge in badges)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.4, end: 1),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.elasticOut,
                    builder: (context, scale, child) =>
                        Transform.scale(scale: scale, child: child),
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: badge.color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(badge.icon, color: badge.color, size: 28),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(badge.title, style: theme.textTheme.titleMedium),
                        Text(
                          badge.description,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Keep going 💪'),
        ),
      ],
    );
  }
}
