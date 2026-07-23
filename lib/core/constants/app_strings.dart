/// Central UI strings. Keeping them here (rather than scattered through
/// widgets) makes tone consistent and future localization straightforward.
abstract final class AppStrings {
  static const appName = 'Reset';
  static const tagline = 'Small actions. Big change.';

  // Navigation
  static const navToday = 'Today';
  static const navReset = 'Reset';
  static const navProgress = 'Progress';
  static const navProfile = 'Profile';

  // Common
  static const save = 'Save';
  static const cancel = 'Cancel';
  static const delete = 'Delete';
  static const undo = 'Undo';
  static const done = 'Done';
  static const next = 'Next';
  static const back = 'Back';
  static const getStarted = 'Get started';
  static const addHabit = 'Add habit';
  static const editHabit = 'Edit habit';
  static const newHabit = 'New habit';
  static const tryAgain = 'Try again';
  static const somethingWentWrong = 'Something went wrong';

  // Greetings by time of day
  static const goodMorning = 'Good morning';
  static const goodAfternoon = 'Good afternoon';
  static const goodEvening = 'Good evening';

  /// Rotating daily motivation. Picked deterministically by day-of-year.
  static const List<String> dailyMotivations = [
    'Every rep counts. Show up for yourself today.',
    'You don\'t need a perfect day — just a step forward.',
    'Consistency beats intensity. Keep the chain alive.',
    'Small actions, repeated, become who you are.',
    'Today is a fresh page. Write something good on it.',
    'Discipline is choosing what you want most over what you want now.',
    'One day at a time — and today is the day you\'ve got.',
    'Progress, not perfection.',
    'The best time to start was yesterday. The next best is right now.',
    'Future you is watching. Make them proud.',
    'You\'ve restarted before. That\'s not failure — that\'s persistence.',
    'Momentum loves company. Stack one more win.',
    'Do it tired. Do it unmotivated. Just do it small.',
    'A 1% better day is still a better day.',
  ];

  /// Shown right after completing a habit.
  static const List<String> completionCheers = [
    'Nice one! 🎉',
    'That\'s a win! 💪',
    'Done and dusted ✨',
    'Keep it rolling! 🔥',
    'Future you says thanks 🙌',
    'One step closer 🚀',
    'Momentum unlocked ⚡',
  ];

  static const allDoneToday = 'All done for today — enjoy the win! 🏆';
  static const nothingToday = 'Nothing scheduled today';
  static const nothingTodayHint =
      'Add a habit or start a Reset plan to fill your day with wins.';

  // Reset mode
  static const resetTitle = 'Reset Mode';
  static const resetIntro =
      'A structured fresh start. Pick a plan, keep it small, and rebuild momentum one day at a time.';
  static const missedDaySupport =
      'Missed a day? No guilt — one day never undoes your progress. Pick it back up today.';

  // Profile
  static const exportData = 'Export data';
  static const resetAppData = 'Reset app data';
  static const resetAppDataWarning =
      'This permanently deletes all habits, history, plans and settings on this device. This cannot be undone.';
  static const about = 'About';
}
