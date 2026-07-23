# Google Play listing — Reset

Copy-paste-ready content for the Play Console. Character limits noted.

## App name (30 chars max)

```
Reset — Daily Habit Rebuilder
```

(29 chars. "Reset" alone is likely taken; the suffix also helps search.)

## Short description (80 chars max)

```
Rebuild yourself with small daily actions. Habits, streaks, fresh starts.
```

(74 chars)

## Full description (4000 chars max)

```
Reset is for people who want to become a better version of themselves — one
small daily action at a time.

100 push-ups. A 10,000-step walk. One chapter. Making the bed. Small wins,
stacked daily, become who you are. Reset helps you show up for them without
guilt, pressure, or noise.

TRACK WHAT MATTERS
• Yes/no habits, counts, minutes, steps, pages, chapters, servings, or your
  own custom unit
• Quick-add buttons (+10 push-ups, +500 steps) and exact entry
• Flexible schedules: every day, specific weekdays, or N times per week
• Reorder, pause, archive — your list, your rules

RESET MODE — A STRUCTURED FRESH START
Pick a plan and rebuild momentum: 7-Day Restart, 21-Day Discipline Reset, or
30-Day Better Me. Preview and customize every habit before you begin. Missed
a day? No guilt — one day never undoes your progress.

SEE YOUR MOMENTUM
• Daily progress ring and streaks
• Weekly calendar and completion chart
• Per-habit stats: streaks, completion rate, 30-day history

YOURS. ACTUALLY YOURS.
• 100% offline — no account, no cloud, no ads, no tracking
• Your data never leaves your device, and you can export it anytime
• Gentle optional reminders, light & dark themes

Reset will never shame you for missing a day. It's built for people who start
again — and this time, keep going.
```

## Store assets

- **App icon (512×512)**: export from `assets/icon/icon.png`
  (`magick assets/icon/icon.png -resize 512x512 store/icon_512.png`)
- **Feature graphic (1024×500)**: required; gradient background + app name
  (generate similarly with ImageMagick if needed)
- **Phone screenshots (min 2, 16:9–9:16)**: captured emulator shots are in
  `store/screenshots/`

## Console form answers

- **Category**: Health & Fitness (or Productivity)
- **Privacy policy URL**: your GitHub Pages URL for `privacy_policy.md`
- **Data safety**: "No data collected, no data shared" (all questions No)
- **Ads**: No
- **Content rating questionnaire**: Utility/Productivity; no user-generated
  content, no violence, etc. → typically rated "Everyone"
- **Target audience**: 13+ recommended (avoids child-directed requirements)
- **App access**: All functionality available without special access
  (no login credentials needed for review)

## Release checklist

1. `flutter build appbundle --release`
2. Upload `build/app/outputs/bundle/release/app-release.aab` to
   **Production → Create new release** (or start with Internal testing)
3. Fill in the forms above, add assets, submit for review
4. **Back up `android/upload-keystore.jks` and `android/key.properties`
   somewhere safe (password manager + offline copy). Losing them means you
   can never update the app.**
