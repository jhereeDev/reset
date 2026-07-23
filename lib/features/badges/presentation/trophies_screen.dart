import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../badge_defs.dart' as defs;
import '../badge_providers.dart';

class TrophiesScreen extends ConsumerWidget {
  const TrophiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final unlocked = ref.watch(unlockedBadgesProvider);
    final total = defs.BadgeCatalog.all.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Trophies')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        children: [
          Text(
            '${unlocked.length} of $total unlocked',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            unlocked.length == total
                ? 'A full cabinet. Genuinely impressive.'
                : 'Trophies unlock themselves as you show up. No pressure — '
                      'they wait as long as it takes.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            childAspectRatio: 1.1,
            children: [
              for (final badge in defs.BadgeCatalog.all)
                _BadgeTile(badge: badge, unlocked: unlocked.contains(badge.id)),
            ],
          ),
        ],
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge, required this.unlocked});

  final defs.Badge badge;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.dividerColor;

    return Card(
      child: Semantics(
        label:
            '${badge.title}: ${badge.description}. '
            '${unlocked ? "Unlocked" : "Locked"}',
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: unlocked
                      ? badge.color.withValues(alpha: 0.15)
                      : muted.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  unlocked ? badge.icon : Icons.lock_outline_rounded,
                  color: unlocked ? badge.color : muted,
                  size: 30,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                badge.title,
                style: theme.textTheme.titleSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                badge.description,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
