import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.about)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.restart_alt_rounded,
                  size: 56,
                  color: Colors.white,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  AppStrings.appName,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                  ),
                ),
                Text(
                  AppStrings.tagline,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Reset helps you rebuild yourself through simple daily actions — '
            'a few push-ups, a chapter, a walk. Small wins, stacked daily, '
            'become who you are.\n\n'
            'Everything lives on your device: no account, no cloud, no ads. '
            'Your data is yours — export it anytime from Profile.\n\n'
            'Missing a day is human. Reset will never guilt you; it just '
            'helps you pick the thread back up.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xl),
          Card(
            child: Column(
              children: const [
                ListTile(
                  leading: Icon(Icons.numbers_rounded),
                  title: Text('Version'),
                  trailing: Text('1.0.0'),
                ),
                ListTile(
                  leading: Icon(
                    Icons.favorite_rounded,
                    color: AppColors.personalCare,
                  ),
                  title: Text('Made for people who start again'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
