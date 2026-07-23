# Reset — Product Roadmap

Decisions locked 2026-07-24: **one-time Pro unlock** (no subscription),
**full accounts + cloud sync** (v2.0), features: auto step tracking,
home-screen widgets, gamification, backup & restore. **Privacy-first crash
reporting** (crash data only, no behavioral analytics).

Sequencing principle: reliability before engagement, engagement before
platform integrations, and the backend + monetization land together in v2.0
— cloud sync is the natural headline Pro feature that justifies the price.

---

## v1.0 — Store launch (now)

- [x] Android: Play review in progress (closed testing → production)
- [x] iOS: build 1.0.0 (12) on TestFlight, iPhone-only
- [ ] iPhone screenshots + metadata → **Add for Review**
- [ ] Post-launch: watch reviews, fix anything urgent via patch releases
      (the CI pipeline makes an iOS patch a one-commit affair)

## v1.1 — Never lose a streak (reliability)

The trust release. Ship before growing the audience.

- [x] **Import / restore**: consume the JSON the app already exports; validation,
  merge-or-replace choice, schema-versioned for forward compatibility
- [x] **Automatic local backups**: daily silent export to app documents, keep
  last 7; restore surfaced in onboarding when a backup is detected after
  reinstall
- [x] **Sentry crash reporting** (code shipped, dormant until a DSN is
  configured via --dart-define): update privacy
  policy + both stores' data-safety forms to disclose crash data
- [x] Test coverage for the backup/restore flows (32 tests green)

## v1.2 — Make streaks feel alive (engagement)

- [x] **Gamification**: milestone badges (3/7/21/30/100-day streaks, first plan
  completed, 100 total wins…), a trophies section in Profile, celebratory
  moments on unlock (existing haptics + animation system reused)
- **Home-screen widgets**:
  - Android first (`home_widget` package + Glance): today's ring + top 3
    habits with quick-complete
  - iOS WidgetKit (needs a native Swift extension target + App Group shared
    storage; build via Codemagic as today)
- Streak-freeze token (earned by 7 perfect days, auto-spent on a missed day)
  — supportive-not-punitive, matches the brand voice

## v1.3 — Steps that count themselves (health)

- Implement `HealthStepSource` behind the existing `StepSource` interface
  using the `health` package (HealthKit on iOS, Health Connect on Android)
- Opt-in only; permission requested in-context from the steps habit card
- Merge rule: automatic readings pre-fill the day's value, manual edits win
- Store forms: health-data usage declarations both stores; policy update

## v2.0 — Accounts, sync, and Pro (the big one)

Backend: **Supabase** (Postgres + auth + row-level security; generous free
tier). The repository layer was built abstract for exactly this.

- **Auth**: email magic-link + Sign in with Apple (required once accounts
  exist) + Google
- **Sync engine**: local-first stays the source of truth; per-row
  updated-at last-write-wins, background push/pull, offline queue. Local
  mode remains fully functional without an account
- **Reset Pro — one-time unlock (~$4.99)** via `in_app_purchase`:
  - Cloud sync + multi-device (the headline)
  - Widgets, badge cosmetics, premium themes/icons
  - Free tier keeps everything that exists today — early adopters lose nothing
- Privacy policy rewrite, both stores' data forms redone, account-deletion
  flow (Apple requires in-app deletion when accounts exist)

## Standing quality bar (every release)

- `dart format` / `flutter analyze` / `flutter test` green in CI before ship
- No feature ships without its business logic under test
- Supportive language always; no guilt mechanics, no dark patterns
- The offline path keeps working forever — cloud is additive, never required
