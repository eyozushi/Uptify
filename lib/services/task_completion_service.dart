// services/task_completion_service.dart - 観客数管理機能追加版（全機能保持）
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';
import '../services/data_service.dart';
import '../services/achievement_service.dart';
import '../models/task_completion.dart';
import '../models/task_item.dart';
import 'dart:math' as math;
import 'dart:convert';

class TaskCompletionService {
  static final TaskCompletionService _instance = TaskCompletionService._internal();
  factory TaskCompletionService() => _instance;
  TaskCompletionService._internal();

  final NotificationService _notificationService = NotificationService();
  final DataService _dataService = DataService();
  final AchievementService _achievementService = AchievementService(); 
  
  static const int _taskCompletionNotificationBaseId = 200;
  int _nextNotificationId = _taskCompletionNotificationBaseId;
  
  // 観客数管理用のキー（追加）
  static const String _currentAudienceKey = 'current_audience_count';
  static const String _isInitializedKey = 'audience_system_initialized';


  // 🆕 Record Gaugeキャッシュクリア用メソッドを追加
  Future<void> _clearRecordGaugeCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('record_gauge_state');
      print('✅ Record Gaugeキャッシュをクリア');
    } catch (e) {
      print('❌ Record Gaugeキャッシュクリアエラー: $e');
    }
  }


  // 励ましメッセージのリスト
  static const List<String> _motivationalMessages = [
    'すばらしい集中力ですね！この調子で続けましょう！',
    'もう半分以上完了しました！あと少しです！',
    '着実に進歩していますね。自分を褒めてあげましょう！',
    'ここまで来れたあなたなら、きっと最後までできます！',
    '一歩一歩、理想の自分に近づいています！',
    '今日のあなたは昨日の自分を超えています！',
    'この努力が未来のあなたを作ります！',
    '継続は力なり。今の頑張りが結果につながります！',
  ];

  // アルバム完了メッセージのバリエーション
  static const List<String> _albumCompletionMessages = [
    'おめでとうございます！すべてのタスクを完了しました！',
    '素晴らしい集中力でした！目標達成です！',
    'お疲れ様でした！今日の自分に拍手を送りましょう！',
    '完璧です！理想の自分にまた一歩近づきました！',
    'やりましたね！この勢いで明日も頑張りましょう！',
  ];

  // 🆕 観客数管理メソッド（追加）
  
  /// 観客数システムを初期化（初回のみ）
  Future<void> initializeAudienceSystem() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isInitialized = prefs.getBool(_isInitializedKey) ?? false;
      
      if (!isInitialized) {
        // 初回のみ：累計完了タスク数を初期観客数として設定
        final totalCompleted = await getTotalCompletedTasks();
        await prefs.setInt(_currentAudienceKey, totalCompleted);
        await prefs.setBool(_isInitializedKey, true);
        
        print('観客数システム初期化完了: 初期観客数 = $totalCompleted人');
      }
    } catch (e) {
      print('観客数システム初期化エラー: $e');
    }
  }
  
  /// 現在の観客数を取得
  Future<int> getCurrentAudienceCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_currentAudienceKey) ?? 0;
    } catch (e) {
      print('現在の観客数取得エラー: $e');
      return 0;
    }
  }
  
  /// 観客数を追加（入場処理）
  Future<void> addAudienceMembers(int count) async {
    try {
      if (count <= 0) return;
      
      final prefs = await SharedPreferences.getInstance();
      final currentCount = await getCurrentAudienceCount();
      final newCount = currentCount + count;
      
      await prefs.setInt(_currentAudienceKey, newCount);
      print('観客数更新: $currentCount人 → $newCount人 (+$count人)');
    } catch (e) {
      print('観客数追加エラー: $e');
    }
  }
  
  /// 新規完了タスク数を取得（前回チェック以降の増加分）
  Future<int> getNewCompletedTasksSince(int lastKnownCount) async {
    try {
      final currentTotal = await getTotalCompletedTasks();
      final newTasks = math.max(0, currentTotal - lastKnownCount);
      return newTasks;
    } catch (e) {
      print('新規完了タスク数取得エラー: $e');
      return 0;
    }
  }

  // 累計データ取得メソッド（既存機能保持）

  /// 累計完了タスク数を取得（成功のみ）
  Future<int> getTotalCompletedTasks() async {
    try {
      final completions = await _achievementService.loadTaskCompletions();
      return completions.where((completion) => completion.wasSuccessful).length;
    } catch (e) {
      print('累計完了タスク数取得エラー: $e');
      return 0;
    }
  }

  /// 累計タスク実行数を取得（成功・失敗含む）
  Future<int> getTotalAttemptedTasks() async {
    try {
      final completions = await _achievementService.loadTaskCompletions();
      return completions.length;
    } catch (e) {
      print('累計実行タスク数取得エラー: $e');
      return 0;
    }
  }

  /// 累計達成率を計算
  Future<double> getTotalAchievementRate() async {
    try {
      final totalAttempted = await getTotalAttemptedTasks();
      if (totalAttempted == 0) return 0.0;
      
      final totalCompleted = await getTotalCompletedTasks();
      return totalCompleted / totalAttempted;
    } catch (e) {
      print('累計達成率計算エラー: $e');
      return 0.0;
    }
  }

  /// 【新規追加】今日のユニーク完了タスクIDリストを取得（成功のみ）
  Future<List<String>> getTodayCompletedUniqueTaskIds() async {
    try {
      final today = DateTime.now();
      final todayCompletions = await _achievementService.getTaskCompletionsByDate(today);
      
      // 成功したタスクのユニークなIDを抽出
      final uniqueTaskIds = <String>{};
      for (final completion in todayCompletions) {
        if (completion.wasSuccessful) {
          uniqueTaskIds.add(completion.taskId);
        }
      }
      
      return uniqueTaskIds.toList();
    } catch (e) {
      print('❌ 今日のユニークタスクID取得エラー: $e');
      return [];
    }
  }

  /// 【新規追加】今日の4タスク全完了判定（ドリームアルバム専用）
  Future<bool> isDreamAlbumFullyCompletedToday() async {
    try {
      final completedTaskIds = await getTodayCompletedUniqueTaskIds();
      
      // 4種類以上のユニークタスクが完了していればtrue
      return completedTaskIds.length >= 4;
    } catch (e) {
      print('❌ 4タスク全完了判定エラー: $e');
      return false;
    }
  }

  /// 【新規追加】今日完了したタスクのインデックスリストを取得（トラック順）
  /// 戻り値: 完了したタスクの位置を示すインデックス（0〜3）
  Future<List<int>> getTodayCompletedTaskIndices() async {
    try {
      final userData = await _dataService.loadUserData();
      List<TaskItem> allTasks = [];
      
      // ユーザーの4タスクを取得
      if (userData['tasks'] != null) {
        if (userData['tasks'] is List<TaskItem>) {
          allTasks = List<TaskItem>.from(userData['tasks']);
        } else if (userData['tasks'] is List) {
          allTasks = (userData['tasks'] as List)
              .map((taskJson) => TaskItem.fromJson(taskJson))
              .take(4)
              .toList();
        }
      }
      
      if (allTasks.isEmpty) {
        allTasks = _dataService.getDefaultTasks();
      }
      
      // 今日完了したタスクIDを取得
      final completedTaskIds = await getTodayCompletedUniqueTaskIds();
      
      // 完了したタスクのインデックスを特定
      final completedIndices = <int>[];
      for (int i = 0; i < allTasks.length && i < 4; i++) {
        if (completedTaskIds.contains(allTasks[i].id)) {
          completedIndices.add(i);
        }
      }
      
      return completedIndices;
    } catch (e) {
      print('❌ 完了タスクインデックス取得エラー: $e');
      return [];
    }
  }


  /// 過去N日間の日別完了数を取得
  Future<Map<String, int>> getDailyCompletions({int days = 7}) async {
    try {
      final completions = await _achievementService.loadTaskCompletions();
      final now = DateTime.now();
      final dailyData = <String, int>{};
      
      // 過去N日間のデータを初期化
      for (int i = 0; i < days; i++) {
        final date = now.subtract(Duration(days: i));
        final dateKey = _formatDateKey(date);
        dailyData[dateKey] = 0;
      }
      
      // 完了データを日別に集計
      for (final completion in completions) {
        if (!completion.wasSuccessful) continue;
        
        final dateKey = _formatDateKey(completion.completedAt);
        final daysDifference = now.difference(completion.completedAt).inDays;
        
        if (daysDifference >= 0 && daysDifference < days) {
          dailyData[dateKey] = (dailyData[dateKey] ?? 0) + 1;
        }
      }
      
      return dailyData;
    } catch (e) {
      print('日別完了数取得エラー: $e');
      return {};
    }
  }

  /// 日付をキー形式にフォーマット（YYYY-MM-DD）
  String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // ==================== 既存の高度な通知システム（全機能保持） ====================

  // 高度なタスク切り替え通知（自動再生用）
  Future<void> sendAdvancedTaskTransitionNotification({
    required TaskItem completedTask,
    required TaskItem nextTask,
    required String albumName,
    required String albumType,
    String? albumId,
    required int currentTaskNumber,
    required int totalTasks,
    required int elapsedSeconds,
    required int totalElapsedMinutes,
  }) async {
    try {
      // 通知内容をカスタマイズ
      final payload = createNotificationPayload(
        taskId: nextTask.id,
        taskTitle: nextTask.title,
        albumName: albumName,
        albumType: albumType,
        albumId: albumId,
        elapsedSeconds: elapsedSeconds,
        notificationType: 'advanced_task_transition',
      );

      await _notificationService.showTaskTransitionNotification(
        completedTaskTitle: completedTask.title,
        nextTaskTitle: nextTask.title,
        albumName: albumName,
        currentTaskNumber: currentTaskNumber,
        totalTasks: totalTasks,
        payload: payload,
      );

      // 特定の条件で励まし通知も送信
      if (_shouldSendMotivationalMessage(currentTaskNumber, totalTasks)) {
        await _sendContextualMotivationalNotification(
          albumName: albumName,
          currentTaskNumber: currentTaskNumber,
          totalTasks: totalTasks,
          totalElapsedMinutes: totalElapsedMinutes,
        );
      }
      
      print('高度なタスク切り替え通知を送信: ${completedTask.title} → ${nextTask.title}');
    } catch (e) {
      print('高度なタスク切り替え通知送信エラー: $e');
    }
  }

  // 高度なアルバム完了通知（自動再生用）
  Future<void> sendAdvancedAlbumCompletionNotification({
    required String albumName,
    required String albumType,
    String? albumId,
    required List<TaskItem> completedTasks,
    required int totalElapsedMinutes,
    required bool isConsecutiveCompletion,
  }) async {
    try {
      final totalTasks = completedTasks.length;
      final completionMessage = _getRandomCompletionMessage();
      
      // 連続完了の場合は特別なメッセージを追加
      final bonusMessage = isConsecutiveCompletion 
          ? '\n連続達成ボーナス！素晴らしい継続力です！' 
          : '';

      final payload = createNotificationPayload(
        taskId: 'album_completion_advanced',
        taskTitle: albumName,
        albumName: albumName,
        albumType: albumType,
        albumId: albumId,
        elapsedSeconds: totalElapsedMinutes * 60,
        notificationType: 'advanced_album_completion',
      );

      await _notificationService.showAlbumCompletionNotification(
        albumName: albumName,
        totalTasks: totalTasks,
        totalDurationMinutes: totalElapsedMinutes,
        payload: payload,
      );
      
      print('高度なアルバム完了通知を送信: $albumName ($totalTasks タスク, $totalElapsedMinutes 分)');
    } catch (e) {
      print('高度なアルバム完了通知送信エラー: $e');
    }
  }

  // コンテキスト対応の励まし通知
  Future<void> _sendContextualMotivationalNotification({
    required String albumName,
    required int currentTaskNumber,
    required int totalTasks,
    required int totalElapsedMinutes,
  }) async {
    try {
      String message = _getContextualMotivationalMessage(
        currentTaskNumber: currentTaskNumber,
        totalTasks: totalTasks,
        elapsedMinutes: totalElapsedMinutes,
      );

      final payload = createNotificationPayload(
        taskId: 'motivational_${DateTime.now().millisecondsSinceEpoch}',
        taskTitle: 'Motivational Message',
        albumName: albumName,
        albumType: 'motivation',
        albumId: null,
        elapsedSeconds: totalElapsedMinutes * 60,
        notificationType: 'contextual_motivation',
      );

      // 少し遅延してから送信（タスク切り替え通知と重複しないように）
      await Future.delayed(const Duration(seconds: 2));

      await _notificationService.showMotivationalNotification(
        message: message,
        albumName: albumName,
        currentTaskNumber: currentTaskNumber,
        totalTasks: totalTasks,
        payload: payload,
      );

      print('コンテキスト励まし通知を送信: $message');
    } catch (e) {
      print('コンテキスト励まし通知送信エラー: $e');
    }
  }

  // 進捗追跡通知（長時間アルバム用）
  Future<void> sendProgressTrackingNotification({
    required TaskItem currentTask,
    required String albumName,
    required int currentTaskNumber,
    required int totalTasks,
    required int totalElapsedMinutes,
  }) async {
    try {
      final payload = createNotificationPayload(
        taskId: currentTask.id,
        taskTitle: currentTask.title,
        albumName: albumName,
        albumType: 'progress_tracking',
        albumId: null,
        elapsedSeconds: totalElapsedMinutes * 60,
        notificationType: 'progress_tracking',
      );

      await _notificationService.showProgressUpdateNotification(
        currentTaskTitle: currentTask.title,
        currentTaskNumber: currentTaskNumber,
        totalTasks: totalTasks,
        albumName: albumName,
        elapsedMinutes: totalElapsedMinutes,
        payload: payload,
      );

      print('進捗追跡通知を送信: ${currentTask.title} ($currentTaskNumber/$totalTasks)');
    } catch (e) {
      print('進捗追跡通知送信エラー: $e');
    }
  }

  // 励まし通知を送信すべきかの判定
  bool _shouldSendMotivationalMessage(int currentTaskNumber, int totalTasks) {
    // 中間地点（50%完了時）や3/4完了時に送信
    final progressPercentage = (currentTaskNumber / totalTasks);
    return progressPercentage >= 0.5 && progressPercentage <= 0.75 && currentTaskNumber % 2 == 0;
  }

  // コンテキストに応じた励ましメッセージの生成
  String _getContextualMotivationalMessage({
    required int currentTaskNumber,
    required int totalTasks,
    required int elapsedMinutes,
  }) {
    final progressPercentage = (currentTaskNumber / totalTasks * 100).round();
    final random = math.Random();
    
    if (progressPercentage >= 75) {
      // 終盤の励まし
      return 'もうすぐゴールです！$progressPercentage%完了。最後まで一緒に頑張りましょう！';
    } else if (progressPercentage >= 50) {
      // 中盤の励まし
      return '半分以上完了しました！($progressPercentage%) この調子で続けましょう！';
    } else if (elapsedMinutes >= 30) {
      // 長時間継続の励まし
      return '${elapsedMinutes}分間お疲れ様です！素晴らしい集中力ですね！';
    } else {
      // 一般的な励まし
      return _motivationalMessages[random.nextInt(_motivationalMessages.length)];
    }
  }

  // ランダムな完了メッセージの取得
  String _getRandomCompletionMessage() {
    final random = math.Random();
    return _albumCompletionMessages[random.nextInt(_albumCompletionMessages.length)];
  }

  // 自動再生中の動的通知調整
  Future<void> adjustNotificationFrequency({
    required int totalTasks,
    required int currentTaskNumber,
    required Duration totalElapsedTime,
  }) async {
    try {
      // タスク数や経過時間に応じて通知頻度を調整
      if (totalTasks <= 3) {
        // 短いアルバム：最小限の通知
        print('短いアルバム: 通知頻度を最小限に調整');
      } else if (totalTasks <= 6) {
        // 中程度のアルバム：標準的な通知
        print('中程度のアルバム: 標準通知頻度を維持');
      } else {
        // 長いアルバム：頻繁な励まし通知
        print('長いアルバム: 励まし通知頻度を増加');
      }
      
      // 長時間実行時の特別な配慮
      if (totalElapsedTime.inMinutes > 60) {
        print('長時間実行検出: 疲労軽減通知を有効化');
      }
    } catch (e) {
      print('通知頻度調整エラー: $e');
    }
  }

  String createDetailedNotificationPayload({
    required String notificationType,
    required int currentTaskIndex,
    required int totalTasks,
    required String albumName,
    required String albumType,
    String? albumId,
    required int totalElapsedSeconds,
    required List<String> completedTaskIds,
    required bool isAutoPlayEnabled,
  }) {
    final payload = {
      'type': notificationType,
      'currentTaskIndex': currentTaskIndex.toString(),
      'totalTasks': totalTasks.toString(),
      'albumName': albumName,
      'albumType': albumType,
      'albumId': albumId ?? '',
      'totalElapsedSeconds': totalElapsedSeconds.toString(),
      'completedTaskIds': completedTaskIds.join(','),
      'isAutoPlayEnabled': isAutoPlayEnabled.toString(),
      'notificationType': notificationType,
      'createdAt': DateTime.now().toIso8601String(),
    };
    
    return payload.entries
        .where((e) => e.value != null && e.value.toString().isNotEmpty)
        .map((e) => '${e.key}=${e.value}')
        .join('&');
  }

  String createNotificationPayload({
    required String taskId,
    required String taskTitle,
    required String albumName,
    required String albumType,
    String? albumId,
    required int elapsedSeconds,
    required String notificationType,
  }) {
    final payload = {
      'type': notificationType,
      'taskId': taskId,
      'taskTitle': taskTitle,
      'albumName': albumName,
      'albumType': albumType,
      'albumId': albumId ?? '',
      'elapsedSeconds': elapsedSeconds.toString(),
      'completedAt': DateTime.now().toIso8601String(),
    };
    
    return payload.entries
        .where((e) => e.value != null && e.value.toString().isNotEmpty)
        .map((e) => '${e.key}=${e.value}')
        .join('&');
  }

  Map<String, String> parseNotificationPayload(String payload) {
    final result = <String, String>{};
    
    try {
      final pairs = payload.split('&');
      for (final pair in pairs) {
        final parts = pair.split('=');
        if (parts.length == 2) {
          result[parts[0]] = parts[1];
        }
      }
    } catch (e) {
      print('通知ペイロード解析エラー: $e');
    }
    
    return result;
  }

  Future<void> sendTaskPlayCompletedNotification({
    required TaskItem task,
    required String albumName,
    required String albumType,
    String? albumId,
    required int elapsedSeconds,
  }) async {
    try {
      final title = 'タスク再生完了！';
      final body = '「${task.title}」を再生しました。このタスクはできましたか？';
      
      await _notificationService.showTaskCompletionNotification(
        id: _nextNotificationId++,
        taskTitle: task.title,
        albumName: albumName,
        payload: createNotificationPayload(
          taskId: task.id,
          taskTitle: task.title,
          albumName: albumName,
          albumType: albumType,
          albumId: albumId,
          elapsedSeconds: elapsedSeconds,
          notificationType: 'task_play_completed',
        ),
      );
      
      print('タスク再生完了通知を送信しました: ${task.title}');
      
      if (_nextNotificationId > _taskCompletionNotificationBaseId + 100) {
        _nextNotificationId = _taskCompletionNotificationBaseId;
      }
    } catch (e) {
      print('タスク再生完了通知送信エラー: $e');
    }
  }

  Future<void> recordTaskCompletion({
    required String taskId,
    required String taskTitle,
    required bool wasSuccessful,
    required int elapsedSeconds,
    required String albumType,
    required String albumName,
    String? albumId,
    DateTime? startedAt,
    DateTime? completedAt,
  }) async {
    try {
      final completion = TaskCompletion(
        id: _dataService.generateCompletionId(),
        taskId: taskId,
        taskTitle: taskTitle,
        startedAt: startedAt ?? DateTime.now().subtract(Duration(seconds: elapsedSeconds)),
        completedAt: completedAt ?? DateTime.now(),
        wasSuccessful: wasSuccessful,
        elapsedSeconds: elapsedSeconds,
        albumType: albumType,
        albumId: albumId,
        albumName: albumName,
      );
      
      await _dataService.saveTaskCompletion(completion);
      await _dataService.addTaskCompletionToUserData(taskId, completion.completedAt);
      
      // 🆕 ライフドリームアルバムのタスク完了時はキャッシュをクリア
      if (wasSuccessful && albumType == 'life_dream') {
        await _clearRecordGaugeCache();
      }
      
      print('タスク完了記録を保存しました: $taskTitle (成功: $wasSuccessful)');
    } catch (e) {
      print('タスク完了記録保存エラー: $e');
      rethrow;
    }
  }

  Future<void> recordTaskCompletionFromNotification({
    required String taskId,
    required String taskTitle,
    required String albumName,
    required String albumType,
    String? albumId,
    required int elapsedSeconds,
    required bool wasSuccessful,
  }) async {
    try {
      await recordTaskCompletion(
        taskId: taskId,
        taskTitle: taskTitle,
        wasSuccessful: wasSuccessful,
        elapsedSeconds: elapsedSeconds,
        albumType: albumType,
        albumName: albumName,
        albumId: albumId,
      );
      
      print('通知からのタスク完了記録が完了しました: $taskTitle (成功: $wasSuccessful)');
    } catch (e) {
      print('通知からのタスク完了記録エラー: $e');
    }
  }

  Future<int> getTodayTaskSuccesses(String taskId) async {
    try {
      final today = DateTime.now();
      final todayCompletions = await _dataService.getTaskCompletionsByDate(today);
      
      return todayCompletions
          .where((completion) => completion.taskId == taskId && completion.wasSuccessful)
          .length;
    } catch (e) {
      print('今日のタスク成功回数取得エラー: $e');
      return 0;
    }
  }

  /// 【新規追加】特定月の日別タスク完了数を取得
Future<Map<int, int>> getMonthlyDailyCompletions(int year, int month) async {
  try {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final dailyCounts = <int, int>{};
    
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(year, month, day);
      final completions = await _achievementService.getTaskCompletionsByDate(date);
      
      // 成功したタスクのみカウント
      final successCount = completions.where((c) => c.wasSuccessful).length;
      dailyCounts[day] = successCount;
    }
    
    return dailyCounts;
  } catch (e) {
    print('❌ 月別日次完了数取得エラー: $e');
    return {};
  }
}

/// 【新規追加】年間統計を取得
Future<Map<String, dynamic>> getAnnualStatistics(int year) async {
  try {
    final yearStart = DateTime(year, 1, 1);
    final yearEnd = DateTime(year, 12, 31, 23, 59, 59);
    
    final allCompletions = await _achievementService.loadTaskCompletions();
    
    // 年間の成功タスクをフィルタ
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
    
    // 総再生時間（時間）
    final totalHours = (totalMinutes / 60).floor();
    
    // ユニークなタスク数
    final uniqueTasks = <String>{};
    for (final c in yearCompletions) {
      uniqueTasks.add(c.taskId);
    }
    
    // ユニークなアルバム数
    final uniqueAlbums = <String>{};
    for (final c in yearCompletions) {
      if (c.albumName != null) {
        uniqueAlbums.add(c.albumName!);
      }
    }
    
    // 月別タスク数
    final monthlyCounts = <int, int>{};
    for (int month = 1; month <= 12; month++) {
      final monthStart = DateTime(year, month, 1);
      final monthEnd = DateTime(year, month + 1, 0, 23, 59, 59);
      
      final monthCount = yearCompletions.where((c) {
        return c.completedAt.isAfter(monthStart.subtract(const Duration(days: 1))) &&
               c.completedAt.isBefore(monthEnd.add(const Duration(days: 1)));
      }).length;
      
      monthlyCounts[month] = monthCount;
    }
    
    // 最も活動した月を特定
    int peakMonth = 1;
    int maxCount = 0;
    monthlyCounts.forEach((month, count) {
      if (count > maxCount) {
        maxCount = count;
        peakMonth = month;
      }
    });
    
    return {
      'totalTasks': totalTasks,
      'totalMinutes': totalMinutes,
      'totalHours': totalHours,
      'uniqueTasks': uniqueTasks.length,
      'uniqueAlbums': uniqueAlbums.length,
      'monthlyCounts': monthlyCounts,
      'peakMonth': peakMonth,
      'peakMonthCount': maxCount,
    };
  } catch (e) {
    print('❌ 年間統計取得エラー: $e');
    return {
      'totalTasks': 0,
      'totalMinutes': 0,
      'totalHours': 0,
      'uniqueTasks': 0,
      'uniqueAlbums': 0,
      'monthlyCounts': <int, int>{},
      'peakMonth': 1,
      'peakMonthCount': 0,
    };
  }
}

/// 【新規追加】連続タスク実行日数を取得
  /// 【新規追加】連続タスク実行日数を取得
  Future<int> getConsecutiveDays() async {
  try {
    final allCompletions = await _achievementService.loadTaskCompletions();
    
    // 成功したタスクのみを日付でグループ化
    final completionDates = <String>{};
    for (final completion in allCompletions) {
      if (completion.wasSuccessful) {
        final dateKey = _formatDateKey(completion.completedAt);
        completionDates.add(dateKey);
      }
    }
    
    if (completionDates.isEmpty) return 0;
    
    // 日付をDateTimeオブジェクトに変換してソート
    final dates = completionDates.map((dateKey) {
      final parts = dateKey.split('-');
      return DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    }).toList()
      ..sort((a, b) => b.compareTo(a)); // 降順
    
    // 今日と昨日の日付（時刻を00:00:00に正規化）
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    
    // 🔧 修正：最新の実行日を確認
    final latestDate = dates.first;
    
    // 🔧 新ロジック：最新実行日が今日か昨日でなければ0
    if (!latestDate.isAtSameMomentAs(today) && 
        !latestDate.isAtSameMomentAs(yesterday)) {
      print('⚠️ 最新実行日: ${_formatDateKey(latestDate)} - 今日でも昨日でもない → 0日');
      return 0;
    }
    
    // 🔧 新ロジック：昨日から遡って連続日数をカウント
    // （今日実行していてもいなくても、昨日までの連続をカウント）
    int consecutiveDays = 0;
    DateTime checkDate = yesterday;
    
    // 昨日から過去に向かって連続日数をカウント
    while (dates.any((date) => date.isAtSameMomentAs(checkDate))) {
      consecutiveDays++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }
    
    // 🔧 新ロジック：今日実行済みなら +1
    if (latestDate.isAtSameMomentAs(today)) {
      consecutiveDays++;
      print('✅ 今日実行済み: 昨日まで${consecutiveDays - 1}日 + 今日1日 = ${consecutiveDays}日');
    } else {
      print('📅 今日未実行: 昨日までの連続${consecutiveDays}日を表示');
    }
    
    return consecutiveDays;
  } catch (e) {
    print('❌ 連続日数取得エラー: $e');
    return 0;
  }
}

}