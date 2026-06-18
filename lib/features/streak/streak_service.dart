import '../../core/db/database.dart';

class StreakData {
  final int currentStreak;
  final int longestStreak;
  final int totalDaysLogged;
  final int totalTransactions;
  final List<Achievement> achievements;

  const StreakData({
    required this.currentStreak,
    required this.longestStreak,
    required this.totalDaysLogged,
    required this.totalTransactions,
    required this.achievements,
  });
}

class Achievement {
  final String id;
  final String icon;
  final String title;
  final String description;
  final bool unlocked;

  const Achievement({
    required this.id,
    required this.icon,
    required this.title,
    required this.description,
    required this.unlocked,
  });
}

class StreakService {
  static Future<StreakData> compute() async {
    final db = AppDatabase.instance.db;

    // Get all distinct dates (as day-only) that have transactions
    final rows = await db.rawQuery(
      'SELECT DISTINCT date FROM transactions_tbl ORDER BY date ASC',
    );

    final totalTransactions = (await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM transactions_tbl',
    ))
        .first['cnt'] as int;

    if (rows.isEmpty) {
      return StreakData(
        currentStreak: 0,
        longestStreak: 0,
        totalDaysLogged: 0,
        totalTransactions: 0,
        achievements: _computeAchievements(0, 0, 0, 0),
      );
    }

    // Convert to unique calendar dates
    final dates = <DateTime>{};
    for (final r in rows) {
      final ms = r['date'] as int;
      final d = DateTime.fromMillisecondsSinceEpoch(ms);
      dates.add(DateTime(d.year, d.month, d.day));
    }
    final sorted = dates.toList()..sort();
    final totalDays = sorted.length;

    // Calculate current streak (from today backwards)
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    int currentStreak = 0;
    var checkDate = todayOnly;

    // Allow streak to start from today or yesterday
    if (dates.contains(checkDate)) {
      currentStreak = 1;
      checkDate = checkDate.subtract(const Duration(days: 1));
      while (dates.contains(checkDate)) {
        currentStreak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      }
    } else {
      // Check if yesterday had a transaction (grace period)
      checkDate = todayOnly.subtract(const Duration(days: 1));
      if (dates.contains(checkDate)) {
        currentStreak = 1;
        checkDate = checkDate.subtract(const Duration(days: 1));
        while (dates.contains(checkDate)) {
          currentStreak++;
          checkDate = checkDate.subtract(const Duration(days: 1));
        }
      }
    }

    // Calculate longest streak
    int longestStreak = 1;
    int runLength = 1;
    for (var i = 1; i < sorted.length; i++) {
      final diff = sorted[i].difference(sorted[i - 1]).inDays;
      if (diff == 1) {
        runLength++;
        if (runLength > longestStreak) longestStreak = runLength;
      } else {
        runLength = 1;
      }
    }

    return StreakData(
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      totalDaysLogged: totalDays,
      totalTransactions: totalTransactions,
      achievements: _computeAchievements(
        currentStreak,
        longestStreak,
        totalDays,
        totalTransactions,
      ),
    );
  }

  static List<Achievement> _computeAchievements(
    int currentStreak,
    int longestStreak,
    int totalDays,
    int totalTx,
  ) {
    return [
      Achievement(
        id: 'first_log',
        icon: '🌱',
        title: 'Mulai Catat',
        description: 'Catat transaksi pertama',
        unlocked: totalTx >= 1,
      ),
      Achievement(
        id: 'ten_tx',
        icon: '📝',
        title: 'Rajin Catat',
        description: '10 transaksi tercatat',
        unlocked: totalTx >= 10,
      ),
      Achievement(
        id: 'fifty_tx',
        icon: '📊',
        title: 'Data Driven',
        description: '50 transaksi tercatat',
        unlocked: totalTx >= 50,
      ),
      Achievement(
        id: 'hundred_tx',
        icon: '💯',
        title: 'Centurion',
        description: '100 transaksi tercatat',
        unlocked: totalTx >= 100,
      ),
      Achievement(
        id: 'streak_3',
        icon: '🔥',
        title: 'On Fire',
        description: 'Streak 3 hari berturut-turut',
        unlocked: longestStreak >= 3,
      ),
      Achievement(
        id: 'streak_7',
        icon: '⚡',
        title: 'Seminggu Konsisten',
        description: 'Streak 7 hari berturut-turut',
        unlocked: longestStreak >= 7,
      ),
      Achievement(
        id: 'streak_14',
        icon: '🏆',
        title: '2 Minggu Mantap',
        description: 'Streak 14 hari berturut-turut',
        unlocked: longestStreak >= 14,
      ),
      Achievement(
        id: 'streak_30',
        icon: '👑',
        title: 'Sebulan Penuh!',
        description: 'Streak 30 hari berturut-turut',
        unlocked: longestStreak >= 30,
      ),
      Achievement(
        id: 'days_7',
        icon: '📅',
        title: 'Pemula Disiplin',
        description: 'Log di 7 hari berbeda',
        unlocked: totalDays >= 7,
      ),
      Achievement(
        id: 'days_30',
        icon: '🗓️',
        title: 'Kebiasaan Terbentuk',
        description: 'Log di 30 hari berbeda',
        unlocked: totalDays >= 30,
      ),
      Achievement(
        id: 'days_100',
        icon: '🎯',
        title: 'Veteran Finansial',
        description: 'Log di 100 hari berbeda',
        unlocked: totalDays >= 100,
      ),
      Achievement(
        id: 'days_365',
        icon: '🏅',
        title: 'Setahun!',
        description: 'Log di 365 hari berbeda',
        unlocked: totalDays >= 365,
      ),
    ];
  }
}
