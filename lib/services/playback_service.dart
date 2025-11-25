// services/playback_service.dart
import 'package:flutter/material.dart';
import '../models/calendar_day_data.dart';
import '../models/playback_report.dart';
import '../models/task_completion.dart';
import '../services/achievement_service.dart';
import '../services/task_completion_service.dart';

class PlaybackService {
  static final PlaybackService _instance = PlaybackService._internal();
  factory PlaybackService() => _instance;
  PlaybackService._internal();

  final AchievementService _achievementService = AchievementService();
  final TaskCompletionService _taskCompletionService = TaskCompletionService();
  
  // キャッシュ（パフォーマンス最適化用）
  final Map<String, CalendarDayData> _calendarCache = {};
  final Map<String, PlaybackReport> _reportCache = {};

  // ==================== カレンダー用メソッド ====================
  
  /// 【新規追加】指定月のカレンダーデータを取得
  Future<List<CalendarDayData>> getMonthCalendarData(int year, int month) async {
    try {
      final daysInMonth = DateTime(year, month + 1, 0).day;
      final calendarData = <CalendarDayData>[];
      
      for (int day = 1; day <= daysInMonth; day++) {
        final date = DateTime(year, month, day);
        final dayData = await _getCalendarDayData(date);
        calendarData.add(dayData);
      }
      
      return calendarData;
    } catch (e) {
      print('❌ 月間カレンダーデータ取得エラー: $e');
      return [];
    }
  }
  
  Future<CalendarDayData> _getCalendarDayData(DateTime date) async {
  final cacheKey = _formatDateKey(date);
  
  // キャッシュチェック
  if (_calendarCache.containsKey(cacheKey)) {
    return _calendarCache[cacheKey]!;
  }
  
  try {
    // その日の完了記録を取得
    final completions = await _achievementService.getTaskCompletionsByDate(date);
    
    // 成功タスクのみをカウント
    final successfulCompletions = completions.where((c) => c.wasSuccessful).toList();
    
    // ユニークなタスクIDを抽出
    final uniqueTaskIds = <String>{};
    for (final completion in successfulCompletions) {
      uniqueTaskIds.add(completion.taskId);
    }
    
    // 🔧 変更：1タスク以上完了で緑丸表示（ハードル下げ）
    final isFullCompletion = uniqueTaskIds.length >= 1; // 🔧 4 → 1 に変更
    
    final dayData = CalendarDayData(
      date: date,
      completedTaskCount: successfulCompletions.length,
      isFullCompletion: isFullCompletion,
      completedTaskIds: uniqueTaskIds.toList(),
      successfulTaskCount: successfulCompletions.length,
    );
    
    // キャッシュに保存
    _calendarCache[cacheKey] = dayData;
    
    return dayData;
  } catch (e) {
    print('❌ 日別カレンダーデータ取得エラー: $e');
    return CalendarDayData.empty(date);
  }
}

  // ==================== デイリーレポート用メソッド ====================
  
  /// 【新規追加】デイリーレポートを取得
  Future<PlaybackReport> getDailyReport(DateTime date) async {
    final cacheKey = 'daily_${_formatDateKey(date)}';
    
    // キャッシュチェック
    if (_reportCache.containsKey(cacheKey)) {
      return _reportCache[cacheKey]!;
    }
    
    try {
      final taskHistory = await getDailyTaskHistory(date);
      final totalTasks = await getDailyTaskCount(date);
      
      final report = PlaybackReport.daily(
        date: date,
        taskHistory: taskHistory,
        totalTasks: totalTasks,
      );
      
      // キャッシュに保存
      _reportCache[cacheKey] = report;
      
      return report;
    } catch (e) {
      print('❌ デイリーレポート取得エラー: $e');
      return PlaybackReport.daily(
        date: date,
        taskHistory: [],
        totalTasks: 0,
      );
    }
  }
  
  /// 【新規追加】その日のタスク履歴を取得（時系列順）
  Future<List<TaskCompletion>> getDailyTaskHistory(DateTime date) async {
    try {
      final completions = await _achievementService.getTaskCompletionsByDate(date);
      
      // 成功したタスクのみを抽出
      final successfulCompletions = completions.where((c) => c.wasSuccessful).toList();
      
      // 完了時刻で昇順ソート（古い順）
      successfulCompletions.sort((a, b) => a.completedAt.compareTo(b.completedAt));
      
      return successfulCompletions;
    } catch (e) {
      print('❌ デイリータスク履歴取得エラー: $e');
      return [];
    }
  }
  
  /// 【新規追加】その日の完了タスク数を取得
  Future<int> getDailyTaskCount(DateTime date) async {
    try {
      final history = await getDailyTaskHistory(date);
      return history.length;
    } catch (e) {
      print('❌ デイリータスク数取得エラー: $e');
      return 0;
    }
  }

  // ==================== ウィークリーレポート用メソッド ====================
  
  /// 【新規追加】ウィークリーレポートを取得
  Future<PlaybackReport> getWeeklyReport(DateTime weekStart) async {
    final cacheKey = 'weekly_${_formatDateKey(weekStart)}';
    
    // キャッシュチェック
    if (_reportCache.containsKey(cacheKey)) {
      return _reportCache[cacheKey]!;
    }
    
    try {
      final dailyCounts = await getWeeklyCounts(weekStart);
      final totalTasks = dailyCounts.values.fold(0, (sum, count) => sum + count);
      final topTasks = await getWeeklyTopTasks(weekStart);
      
      final report = PlaybackReport.weekly(
        weekStart: weekStart,
        dailyCounts: dailyCounts,
        totalTasks: totalTasks,
        topTasks: topTasks,
      );
      
      // キャッシュに保存
      _reportCache[cacheKey] = report;
      
      return report;
    } catch (e) {
      print('❌ ウィークリーレポート取得エラー: $e');
      return PlaybackReport.weekly(
        weekStart: weekStart,
        dailyCounts: {},
        totalTasks: 0,
        topTasks: [],
      );
    }
  }
  
  /// 【新規追加】週間の日別完了数を取得（日曜=0, 土曜=6）
  Future<Map<int, int>> getWeeklyCounts(DateTime weekStart) async {
    try {
      final counts = <int, int>{};
      
      for (int i = 0; i < 7; i++) {
        final date = weekStart.add(Duration(days: i));
        final count = await getDailyTaskCount(date);
        counts[i] = count;
      }
      
      return counts;
    } catch (e) {
      print('❌ 週間カウント取得エラー: $e');
      return {};
    }
  }
  
  /// 【新規追加】週間のトップタスクを取得（上位3つ）
  Future<List<Map<String, dynamic>>> getWeeklyTopTasks(DateTime weekStart) async {
    try {
      final weekEnd = weekStart.add(const Duration(days: 7));
      final allCompletions = await _achievementService.loadTaskCompletions();
      
      // 週間のタスクをフィルタ
      final weekCompletions = allCompletions.where((c) {
        return c.wasSuccessful &&
               c.completedAt.isAfter(weekStart.subtract(const Duration(days: 1))) &&
               c.completedAt.isBefore(weekEnd);
      }).toList();
      
      // タスクごとの再生回数を集計
      final taskCounts = <String, Map<String, dynamic>>{};
      
      for (final completion in weekCompletions) {
        if (!taskCounts.containsKey(completion.taskId)) {
          taskCounts[completion.taskId] = {
            'taskId': completion.taskId,
            'taskTitle': completion.taskTitle,
            'count': 0,
          };
        }
        taskCounts[completion.taskId]!['count'] = 
            (taskCounts[completion.taskId]!['count'] as int) + 1;
      }
      
      // 回数順にソート
      final sortedTasks = taskCounts.values.toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
      
      // 上位3つを返す
      return sortedTasks.take(3).toList();
    } catch (e) {
      print('❌ 週間トップタスク取得エラー: $e');
      return [];
    }
  }

  // ==================== マンスリーレポート用メソッド ====================
  
  Future<PlaybackReport> getMonthlyReport(int year, int month) async {
  final cacheKey = 'monthly_${year}_${month}';
  
  // キャッシュチェック
  if (_reportCache.containsKey(cacheKey)) {
    return _reportCache[cacheKey]!;
  }
  
  try {
  final dailyTrend = await getMonthlyTrend(year, month);
  final totalTasks = dailyTrend.fold(0, (sum, count) => sum + count);
  final topAlbums = await getMonthlyTopAlbums(year, month);
  final topTasks = await getMonthlyTopTasks(year, month); // 🆕 追加
  
  final weeklyData = await _calculateWeeklyAverage(year, month);
  
  final report = PlaybackReport.monthly(
    year: year,
    month: month,
    dailyTrend: dailyTrend,
    weeklyAverage: (weeklyData['averages'] as List).cast<double>(),
    weekLabels: (weeklyData['labels'] as List).cast<String>(),
    totalTasks: totalTasks,
    topAlbums: topAlbums,
    topTasks: topTasks, // 🆕 追加
  );
    
    // キャッシュに保存
    _reportCache[cacheKey] = report;
    
    return report;
  } catch (e) {
    print('❌ マンスリーレポート取得エラー: $e');
    return PlaybackReport.monthly(
      year: year,
      month: month,
      dailyTrend: [],
      weeklyAverage: [],
      weekLabels: [],
      totalTasks: 0,
      topAlbums: [],
    );
  }
}

/// 【新規追加】週別平均タスク数を計算
Future<Map<String, List<dynamic>>> _calculateWeeklyAverage(int year, int month) async {
  try {
    // 月の最初と最後の日を取得
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);
    
    // 週別データを格納
    final weeklyAverages = <double>[]; // 🔧 修正：明示的に<double>型
    final weekLabels = <String>[];     // 🔧 修正：明示的に<String>型
    
    // 現在の週の開始日
    DateTime currentWeekStart = firstDay;
    int weekNumber = 1;
    
    while (currentWeekStart.isBefore(lastDay) || currentWeekStart.isAtSameMomentAs(lastDay)) {
      // その週の終了日を計算（日曜日 or 月末）
      DateTime currentWeekEnd = currentWeekStart.add(const Duration(days: 6));
      
      // 月末を超えないように調整
      if (currentWeekEnd.isAfter(lastDay)) {
        currentWeekEnd = lastDay;
      }
      
      // その週の日数
      final daysInWeek = currentWeekEnd.difference(currentWeekStart).inDays + 1;
      
      // その週のタスク数を集計
      int weekTotalTasks = 0;
      for (var date = currentWeekStart; 
           date.isBefore(currentWeekEnd.add(const Duration(days: 1))); 
           date = date.add(const Duration(days: 1))) {
        final dayCount = await getDailyTaskCount(date);
        weekTotalTasks += dayCount;
      }
      
      // 平均を計算（小数点第1位まで）
      final average = daysInWeek > 0 ? weekTotalTasks / daysInWeek : 0.0;
      
      weeklyAverages.add(double.parse(average.toStringAsFixed(1)));
      weekLabels.add('第${weekNumber}週');
      
      // 次の週へ
      currentWeekStart = currentWeekEnd.add(const Duration(days: 1));
      weekNumber++;
    }
    
    return {
      'averages': weeklyAverages,  // 🔧 既に<double>型なので問題なし
      'labels': weekLabels,        // 🔧 既に<String>型なので問題なし
    };
  } catch (e) {
    print('❌ 週別平均計算エラー: $e');
    return {
      'averages': <double>[],  // 🔧 修正：明示的に<double>[]
      'labels': <String>[],    // 🔧 修正：明示的に<String>[]
    };
  }
}
  
  /// 【新規追加】月間の日別トレンド（折れ線グラフ用）
  Future<List<int>> getMonthlyTrend(int year, int month) async {
    try {
      final daysInMonth = DateTime(year, month + 1, 0).day;
      final trend = <int>[];
      
      for (int day = 1; day <= daysInMonth; day++) {
        final date = DateTime(year, month, day);
        final count = await getDailyTaskCount(date);
        trend.add(count);
      }
      
      return trend;
    } catch (e) {
      print('❌ 月間トレンド取得エラー: $e');
      return [];
    }
  }
  
  /// 【新規追加】月間のトップアルバムを取得（上位3つ）
  Future<List<Map<String, dynamic>>> getMonthlyTopAlbums(int year, int month) async {
    try {
      final monthStart = DateTime(year, month, 1);
      final monthEnd = DateTime(year, month + 1, 0, 23, 59, 59);
      
      final allCompletions = await _achievementService.loadTaskCompletions();
      
      // 月間のタスクをフィルタ
      final monthCompletions = allCompletions.where((c) {
        return c.wasSuccessful &&
               c.completedAt.isAfter(monthStart.subtract(const Duration(days: 1))) &&
               c.completedAt.isBefore(monthEnd.add(const Duration(days: 1)));
      }).toList();
      
      // アルバムごとの再生回数を集計
      final albumCounts = <String, Map<String, dynamic>>{};
      
      for (final completion in monthCompletions) {
        final albumKey = completion.albumName ?? '不明なアルバム';
        
        if (!albumCounts.containsKey(albumKey)) {
          albumCounts[albumKey] = {
            'albumName': albumKey,
            'albumType': completion.albumType,
            'count': 0,
          };
        }
        albumCounts[albumKey]!['count'] = 
            (albumCounts[albumKey]!['count'] as int) + 1;
      }
      
      // 回数順にソート
      final sortedAlbums = albumCounts.values.toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
      
      // 上位3つを返す
      return sortedAlbums.take(3).toList();
    } catch (e) {
      print('❌ 月間トップアルバム取得エラー: $e');
      return [];
    }
  }

  /// 【新規追加】月間のトップタスクを取得（上位3つ）
Future<List<Map<String, dynamic>>> getMonthlyTopTasks(int year, int month) async {
  try {
    final monthStart = DateTime(year, month, 1);
    final monthEnd = DateTime(year, month + 1, 0, 23, 59, 59);
    
    final allCompletions = await _achievementService.loadTaskCompletions();
    
    // 月間のタスクをフィルタ
    final monthCompletions = allCompletions.where((c) {
      return c.wasSuccessful &&
             c.completedAt.isAfter(monthStart.subtract(const Duration(days: 1))) &&
             c.completedAt.isBefore(monthEnd.add(const Duration(days: 1)));
    }).toList();
    
    // タスクごとの再生回数を集計
    final taskCounts = <String, Map<String, dynamic>>{};
    
    for (final completion in monthCompletions) {
      if (!taskCounts.containsKey(completion.taskId)) {
        taskCounts[completion.taskId] = {
          'taskId': completion.taskId,
          'taskTitle': completion.taskTitle,
          'count': 0,
        };
      }
      taskCounts[completion.taskId]!['count'] = 
          (taskCounts[completion.taskId]!['count'] as int) + 1;
    }
    
    // 回数順にソート
    final sortedTasks = taskCounts.values.toList()
      ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    
    // 上位3つを返す
    return sortedTasks.take(3).toList();
  } catch (e) {
    print('❌ 月間トップタスク取得エラー: $e');
    return [];
  }
}

  // ==================== アニュアルレポート用メソッド ====================
  
  /// 【新規追加】アニュアルレポートを取得
  Future<PlaybackReport> getAnnualReport(int year) async {
    final cacheKey = 'annual_$year';
    
    // キャッシュチェック
    if (_reportCache.containsKey(cacheKey)) {
      return _reportCache[cacheKey]!;
    }
    
    try {
      final summary = await getAnnualSummary(year);
      
      final report = PlaybackReport.annual(
        year: year,
        totalTasks: summary['totalTasks'] ?? 0,
        totalMinutes: summary['totalMinutes'] ?? 0,
        topAlbums: summary['topAlbums'] ?? [],
        topTasks: summary['topTasks'] ?? [],
        maxStreakDays: summary['maxStreakDays'] ?? 0,
        peakMonth: summary['peakMonth'] ?? '不明',
      );
      
      // キャッシュに保存
      _reportCache[cacheKey] = report;
      
      return report;
    } catch (e) {
      print('❌ アニュアルレポート取得エラー: $e');
      return PlaybackReport.annual(
        year: year,
        totalTasks: 0,
        totalMinutes: 0,
        topAlbums: [],
        topTasks: [],
        maxStreakDays: 0,
        peakMonth: '不明',
      );
    }
  }
  
  /// 【新規追加】年間サマリーを取得
  Future<Map<String, dynamic>> getAnnualSummary(int year) async {
    try {
      final yearStart = DateTime(year, 1, 1);
      final yearEnd = DateTime(year, 12, 31, 23, 59, 59);
      
      final allCompletions = await _achievementService.loadTaskCompletions();
      
      // 年間のタスクをフィルタ
      final yearCompletions = allCompletions.where((c) {
        return c.wasSuccessful &&
               c.completedAt.isAfter(yearStart.subtract(const Duration(days: 1))) &&
               c.completedAt.isBefore(yearEnd.add(const Duration(days: 1)));
      }).toList();
      
      // 総タスク数
      final totalTasks = yearCompletions.length;
      
      // 総再生時間（分）
      final totalMinutes = yearCompletions.fold(0, 
          (sum, c) => sum + (c.elapsedSeconds ~/ 60));
      
      // トップアルバム（上位3つ）
      final topAlbums = await _getAnnualTopAlbums(yearCompletions);
      
      // トップタスク（上位3つ）
      final topTasks = await _getAnnualTopTasks(yearCompletions);
      
      // 最長連続達成日数
      final maxStreakDays = await _calculateMaxStreak(year);
      
      // 活動のピーク月
      final peakMonth = await _calculatePeakMonth(year);
      
      return {
        'totalTasks': totalTasks,
        'totalMinutes': totalMinutes,
        'topAlbums': topAlbums,
        'topTasks': topTasks,
        'maxStreakDays': maxStreakDays,
        'peakMonth': peakMonth,
      };
    } catch (e) {
      print('❌ 年間サマリー取得エラー: $e');
      return {};
    }
  }
  
  /// 【新規追加】年間トップアルバムを集計
  Future<List<Map<String, dynamic>>> _getAnnualTopAlbums(List<TaskCompletion> completions) async {
    try {
      final albumCounts = <String, Map<String, dynamic>>{};
      
      for (final completion in completions) {
        final albumKey = completion.albumName ?? '不明なアルバム';
        
        if (!albumCounts.containsKey(albumKey)) {
          albumCounts[albumKey] = {
            'albumName': albumKey,
            'albumType': completion.albumType,
            'count': 0,
          };
        }
        albumCounts[albumKey]!['count'] = 
            (albumCounts[albumKey]!['count'] as int) + 1;
      }
      
      final sortedAlbums = albumCounts.values.toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
      
      return sortedAlbums.take(3).toList();
    } catch (e) {
      print('❌ 年間トップアルバム集計エラー: $e');
      return [];
    }
  }
  
  /// 【新規追加】年間トップタスクを集計
  Future<List<Map<String, dynamic>>> _getAnnualTopTasks(List<TaskCompletion> completions) async {
    try {
      final taskCounts = <String, Map<String, dynamic>>{};
      
      for (final completion in completions) {
        if (!taskCounts.containsKey(completion.taskId)) {
          taskCounts[completion.taskId] = {
            'taskId': completion.taskId,
            'taskTitle': completion.taskTitle,
            'count': 0,
          };
        }
        taskCounts[completion.taskId]!['count'] = 
            (taskCounts[completion.taskId]!['count'] as int) + 1;
      }
      
      final sortedTasks = taskCounts.values.toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
      
      return sortedTasks.take(3).toList();
    } catch (e) {
      print('❌ 年間トップタスク集計エラー: $e');
      return [];
    }
  }
  
  /// 【新規追加】最長連続達成日数を計算
  Future<int> _calculateMaxStreak(int year) async {
    try {
      final yearStart = DateTime(year, 1, 1);
      final yearEnd = DateTime(year, 12, 31);
      
      int maxStreak = 0;
      int currentStreak = 0;
      
      for (var date = yearStart; 
           date.isBefore(yearEnd) || date.isAtSameMomentAs(yearEnd); 
           date = date.add(const Duration(days: 1))) {
        
        final count = await getDailyTaskCount(date);
        
        if (count > 0) {
          currentStreak++;
          if (currentStreak > maxStreak) {
            maxStreak = currentStreak;
          }
        } else {
          currentStreak = 0;
        }
      }
      
      return maxStreak;
    } catch (e) {
      print('❌ 最長連続日数計算エラー: $e');
      return 0;
    }
  }
  
  /// 【新規追加】活動のピーク月を計算
  Future<String> _calculatePeakMonth(int year) async {
    try {
      final monthlyCounts = <int, int>{};
      
      for (int month = 1; month <= 12; month++) {
        final trend = await getMonthlyTrend(year, month);
        final monthTotal = trend.fold(0, (sum, count) => sum + count);
        monthlyCounts[month] = monthTotal;
      }
      
      // 最大値の月を見つける
      int peakMonth = 1;
      int maxCount = 0;
      
      monthlyCounts.forEach((month, count) {
        if (count > maxCount) {
          maxCount = count;
          peakMonth = month;
        }
      });
      
      return '${peakMonth}月';
    } catch (e) {
      print('❌ ピーク月計算エラー: $e');
      return '不明';
    }
  }

  // ==================== ユーティリティメソッド ====================
  
  /// 【新規追加】日付をキー形式にフォーマット（YYYY-MM-DD）
  String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
  
  /// 【新規追加】キャッシュをクリア
  void clearCache() {
    _calendarCache.clear();
    _reportCache.clear();
    print('✅ Playbackサービスのキャッシュをクリアしました');
  }
  
  /// 【新規追加】特定日のキャッシュをクリア
  void clearDateCache(DateTime date) {
    final dateKey = _formatDateKey(date);
    _calendarCache.remove(dateKey);
    _reportCache.remove('daily_$dateKey');
    print('✅ $dateKey のキャッシュをクリアしました');
  }
}