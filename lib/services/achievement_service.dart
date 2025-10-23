// services/achievement_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/task_completion.dart';
import '../models/achievement_record.dart';

class AchievementService {
  static final AchievementService _instance = AchievementService._internal();
  factory AchievementService() => _instance;
  AchievementService._internal();

  static const String _keyTaskCompletions = 'task_completions';
  static const String _keyAchievementRecords = 'achievement_records';

  // ==================== Playback機能用の追加メソッド ====================

/// 【新規追加】指定月の4タスク全完了日リストを取得
Future<List<DateTime>> getFullCompletionDays(int year, int month) async {
  try {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final fullCompletionDays = <DateTime>[];
    
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(year, month, day);
      final completions = await getTaskCompletionsByDate(date);
      
      // 成功したタスクのユニークなIDを抽出
      final uniqueTaskIds = <String>{};
      for (final completion in completions) {
        if (completion.wasSuccessful) {
          uniqueTaskIds.add(completion.taskId);
        }
      }
      
      // 4タスク以上完了していれば全完了とみなす
      if (uniqueTaskIds.length >= 4) {
        fullCompletionDays.add(date);
      }
    }
    
    return fullCompletionDays;
  } catch (e) {
    print('❌ 月間全完了日取得エラー: $e');
    return [];
  }
}

/// 【新規追加】週間の日別完了数を取得
Future<Map<int, int>> getWeeklyCompletions(DateTime weekStart) async {
  try {
    final weeklyCounts = <int, int>{};
    
    for (int i = 0; i < 7; i++) {
      final date = weekStart.add(Duration(days: i));
      final completions = await getTaskCompletionsByDate(date);
      
      // 成功したタスクのみカウント
      final successCount = completions.where((c) => c.wasSuccessful).length;
      weeklyCounts[i] = successCount;
    }
    
    return weeklyCounts;
  } catch (e) {
    print('❌ 週間完了数取得エラー: $e');
    return {};
  }
}

/// 【新規追加】年間のトップアルバムランキングを取得
Future<List<Map<String, dynamic>>> getAnnualTopAlbums(int year) async {
  try {
    final yearStart = DateTime(year, 1, 1);
    final yearEnd = DateTime(year, 12, 31, 23, 59, 59);
    
    final allCompletions = await loadTaskCompletions();
    
    // 年間の成功タスクをフィルタ
    final yearCompletions = allCompletions.where((c) {
      return c.wasSuccessful &&
             c.completedAt.isAfter(yearStart.subtract(const Duration(days: 1))) &&
             c.completedAt.isBefore(yearEnd.add(const Duration(days: 1)));
    }).toList();
    
    // アルバムごとの再生回数を集計
    final albumCounts = <String, Map<String, dynamic>>{};
    
    for (final completion in yearCompletions) {
      final albumKey = completion.albumName ?? '不明なアルバム';
      
      if (!albumCounts.containsKey(albumKey)) {
        albumCounts[albumKey] = {
          'albumName': albumKey,
          'albumType': completion.albumType,
          'albumId': completion.albumId,
          'count': 0,
        };
      }
      albumCounts[albumKey]!['count'] = 
          (albumCounts[albumKey]!['count'] as int) + 1;
    }
    
    // 回数順にソート
    final sortedAlbums = albumCounts.values.toList()
      ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    
    return sortedAlbums;
  } catch (e) {
    print('❌ 年間トップアルバム取得エラー: $e');
    return [];
  }
}

  // タスク完了記録を保存
  Future<void> saveTaskCompletion(TaskCompletion completion) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 既存の完了記録を取得
      final completions = await loadTaskCompletions();
      
      // 新しい記録を追加
      completions.add(completion);
      
      // JSON形式で保存
      final completionsJson = completions.map((c) => c.toJson()).toList();
      final jsonString = jsonEncode(completionsJson);
      await prefs.setString(_keyTaskCompletions, jsonString);
      
      // 日別の達成記録も更新
      await _updateDailyAchievementRecord(completion);
      
      print('✅ タスク完了記録を保存しました: ${completion.taskTitle}');
    } catch (e) {
      print('❌ タスク完了記録保存エラー: $e');
      rethrow;
    }
  }

  // 全てのタスク完了記録を読み込み
  Future<List<TaskCompletion>> loadTaskCompletions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_keyTaskCompletions);
      
      if (jsonString != null) {
        final List<dynamic> completionsJson = jsonDecode(jsonString);
        return completionsJson
            .map((completionJson) => TaskCompletion.fromJson(completionJson))
            .toList();
      }
      
      return [];
    } catch (e) {
      print('❌ タスク完了記録読み込みエラー: $e');
      return [];
    }
  }

  // 特定日のタスク完了記録を取得
  Future<List<TaskCompletion>> getTaskCompletionsByDate(DateTime date) async {
    try {
      final allCompletions = await loadTaskCompletions();
      final targetDate = DateTime(date.year, date.month, date.day);
      
      return allCompletions.where((completion) {
        final completionDate = DateTime(
          completion.completedAt.year,
          completion.completedAt.month,
          completion.completedAt.day,
        );
        return completionDate.isAtSameMomentAs(targetDate);
      }).toList();
    } catch (e) {
      print('❌ 日別タスク完了記録取得エラー: $e');
      return [];
    }
  }

  // 達成記録を保存
  Future<void> saveAchievementRecord(AchievementRecord record) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 既存の達成記録を取得
      final records = await loadAchievementRecords();
      
      // 同じ日の記録があれば更新、なければ追加
      final existingIndex = records.indexWhere((r) => r.dateKey == record.dateKey);
      if (existingIndex >= 0) {
        records[existingIndex] = record;
      } else {
        records.add(record);
      }
      
      // 日付順にソート
      records.sort((a, b) => a.date.compareTo(b.date));
      
      // JSON形式で保存
      final recordsJson = records.map((r) => r.toJson()).toList();
      final jsonString = jsonEncode(recordsJson);
      await prefs.setString(_keyAchievementRecords, jsonString);
      
      print('✅ 達成記録を保存しました: ${record.dateKey}');
    } catch (e) {
      print('❌ 達成記録保存エラー: $e');
      rethrow;
    }
  }

  // 全ての達成記録を読み込み
  Future<List<AchievementRecord>> loadAchievementRecords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_keyAchievementRecords);
      
      if (jsonString != null) {
        final List<dynamic> recordsJson = jsonDecode(jsonString);
        return recordsJson
            .map((recordJson) => AchievementRecord.fromJson(recordJson))
            .toList();
      }
      
      return [];
    } catch (e) {
      print('❌ 達成記録読み込みエラー: $e');
      return [];
    }
  }

  // 特定日の達成記録を取得
  Future<AchievementRecord?> getAchievementRecord(DateTime date) async {
    try {
      final records = await loadAchievementRecords();
      final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      
      return records.firstWhere(
        (record) => record.dateKey == dateKey,
        orElse: () => throw StateError('Record not found'),
      );
    } catch (e) {
      return null;
    }
  }

  // 日別達成記録を更新（内部メソッド）
  Future<void> _updateDailyAchievementRecord(TaskCompletion completion) async {
    try {
      final date = DateTime(
        completion.completedAt.year,
        completion.completedAt.month,
        completion.completedAt.day,
      );
      
      // その日の全ての完了記録を取得
      final dayCompletions = await getTaskCompletionsByDate(date);
      
      // 統計を計算
      final taskCompletions = <String, int>{};
      final taskSuccesses = <String, int>{};
      final completedTaskIds = <String>[];
      
      for (final completion in dayCompletions) {
        taskCompletions[completion.taskId] = 
            (taskCompletions[completion.taskId] ?? 0) + 1;
        
        if (completion.wasSuccessful) {
          taskSuccesses[completion.taskId] = 
              (taskSuccesses[completion.taskId] ?? 0) + 1;
        }
        
        if (!completedTaskIds.contains(completion.taskId)) {
          completedTaskIds.add(completion.taskId);
        }
      }
      
      final totalCompleted = dayCompletions.length;
      final totalSuccessful = dayCompletions.where((c) => c.wasSuccessful).length;
      final achievementRate = totalCompleted > 0 ? totalSuccessful / totalCompleted : 0.0;
      
      // 達成記録を作成・保存
      final record = AchievementRecord(
        date: date,
        taskCompletions: taskCompletions,
        taskSuccesses: taskSuccesses,
        totalTasksCompleted: totalCompleted,
        totalTasksAttempted: totalCompleted,
        achievementRate: achievementRate,
        completedTaskIds: completedTaskIds,
      );
      
      await saveAchievementRecord(record);
    } catch (e) {
      print('❌ 日別達成記録更新エラー: $e');
    }
  }

  // タスク統計を取得
  Future<Map<String, dynamic>> getTaskStatistics() async {
    try {
      final completions = await loadTaskCompletions();
      final records = await loadAchievementRecords();
      
      // 基本統計
      final totalCompletions = completions.length;
      final totalSuccesses = completions.where((c) => c.wasSuccessful).length;
      final overallAchievementRate = totalCompletions > 0 ? totalSuccesses / totalCompletions : 0.0;
      
      // タスク別統計
      final taskStats = <String, Map<String, dynamic>>{};
      for (final completion in completions) {
        final taskId = completion.taskId;
        if (!taskStats.containsKey(taskId)) {
          taskStats[taskId] = {
            'title': completion.taskTitle,
            'totalAttempts': 0,
            'totalSuccesses': 0,
            'averageTime': 0.0,
            'totalTime': 0,
          };
        }
        
        taskStats[taskId]!['totalAttempts'] = (taskStats[taskId]!['totalAttempts'] as int) + 1;
        if (completion.wasSuccessful) {
          taskStats[taskId]!['totalSuccesses'] = (taskStats[taskId]!['totalSuccesses'] as int) + 1;
        }
        taskStats[taskId]!['totalTime'] = (taskStats[taskId]!['totalTime'] as int) + completion.elapsedSeconds;
      }
      
      // 平均時間を計算
      for (final stats in taskStats.values) {
        final totalTime = stats['totalTime'] as int;
        final totalAttempts = stats['totalAttempts'] as int;
        stats['averageTime'] = totalAttempts > 0 ? totalTime / totalAttempts : 0.0;
      }
      
      return {
        'totalCompletions': totalCompletions,
        'totalSuccesses': totalSuccesses,
        'overallAchievementRate': overallAchievementRate,
        'activeDays': records.length,
        'taskStatistics': taskStats,
        'recentCompletions': completions.take(10).toList(),
      };
    } catch (e) {
      print('❌ タスク統計取得エラー: $e');
      return {};
    }
  }

  // 完了記録のユニークIDを生成
  String generateCompletionId() {
    return 'completion_${DateTime.now().millisecondsSinceEpoch}';
  }

  // データをクリア（テスト用）
  Future<void> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyTaskCompletions);
      await prefs.remove(_keyAchievementRecords);
      print('✅ 全ての達成データをクリアしました');
    } catch (e) {
      print('❌ データクリアエラー: $e');
    }
  }
}