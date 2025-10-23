// services/habit_breaker_service.dart - 一時停止機能追加版（エラー修正）
import 'dart:math';
import 'dart:async';
import '../services/notification_service.dart';
import '../services/data_service.dart';
import '../models/notification_config.dart';

class HabitBreakerService {
  static final HabitBreakerService _instance = HabitBreakerService._internal();
  factory HabitBreakerService() => _instance;
  HabitBreakerService._internal();

  final NotificationService _notificationService = NotificationService();
  final DataService _dataService = DataService();
  
  // SNS中毒抑制通知のID（ベース）
  static const int _habitBreakerNotificationBaseId = 100;
  
  bool _isActive = false;
  Timer? _schedulingTimer;
  int _nextNotificationId = _habitBreakerNotificationBaseId;

  // 🔧 新機能: 一時停止機能
  bool _isPaused = false;
  DateTime? _pauseStartTime;
  Timer? _resumeTimer;
  NotificationConfig? _cachedConfig;

  // SNS中毒抑制通知を開始（真の定期通知）
  Future<void> startHabitBreaker() async {
    try {
      // 通知設定を読み込み
      final config = await _dataService.loadNotificationConfig();
      _cachedConfig = config;
      
      if (!config.isHabitBreakerEnabled) {
        print('📵 SNS中毒抑制通知は無効です');
        return;
      }

      // 既存の通知をすべて停止
      await stopHabitBreaker();

      // 真の定期通知システムを開始
      await _startPeriodicNotifications(config);

      _isActive = true;
      print('✅ SNS中毒抑制通知を開始しました（${config.habitBreakerInterval}分間隔）');
    } catch (e) {
      print('❌ SNS中毒抑制通知開始エラー: $e');
    }
  }

  // 真の定期通知システム
  Future<void> _startPeriodicNotifications(NotificationConfig config) async {
    // 最初の通知をすぐにスケジュール（一時停止中でなければ）
    if (!_isPaused) {
      await _scheduleNextNotification(config, isFirst: true);
    }
    
    // 定期的に次の通知をスケジュールするタイマー
    _schedulingTimer = Timer.periodic(
      Duration(minutes: config.habitBreakerInterval), 
      (timer) async {
        // 一時停止中はスキップ
        if (_isPaused) {
          print('🔧 SNS中毒抑制通知スキップ: 一時停止中');
          return;
        }

        // 設定が変更されていないかチェック
        final currentConfig = await _dataService.loadNotificationConfig();
        
        if (!currentConfig.isHabitBreakerEnabled) {
          await stopHabitBreaker();
          return;
        }
        
        // 間隔が変更された場合は再起動
        if (currentConfig.habitBreakerInterval != config.habitBreakerInterval) {
          await startHabitBreaker();
          return;
        }
        
        // 次の通知をスケジュール
        await _scheduleNextNotification(currentConfig);
      },
    );
  }

  // 個別の通知をスケジュール（修正版：scheduleDelayedNotificationを使用）
  Future<void> _scheduleNextNotification(NotificationConfig config, {bool isFirst = false}) async {
    // 一時停止中はスケジュールしない
    if (_isPaused) {
      print('🔧 通知スケジュールをスキップ: 一時停止中');
      return;
    }

    try {
      final message = _getRandomMessage(config.habitBreakerMessages);
      final delay = Duration(minutes: config.habitBreakerInterval);
      
      // 🔧 修正: scheduleDelayedNotificationを使用
      await _notificationService.scheduleDelayedNotification(
        id: _nextNotificationId++,
        title: '今すぐタスクをプレイしよう',
        body: message,
        delay: delay,
        payload: 'habit_breaker_${DateTime.now().millisecondsSinceEpoch}',
        withActions: false, // アクションボタンなし
      );
      
      print('📅 次の通知を${config.habitBreakerInterval}分後にスケジュールしました');
      
      // IDが大きくなりすぎた場合はリセット
      if (_nextNotificationId > _habitBreakerNotificationBaseId + 100) {
        _nextNotificationId = _habitBreakerNotificationBaseId;
      }
    } catch (e) {
      print('❌ 通知スケジュールエラー: $e');
    }
  }

  // 🔧 新機能: 通知を一時停止（タスク実行中）
  void pauseNotifications() {
    if (!_isActive || _isPaused) return;
    
    _isPaused = true;
    _pauseStartTime = DateTime.now();
    
    // 予約された通知をキャンセル
    _cancelScheduledNotifications();
    
    print('🔧 SNS中毒抑制通知を一時停止しました（タスク実行中）');
  }

  // 🔧 新機能: 通知を再開（タスク完了後）
  void resumeNotifications() {
    if (!_isActive || !_isPaused) return;
    
    _isPaused = false;
    
    if (_pauseStartTime != null) {
      final pauseDuration = DateTime.now().difference(_pauseStartTime!);
      print('🔧 SNS中毒抑制通知を再開しました（一時停止時間: ${pauseDuration.inMinutes}分）');
      
      // 次の通知を即座にスケジュール（設定がある場合）
      if (_cachedConfig != null && _cachedConfig!.isHabitBreakerEnabled) {
        _scheduleNextNotification(_cachedConfig!);
      }
    } else {
      print('🔧 SNS中毒抑制通知を再開しました');
    }
    
    _pauseStartTime = null;
  }

  // 🔧 新機能: 指定時間後に自動再開（オプション）
  void pauseNotificationsWithAutoResume(Duration pauseDuration) {
    pauseNotifications();
    
    _resumeTimer?.cancel();
    _resumeTimer = Timer(pauseDuration, () {
      resumeNotifications();
    });
    
    print('🔧 SNS中毒抑制通知を一時停止しました（${pauseDuration.inMinutes}分後に自動再開）');
  }

  // 予約された通知をキャンセル（ヘルパーメソッド）
  Future<void> _cancelScheduledNotifications() async {
    try {
      // 現在スケジュールされている可能性のある通知IDをキャンセル
      for (int i = _habitBreakerNotificationBaseId; i < _nextNotificationId; i++) {
        await _notificationService.cancelNotification(i);
      }
      print('✅ 予約された通知をキャンセルしました');
    } catch (e) {
      print('❌ 通知キャンセルエラー: $e');
    }
  }

  // SNS中毒抑制通知を停止
  Future<void> stopHabitBreaker() async {
    try {
      // タイマーを停止
      _schedulingTimer?.cancel();
      _schedulingTimer = null;
      
      // 自動再開タイマーも停止
      _resumeTimer?.cancel();
      _resumeTimer = null;
      
      // 予約されたすべての通知をキャンセル
      await _cancelScheduledNotifications();
      
      _isActive = false;
      _isPaused = false;
      _pauseStartTime = null;
      _cachedConfig = null;
      
      print('✅ SNS中毒抑制通知をすべて停止しました');
    } catch (e) {
      print('❌ SNS中毒抑制通知停止エラー: $e');
    }
  }

  // 通知設定の更新（設定変更時に呼び出す）
  Future<void> updateSettings(NotificationConfig config) async {
    try {
      // 設定を保存
      await _dataService.saveNotificationConfig(config);
      _cachedConfig = config;
      
      // 通知システムを再起動
      if (config.isHabitBreakerEnabled) {
        await startHabitBreaker();
      } else {
        await stopHabitBreaker();
      }
      
      print('✅ SNS中毒抑制通知設定を更新しました');
    } catch (e) {
      print('❌ SNS中毒抑制通知設定更新エラー: $e');
    }
  }

  // 即座にテスト通知を送信
  Future<void> sendTestNotification() async {
    try {
      final config = await _dataService.loadNotificationConfig();
      final message = _getRandomMessage(config.habitBreakerMessages);
      
      await _notificationService.showNotification(
        id: _habitBreakerNotificationBaseId + 999, // テスト用ID
        title: '今すぐタスクをプレイしよう（テスト）',
        body: message,
        payload: 'habit_breaker_test',
      );
      
      print('✅ SNS中毒抑制テスト通知を送信しました');
    } catch (e) {
      print('❌ SNS中毒抑制テスト通知エラー: $e');
    }
  }

  // アプリ起動時の初期化（設定に基づいて自動開始）
  Future<void> initialize() async {
    try {
      final config = await _dataService.loadNotificationConfig();
      _cachedConfig = config;
      
      if (config.isHabitBreakerEnabled) {
        await startHabitBreaker();
      }
      
      print('🔄 HabitBreakerService初期化完了');
    } catch (e) {
      print('❌ HabitBreakerService初期化エラー: $e');
    }
  }

  // アプリ終了時のクリーンアップ
  Future<void> dispose() async {
    _schedulingTimer?.cancel();
    _resumeTimer?.cancel();
    print('🔄 HabitBreakerService終了');
  }

  // 現在の状態を取得
  bool get isActive => _isActive;
  bool get isPaused => _isPaused;

  // 現在の設定を取得
  Future<NotificationConfig> getCurrentConfig() async {
    return await _dataService.loadNotificationConfig();
  }

  // ランダムなメッセージを選択
  String _getRandomMessage(List<String> messages) {
    if (messages.isEmpty) {
      return '理想の自分に近づくための行動を意識しましょう';
    }
    
    final random = Random();
    return messages[random.nextInt(messages.length)];
  }

  // 次の通知予定時刻を計算（デバッグ用）
  Future<DateTime?> getNextNotificationTime() async {
    try {
      final config = await _dataService.loadNotificationConfig();
      if (!config.isHabitBreakerEnabled || !_isActive || _isPaused) {
        return null;
      }
      
      return DateTime.now().add(Duration(minutes: config.habitBreakerInterval));
    } catch (e) {
      print('❌ 次回通知時刻取得エラー: $e');
      return null;
    }
  }

  // 統計情報を取得
  Future<Map<String, dynamic>> getStatistics() async {
    try {
      final config = await _dataService.loadNotificationConfig();
      
      return {
        'isEnabled': config.isHabitBreakerEnabled,
        'interval': config.habitBreakerInterval,
        'isActive': _isActive,
        'isPaused': _isPaused,
        'pauseStartTime': _pauseStartTime?.toIso8601String(),
        'messageCount': config.habitBreakerMessages.length,
        'nextNotification': await getNextNotificationTime(),
        'hasSchedulingTimer': _schedulingTimer != null,
        'hasResumeTimer': _resumeTimer != null,
        'nextNotificationId': _nextNotificationId,
      };
    } catch (e) {
      print('❌ 統計情報取得エラー: $e');
      return {};
    }
  }
}