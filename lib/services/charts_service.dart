// services/charts_service.dart - 新構造対応版（完全版）
import '../models/concert_data.dart';
import 'task_completion_service.dart';
import 'package:shared_preferences/shared_preferences.dart';  // 新規追加
import 'dart:convert';  // 新規追加

class ChartsService {
  final TaskCompletionService _taskCompletionService = TaskCompletionService();
  
  /// コンサートデータを取得（新構造対応）
  Future<ConcertData> getConcertData() async {
    try {
      print('コンサートデータ取得開始');
      
      // 初回起動時のシステム初期化
      await _taskCompletionService.initializeAudienceSystem();
      
      // 観客数とタスク数を分離して取得
      final currentAudience = await _taskCompletionService.getCurrentAudienceCount();
      final totalCompletedTasks = await _taskCompletionService.getTotalCompletedTasks();
      final achievementRate = await _taskCompletionService.getTotalAchievementRate();
      final dailyCompletions = await _taskCompletionService.getDailyCompletions(days: 7);
      
      final concertData = ConcertData(
        totalCompletedTasks: totalCompletedTasks,
        audienceCount: currentAudience, // 管理された観客数を使用
        achievementRate: achievementRate,
        lastUpdated: DateTime.now(),
        dailyCompletions: dailyCompletions,
      );
      
      print('コンサートデータ取得完了: 観客数=$currentAudience人, 累計タスク=$totalCompletedTasks個');
      return concertData;
      
    } catch (e) {
      print('コンサートデータ取得エラー: $e');
      return ConcertData.empty();
    }
  }
  
  /// 新規完了タスク数を取得
  Future<int> getNewCompletedTasksSince(int lastKnownCount) async {
    try {
      return await _taskCompletionService.getNewCompletedTasksSince(lastKnownCount);
    } catch (e) {
      print('新規完了タスク数取得エラー: $e');
      return 0;
    }
  }
  
  /// 観客を入場させる
  Future<void> addAudienceMembers(int count) async {
    try {
      await _taskCompletionService.addAudienceMembers(count);
      print('$count人の観客が入場しました');
    } catch (e) {
      print('観客入場エラー: $e');
    }
  }
  
  /// 観客数のみを取得（軽量版）
  Future<int> getAudienceCount() async {
    try {
      return await _taskCompletionService.getCurrentAudienceCount();
    } catch (e) {
      print('観客数取得エラー: $e');
      return 0;
    }
  }
  
  /// 累計タスク数のみを取得
  Future<int> getTotalCompletedTasks() async {
    try {
      return await _taskCompletionService.getTotalCompletedTasks();
    } catch (e) {
      print('累計タスク数取得エラー: $e');
      return 0;
    }
  }

  /// 観客の位置データを保存
Future<void> saveAudiencePositions(List<Map<String, dynamic>> positions) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(positions);
    await prefs.setString('audience_positions', jsonString);
    print('✅ 観客位置を保存: ${positions.length}人');
  } catch (e) {
    print('❌ 観客位置保存エラー: $e');
  }
}

/// 観客の位置データを読み込み
Future<List<Map<String, dynamic>>> loadAudiencePositions() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('audience_positions');
    
    if (jsonString != null) {
      final List<dynamic> decoded = jsonDecode(jsonString);
      return decoded.cast<Map<String, dynamic>>();
    }
    
    return [];
  } catch (e) {
    print('❌ 観客位置読み込みエラー: $e');
    return [];
  }
}
  
  /// 累計タスク実行数を取得（成功・失敗含む）
  Future<int> getTotalAttemptedTasks() async {
    try {
      return await _taskCompletionService.getTotalAttemptedTasks();
    } catch (e) {
      print('累計実行タスク数取得エラー: $e');
      return 0;
    }
  }
  
  /// 達成率のみを取得
  Future<double> getAchievementRate() async {
    try {
      return await _taskCompletionService.getTotalAchievementRate();
    } catch (e) {
      print('達成率取得エラー: $e');
      return 0.0;
    }
  }
  
  /// 日別完了数を取得
  Future<Map<String, int>> getDailyCompletions({int days = 7}) async {
    try {
      return await _taskCompletionService.getDailyCompletions(days: days);
    } catch (e) {
      print('日別完了数取得エラー: $e');
      return {};
    }
  }
}