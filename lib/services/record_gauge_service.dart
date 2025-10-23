// services/record_gauge_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/record_gauge_state.dart';  // ← ここを相対パスに修正
import '../services/task_completion_service.dart';  // ← ここを相対パスに修正

/// Record Gauge（レコード・ゲージ）のデータ管理サービス
/// 
/// ドリームアルバムの4タスク完了状態をレコード盤として管理
class RecordGaugeService {
  static final RecordGaugeService _instance = RecordGaugeService._internal();
  factory RecordGaugeService() => _instance;
  RecordGaugeService._internal();

  final TaskCompletionService _taskCompletionService = TaskCompletionService();
  
  // SharedPreferencesキー
  static const String _keyRecordGaugeState = 'record_gauge_state';
  static const String _keyCompletionMessageShown = 'record_gauge_completion_shown';

  /// 今日のレコード盤の状態を取得
  Future<RecordGaugeState> getTodayRecordState() async {
    try {
      // 今日完了したタスクのインデックスを取得
      final completedIndices = await _taskCompletionService.getTodayCompletedTaskIndices();
      
      // 状態を作成
      final state = RecordGaugeState.fromCompletedIndices(
        completedIndices: completedIndices,
        date: DateTime.now(),
      );
      
      // 状態を保存
      await _saveState(state);
      
      print('✅ 今日のレコード状態取得: ${state.completedCount}/4 完了');
      return state;
    } catch (e) {
      print('❌ レコード状態取得エラー: $e');
      return RecordGaugeState.initial();
    }
  }

  /// 保存されたレコード盤の状態を読み込み
  Future<RecordGaugeState?> loadSavedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_keyRecordGaugeState);
      
      if (jsonString != null) {
        final state = RecordGaugeState.fromJson(jsonDecode(jsonString));
        
        // 今日の日付でなければnullを返す（古いデータ）
        if (!state.isToday()) {
          print('⚠️ 保存されたレコード状態は古いデータです');
          return null;
        }
        
        return state;
      }
      
      return null;
    } catch (e) {
      print('❌ レコード状態読み込みエラー: $e');
      return null;
    }
  }

  /// レコード盤の状態を保存
  Future<void> _saveState(RecordGaugeState state) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(state.toJson());
      await prefs.setString(_keyRecordGaugeState, jsonString);
      print('✅ レコード状態を保存しました');
    } catch (e) {
      print('❌ レコード状態保存エラー: $e');
    }
  }

  /// 4タスク全完了の達成メッセージを表示すべきかを判定
  /// 
  /// 条件:
  /// - 今日4タスクすべて完了している
  /// - 今日まだメッセージを表示していない
  Future<bool> shouldShowCompletionMessage() async {
    try {
      // 今日の状態を取得
      final state = await getTodayRecordState();
      
      // 全完了していなければfalse
      if (!state.isFullyCompleted) {
        return false;
      }
      
      // 今日既にメッセージを表示済みか確認
      final alreadyShown = await _isCompletionMessageShownToday();
      
      return !alreadyShown;
    } catch (e) {
      print('❌ 達成メッセージ表示判定エラー: $e');
      return false;
    }
  }

  /// 達成メッセージ表示済みフラグをマーク
  Future<void> markCompletionMessageShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      final dateKey = _formatDateKey(today);
      
      // 今日の日付キーで保存
      await prefs.setString(_keyCompletionMessageShown, dateKey);
      print('✅ 達成メッセージ表示済みフラグを設定: $dateKey');
    } catch (e) {
      print('❌ 達成メッセージフラグ設定エラー: $e');
    }
  }

  /// 今日既に達成メッセージを表示済みかを確認
  Future<bool> _isCompletionMessageShownToday() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedDateKey = prefs.getString(_keyCompletionMessageShown);
      
      if (savedDateKey == null) {
        return false;
      }
      
      final today = DateTime.now();
      final todayKey = _formatDateKey(today);
      
      return savedDateKey == todayKey;
    } catch (e) {
      print('❌ 達成メッセージ表示済み確認エラー: $e');
      return false;
    }
  }

  /// 日付をキー形式にフォーマット（YYYY-MM-DD）
  String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// レコード盤のデータをリセット（テスト・デバッグ用）
  Future<void> resetRecordGaugeData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyRecordGaugeState);
      await prefs.remove(_keyCompletionMessageShown);
      print('✅ レコード盤データをリセットしました');
    } catch (e) {
      print('❌ レコード盤データリセットエラー: $e');
    }
  }

  /// 今日の進捗パーセンテージを取得（0〜100）
  Future<int> getTodayProgressPercentage() async {
    try {
      final state = await getTodayRecordState();
      return ((state.completedCount / 4) * 100).round();
    } catch (e) {
      print('❌ 進捗パーセンテージ取得エラー: $e');
      return 0;
    }
  }
}