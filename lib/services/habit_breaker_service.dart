// services/habit_breaker_service.dart - 睡眠時間中の完全停止対応版
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

  // 🆕 睡眠モード管理用
  bool _isInSleepMode = false;
  Timer? _sleepModeCheckTimer;
  
  // SNS中毒抑制通知のID（ベース）
  static const int _habitBreakerNotificationBaseId = 100;
  
  bool _isActive = false;
  Timer? _schedulingTimer;
  int _nextNotificationId = _habitBreakerNotificationBaseId;

  // 一時停止機能
  bool _isPaused = false;
  DateTime? _pauseStartTime;
  Timer? _resumeTimer;
  NotificationConfig? _cachedConfig;

  // 特別通知用のタイマー
  Timer? _bedtimeNotificationTimer;
  Timer? _wakeUpNotificationTimer;

  // 特別通知のID
  static const int _bedtimeNotificationId = 9000;
  static const int _wakeUpNotificationId = 9001;

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

      // 全曜日無効チェック
      if (config.allDaysDisabled) {
        print('📵 全ての曜日が無効です');
        await stopHabitBreaker();
        return;
      }

      // 既存の通知をすべて停止
      await stopHabitBreaker();

      // 真の定期通知システムを開始
      await _startPeriodicNotifications(config);

      // 睡眠スケジュール通知を開始
      if (config.sleepScheduleEnabled) {
        await _startSleepScheduleNotifications(config);
      }

      _isActive = true;
      print('✅ SNS中毒抑制通知を開始しました（${config.habitBreakerInterval}分間隔）');
    } catch (e) {
      print('❌ SNS中毒抑制通知開始エラー: $e');
    }
  }

  Future<void> _startPeriodicNotifications(NotificationConfig config) async {
    // 睡眠中なら開始しない
    if (_isInSleepMode) {
      print('🌙 睡眠モード中のため定期通知を開始しません');
      return;
    }
    
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

        // 睡眠モード中はスキップ
        if (_isInSleepMode) {
          print('🔧 SNS中毒抑制通知スキップ: 睡眠モード中');
          return;
        }

        // 曜日チェック
        final now = DateTime.now();
        final weekday = now.weekday == 7 ? 7 : now.weekday;
        final convertedWeekday = weekday == 7 ? 1 : weekday + 1;
        if (!config.isDayEnabled(convertedWeekday)) {
          print('🔧 SNS中毒抑制通知スキップ: 無効な曜日');
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

  // 個別の通知をスケジュール
  Future<void> _scheduleNextNotification(NotificationConfig config, {bool isFirst = false}) async {
    // 一時停止中はスケジュールしない
    if (_isPaused) {
      print('🔧 通知スケジュールをスキップ: 一時停止中');
      return;
    }

    // 睡眠モード中はスケジュールしない
    if (_isInSleepMode) {
      print('🔧 通知スケジュールをスキップ: 睡眠モード中');
      return;
    }

    // 曜日チェック
    final now = DateTime.now();
    final weekday = now.weekday == 7 ? 7 : now.weekday;
    final convertedWeekday = weekday == 7 ? 1 : weekday + 1;
    if (!config.isDayEnabled(convertedWeekday)) {
      print('🔧 通知スケジュールをスキップ: 無効な曜日');
      return;
    }

    try {
      final message = _getRandomMessage(config.habitBreakerMessages);
      final delay = Duration(minutes: config.habitBreakerInterval);
      
      await _notificationService.scheduleDelayedNotification(
        id: _nextNotificationId++,
        title: 'Start Your Task Now',
        body: message,
        delay: delay,
        payload: 'habit_breaker_${DateTime.now().millisecondsSinceEpoch}',
        withActions: false,
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

  /// 睡眠スケジュール通知を開始
  Future<void> _startSleepScheduleNotifications(NotificationConfig config) async {
    try {
      // 既存の睡眠通知をキャンセル
      await _cancelSleepScheduleNotifications();
      
      // 就寝通知をスケジュール
      await _scheduleBedtimeNotification(config);
      
      // 起床通知をスケジュール
      await _scheduleWakeUpNotification(config);
      
      // 睡眠モード監視タイマーを開始
      _startSleepModeMonitoring(config);
      
      print('✅ 睡眠スケジュール通知を開始しました');
    } catch (e) {
      print('❌ 睡眠スケジュール通知開始エラー: $e');
    }
  }

  /// 睡眠モード監視タイマー（1分ごとにチェック）
  void _startSleepModeMonitoring(NotificationConfig config) {
    _sleepModeCheckTimer?.cancel();
    
    _sleepModeCheckTimer = Timer.periodic(
      const Duration(minutes: 1),
      (timer) {
        final now = DateTime.now();
        final isCurrentlySleepTime = config.isSleepTime(now);
        
        // 睡眠時間に入った場合
        if (isCurrentlySleepTime && !_isInSleepMode) {
          print('🌙 睡眠時間開始 - 定期通知を停止します');
          _enterSleepMode();
        }
        // 起床時間に達した場合
        else if (!isCurrentlySleepTime && _isInSleepMode) {
          print('☀️ 起床時間 - 定期通知を再開します');
          _exitSleepMode();
        }
      },
    );
  }

  /// 睡眠モードに入る（定期通知を完全停止）
  void _enterSleepMode() {
    if (_isInSleepMode) return;
    
    _isInSleepMode = true;
    
    // 定期通知タイマーを停止
    _schedulingTimer?.cancel();
    _schedulingTimer = null;
    
    // 既にスケジュールされた通知をキャンセル
    _cancelScheduledNotifications();
    
    print('🛑 睡眠モード: 定期通知システムを完全停止しました');
  }

  /// 睡眠モードから出る（定期通知を再開）
  void _exitSleepMode() async {
    if (!_isInSleepMode) return;
    
    _isInSleepMode = false;
    
    // 定期通知を再開
    if (_cachedConfig != null && _cachedConfig!.isHabitBreakerEnabled) {
      await _startPeriodicNotifications(_cachedConfig!);
      print('🟢 睡眠モード終了: 定期通知システムを再開しました');
    }
  }

  /// 就寝通知をスケジュール（5分前）
  Future<void> _scheduleBedtimeNotification(NotificationConfig config) async {
    try {
      final now = DateTime.now();
      
      // 就寝時刻の5分前を計算
      var bedtimeHour = config.bedtime24Hour;
      var bedtimeMinute = config.bedtimeMinute - 5;
      
      if (bedtimeMinute < 0) {
        bedtimeMinute += 60;
        bedtimeHour -= 1;
        if (bedtimeHour < 0) bedtimeHour += 24;
      }
      
      // 次の就寝通知時刻を計算
      var notificationTime = DateTime(
        now.year,
        now.month,
        now.day,
        bedtimeHour,
        bedtimeMinute,
      );
      
      // 過去の時刻なら翌日に設定
      if (notificationTime.isBefore(now)) {
        notificationTime = notificationTime.add(const Duration(days: 1));
      }
      
      final delay = notificationTime.difference(now);
      
      // 通知をスケジュール
      await _notificationService.scheduleDelayedNotification(
        id: _bedtimeNotificationId,
        title: 'Bedtime Reminder',
        body: config.bedtimeMessage,
        delay: delay,
        payload: 'bedtime_notification',
        withActions: false,
      );
      
      print('📅 就寝通知を${delay.inMinutes}分後（${notificationTime.hour}:${notificationTime.minute.toString().padLeft(2, '0')}）にスケジュールしました');
      
      // 就寝通知送信後に睡眠モードに入るタイマー
      _bedtimeNotificationTimer = Timer(delay, () async {
        print('🌙 就寝通知を送信 - 睡眠モードに移行します');
        _enterSleepMode();
        
        // 24時間後に再スケジュール
        final currentConfig = await _dataService.loadNotificationConfig();
        if (currentConfig.sleepScheduleEnabled) {
          await _scheduleBedtimeNotification(currentConfig);
        }
      });
    } catch (e) {
      print('❌ 就寝通知スケジュールエラー: $e');
    }
  }

  /// 起床通知をスケジュール
  Future<void> _scheduleWakeUpNotification(NotificationConfig config) async {
    try {
      final now = DateTime.now();
      
      // 次の起床通知時刻を計算
      var notificationTime = DateTime(
        now.year,
        now.month,
        now.day,
        config.wakeUp24Hour,
        config.wakeUpMinute,
      );
      
      // 過去の時刻なら翌日に設定
      if (notificationTime.isBefore(now)) {
        notificationTime = notificationTime.add(const Duration(days: 1));
      }
      
      final delay = notificationTime.difference(now);
      
      // 通知をスケジュール
      await _notificationService.scheduleDelayedNotification(
        id: _wakeUpNotificationId,
        title: 'Good Morning!',
        body: config.wakeUpMessage,
        delay: delay,
        payload: 'wakeup_notification',
        withActions: false,
      );
      
      print('📅 起床通知を${delay.inMinutes}分後（${notificationTime.hour}:${notificationTime.minute.toString().padLeft(2, '0')}）にスケジュールしました');
      
      // 起床通知送信後に睡眠モードを終了するタイマー
      _wakeUpNotificationTimer = Timer(delay, () async {
        print('☀️ 起床通知を送信 - 睡眠モードを終了します');
        _exitSleepMode();
        
        // 24時間後に再スケジュール
        final currentConfig = await _dataService.loadNotificationConfig();
        if (currentConfig.sleepScheduleEnabled) {
          await _scheduleWakeUpNotification(currentConfig);
        }
      });
    } catch (e) {
      print('❌ 起床通知スケジュールエラー: $e');
    }
  }

  /// 睡眠スケジュール通知をキャンセル
  Future<void> _cancelSleepScheduleNotifications() async {
    try {
      // タイマーをキャンセル
      _bedtimeNotificationTimer?.cancel();
      _bedtimeNotificationTimer = null;
      
      _wakeUpNotificationTimer?.cancel();
      _wakeUpNotificationTimer = null;
      
      // 通知をキャンセル
      await _notificationService.cancelNotification(_bedtimeNotificationId);
      await _notificationService.cancelNotification(_wakeUpNotificationId);
      
      print('✅ 睡眠スケジュール通知をキャンセルしました');
    } catch (e) {
      print('❌ 睡眠スケジュール通知キャンセルエラー: $e');
    }
  }

  // 通知を一時停止（タスク実行中）
  void pauseNotifications() {
    if (!_isActive || _isPaused) return;
    
    _isPaused = true;
    _pauseStartTime = DateTime.now();
    
    // 予約された通知をキャンセル
    _cancelScheduledNotifications();
    
    print('🔧 SNS中毒抑制通知を一時停止しました（タスク実行中）');
  }

  // 通知を再開（タスク完了後）
  void resumeNotifications() {
    if (!_isActive || !_isPaused) return;
    
    _isPaused = false;
    
    if (_pauseStartTime != null) {
      final pauseDuration = DateTime.now().difference(_pauseStartTime!);
      print('🔧 SNS中毒抑制通知を再開しました（一時停止時間: ${pauseDuration.inMinutes}分）');
      _pauseStartTime = null;
    } else {
      print('🔧 SNS中毒抑制通知を再開しました');
    }
    
    // 次の通知を即座にスケジュール
    if (_cachedConfig != null && _cachedConfig!.isHabitBreakerEnabled) {
      _scheduleNextNotification(_cachedConfig!, isFirst: false);
      
      // 定期タイマーが停止している場合は再起動
      if (_schedulingTimer == null || !_schedulingTimer!.isActive) {
        print('🔧 定期タイマーを再起動します');
        _startPeriodicNotifications(_cachedConfig!);
      }
    }
  }

  // 指定時間後に自動再開（オプション）
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

  Future<void> stopHabitBreaker() async {
    try {
      // タイマーを停止
      _schedulingTimer?.cancel();
      _schedulingTimer = null;
      
      // 自動再開タイマーも停止
      _resumeTimer?.cancel();
      _resumeTimer = null;
      
      // 睡眠モード監視タイマーも停止
      _sleepModeCheckTimer?.cancel();
      _sleepModeCheckTimer = null;
      
      // 睡眠スケジュール通知もキャンセル
      await _cancelSleepScheduleNotifications();
      
      // 予約されたすべての通知をキャンセル
      await _cancelScheduledNotifications();
      
      _isActive = false;
      _isPaused = false;
      _isInSleepMode = false;
      _pauseStartTime = null;
      _cachedConfig = null;
      
      print('✅ SNS中毒抑制通知をすべて停止しました');
    } catch (e) {
      print('❌ SNS中毒抑制通知停止エラー: $e');
    }
  }

  Future<void> updateSettings(NotificationConfig config) async {
    try {
      // バリデーションチェック
      if (config.sleepScheduleEnabled && config.isSameTime) {
        print('❌ 就寝時刻と起床時刻が同じです');
        throw Exception('Bedtime and wake-up time cannot be the same');
      }
      
      // 全曜日無効チェック
      if (config.allDaysDisabled) {
        print('⚠️ 全ての曜日が無効です - 通知を停止します');
        await stopHabitBreaker();
        await _dataService.saveNotificationConfig(config);
        _cachedConfig = config;
        return;
      }
      
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
      rethrow;
    }
  }

  // 即座にテスト通知を送信
  Future<void> sendTestNotification() async {
    try {
      final config = await _dataService.loadNotificationConfig();
      final message = _getRandomMessage(config.habitBreakerMessages);
      
      await _notificationService.showNotification(
        id: _habitBreakerNotificationBaseId + 999,
        title: 'Start Your Task Now (Test)',
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
      print('🔄 HabitBreakerService初期化開始...');
      
      final config = await _dataService.loadNotificationConfig();
      _cachedConfig = config;
      
      print('📋 通知設定読み込み完了:');
      print('  - 定期通知: ${config.isHabitBreakerEnabled ? "ON" : "OFF"}');
      print('  - 間隔: ${config.habitBreakerInterval}分');
      print('  - 睡眠スケジュール: ${config.sleepScheduleEnabled ? "ON" : "OFF"}');
      print('  - 有効曜日: ${config.enabledDays.length}日');
      
      // 設定がONなら自動起動
      if (config.isHabitBreakerEnabled) {
        await startHabitBreaker();
        print('✅ HabitBreakerService初期化完了 - 通知システム起動済み');
      } else {
        print('ℹ️ HabitBreakerService初期化完了 - 通知はOFF状態');
      }
    } catch (e) {
      print('❌ HabitBreakerService初期化エラー: $e');
    }
  }

  Future<void> dispose() async {
    _schedulingTimer?.cancel();
    _resumeTimer?.cancel();
    _bedtimeNotificationTimer?.cancel();
    _wakeUpNotificationTimer?.cancel();
    _sleepModeCheckTimer?.cancel();
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
        'isInSleepMode': _isInSleepMode,
        'pauseStartTime': _pauseStartTime?.toIso8601String(),
        'messageCount': config.habitBreakerMessages.length,
        'nextNotification': await getNextNotificationTime(),
        'hasSchedulingTimer': _schedulingTimer != null,
        'hasResumeTimer': _resumeTimer != null,
        'hasSleepModeCheckTimer': _sleepModeCheckTimer != null,
        'nextNotificationId': _nextNotificationId,
        'sleepScheduleEnabled': config.sleepScheduleEnabled,
        'isSleepTime': config.isSleepTime(DateTime.now()),
        'enabledDaysCount': config.enabledDays.length,
        'hasBedtimeTimer': _bedtimeNotificationTimer != null,
        'hasWakeUpTimer': _wakeUpNotificationTimer != null,
      };
    } catch (e) {
      print('❌ 統計情報取得エラー: $e');
      return {};
    }
  }
}