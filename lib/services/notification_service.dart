// services/notification_service.dart - 自動再生通知拡張版（エラー修正）
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'dart:io';
import 'dart:math';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  // 🔔 通知応答のコールバック
  Function(NotificationResponse)? _onNotificationResponse;

  // 🆕 自動再生用の通知ID範囲
  static const int taskTransitionBaseId = 5000;
  static const int albumCompletionBaseId = 6000;
  static const int progressUpdateBaseId = 7000;
  static const int motivationalBaseId = 8000;

  // 🆕 睡眠スケジュール通知のID
static const int bedtimeNotificationId = 9000;
static const int wakeUpNotificationId = 9001;

  // 初期化
Future<bool> initialize() async {
  if (_isInitialized) return true;

  try {
    // タイムゾーンデータベースを初期化
    tz.initializeTimeZones();
    
    // Android設定
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS設定 - フォアグラウンド通知を有効化
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
      requestCriticalPermission: false,
      defaultPresentAlert: true,
      defaultPresentSound: true,
      defaultPresentBadge: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // 事前に設定されたコールバックがあれば使用、なければデフォルト
    final callback = _onNotificationResponse != null 
        ? (NotificationResponse response) {
            print('🔔 通知タップ検出: ${response.payload}');
            _onNotificationTapped(response);
          }
        : _onNotificationTapped;

    final bool? result = await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: callback,
    );

    _isInitialized = result ?? false;
    
    if (_isInitialized) {
      await _requestPermissions();
      print('✅ NotificationService初期化完了: $_isInitialized');
    }
    
    return _isInitialized;
  } catch (e) {
    print('❌ NotificationService初期化エラー: $e');
    return false;
  }
}


  // 権限要求（iOS/Android両対応）
  Future<void> _requestPermissions() async {
    try {
      if (Platform.isIOS) {
        final bool? result = await _notifications
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
              critical: false,
            );
        print('✅ iOS通知権限要求結果: $result');
      } else if (Platform.isAndroid) {
        final status = await Permission.notification.request();
        print('✅ Android通知権限要求結果: $status');
      }
    } catch (e) {
      print('❌ 通知権限要求エラー: $e');
    }
  }

  // 通知タップ時の処理
  void _onNotificationTapped(NotificationResponse response) {
    print('🔔 通知がタップされました: ${response.payload}');
    print('🔔 アクション種別: ${response.actionId}');
    
    // 外部コールバックがあれば実行
    _onNotificationResponse?.call(response);
  }

  // 通知応答コールバックを設定
void setNotificationResponseCallback(Function(NotificationResponse) callback) {
  _onNotificationResponse = callback;
  
  // 既に初期化済みの場合は再初期化してコールバックを有効化
  if (_isInitialized) {
    print('🔧 通知応答コールバック設定のため再初期化中...');
    _reinitializeWithCallback();
  }
}

// コールバック設定のための再初期化
Future<void> _reinitializeWithCallback() async {
  try {
    // Android設定
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS設定 - フォアグラウンド通知を有効化
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
      requestCriticalPermission: false,
      defaultPresentAlert: true,
      defaultPresentSound: true,
      defaultPresentBadge: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // 新しいコールバックで再初期化
    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    
    print('✅ 通知応答コールバック設定完了');
  } catch (e) {
    print('❌ 通知応答コールバック設定エラー: $e');
  }
}

  // 権限チェックと取得
  Future<bool> checkAndRequestPermissions() async {
    if (Platform.isAndroid) {
      if (await Permission.notification.isDenied) {
        final status = await Permission.notification.request();
        return status.isGranted;
      }
      return true;
    } else if (Platform.isIOS) {
      final bool? result = await _notifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      return result ?? false;
    }
    return true;
  }

  // 🆕 タスク切り替え通知（自動再生用）
  Future<void> showTaskTransitionNotification({
    required String completedTaskTitle,
    required String nextTaskTitle,
    required String albumName,
    required int currentTaskNumber,
    required int totalTasks,
    String? payload,
  }) async {
    if (!_isInitialized) {
      print('❌ NotificationServiceが初期化されていません');
      return;
    }

    try {
      final notificationId = taskTransitionBaseId + currentTaskNumber;
      final title = '🔄 次のタスクを開始';
      final body = '「$completedTaskTitle」完了！\n▶️ 「$nextTaskTitle」を再生中... ($currentTaskNumber/$totalTasks)';
      
      // 🔧 修正: constを削除し、通常のインスタンスとして作成
      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'auto_play_transition_channel',
        '自動再生切り替え通知',
        channelDescription: '自動再生時のタスク切り替え通知',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        ongoing: false,
        autoCancel: true,
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        styleInformation: BigTextStyleInformation(
          body,
          htmlFormatBigText: false,
          htmlFormatContentTitle: false,
        ),
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.active,
      );

      // 🔧 修正: constを削除
      final NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
      
      print('✅ タスク切り替え通知表示成功: $completedTaskTitle → $nextTaskTitle');
    } catch (e) {
      print('❌ タスク切り替え通知表示エラー: $e');
    }
  }

  // 🆕 アルバム完了通知（自動再生用）
  Future<void> showAlbumCompletionNotification({
    required String albumName,
    required int totalTasks,
    required int totalDurationMinutes,
    String? payload,
  }) async {
    if (!_isInitialized) {
      print('❌ NotificationServiceが初期化されていません');
      return;
    }

    try {
      final notificationId = albumCompletionBaseId;
      final title = '🎉 アルバム完了！';
      final body = '「$albumName」のすべてのタスク($totalTasks個)が完了しました！\n⏱️ 総時間: ${totalDurationMinutes}分\n\nタスクを実行できましたか？';
      
      // 🔧 修正: constを削除し、アクションを動的に作成
      final androidActions = <AndroidNotificationAction>[
        AndroidNotificationAction(
          'album_completion_all_success',
          '✅ 全て達成しました',
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'album_completion_partial_success',
          '🔶 一部達成しました',
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'album_completion_retry',
          '🔄 再度チャレンジ',
          showsUserInterface: true,
        ),
      ];
      
      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'auto_play_completion_channel',
        '自動再生完了通知',
        channelDescription: 'アルバム自動再生完了時の通知',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        ongoing: false,
        autoCancel: false,
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        styleInformation: BigTextStyleInformation(
          body,
          htmlFormatBigText: false,
          htmlFormatContentTitle: false,
        ),
        actions: androidActions,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      );

      final NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
      
      print('✅ アルバム完了通知表示成功: $albumName');
    } catch (e) {
      print('❌ アルバム完了通知表示エラー: $e');
    }
  }



// notification_service.dart の NotificationService クラス内に追加
Future<NotificationAppLaunchDetails?> getNotificationAppLaunchDetails() async {
  try {
    return await _notifications.getNotificationAppLaunchDetails();
  } catch (e) {
    print('❌ 通知起動詳細取得エラー: $e');
    return null;
  }
}

  // 🆕 進捗更新通知（自動再生中の励まし通知）
  Future<void> showProgressUpdateNotification({
    required String currentTaskTitle,
    required int currentTaskNumber,
    required int totalTasks,
    required String albumName,
    required int elapsedMinutes,
    String? payload,
  }) async {
    if (!_isInitialized) {
      print('❌ NotificationServiceが初期化されていません');
      return;
    }

    try {
      final notificationId = progressUpdateBaseId + currentTaskNumber;
      final progressPercentage = ((currentTaskNumber / totalTasks) * 100).round();
      final title = '📈 進捗更新 ($progressPercentage%)';
      final body = '「$currentTaskTitle」実行中...\n🎯 $currentTaskNumber/$totalTasks タスク完了\n⏱️ 経過時間: ${elapsedMinutes}分';
      
      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'auto_play_progress_channel',
        '自動再生進捗通知',
        channelDescription: '自動再生中の進捗更新通知',
        importance: Importance.low,
        priority: Priority.low,
        showWhen: true,
        enableVibration: false,
        playSound: false,
        ongoing: true,
        autoCancel: true,
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        styleInformation: BigTextStyleInformation(
          body,
          htmlFormatBigText: false,
          htmlFormatContentTitle: false,
        ),
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: false,
        interruptionLevel: InterruptionLevel.passive,
      );

      final NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
      
      print('✅ 進捗更新通知表示成功: $currentTaskTitle ($progressPercentage%)');
    } catch (e) {
      print('❌ 進捗更新通知表示エラー: $e');
    }
  }

  // 🆕 励まし通知（自動再生中のモチベーション向上）
  Future<void> showMotivationalNotification({
    required String message,
    required String albumName,
    required int currentTaskNumber,
    required int totalTasks,
    String? payload,
  }) async {
    if (!_isInitialized) {
      print('❌ NotificationServiceが初期化されていません');
      return;
    }

    try {
      final notificationId = motivationalBaseId + DateTime.now().millisecond % 1000;
      final title = '💪 がんばっていますね！';
      final body = '$message\n\n🎯 $currentTaskNumber/$totalTasks タスク完了\n「$albumName」もうすぐゴールです！';
      
      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'auto_play_motivation_channel',
        '自動再生励まし通知',
        channelDescription: '自動再生中の励まし・モチベーション通知',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        ongoing: false,
        autoCancel: true,
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        styleInformation: BigTextStyleInformation(
          body,
          htmlFormatBigText: false,
          htmlFormatContentTitle: false,
        ),
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.active,
      );

      final NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
      
      print('✅ 励まし通知表示成功: $message');
    } catch (e) {
      print('❌ 励まし通知表示エラー: $e');
    }
  }

  // 基本通知を表示
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) {
      print('❌ NotificationServiceが初期化されていません');
      return;
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'habit_breaker_channel',
      '習慣改善通知',
      channelDescription: 'SNS中毒抑制のための通知',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notifications.show(
        id,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
      print('✅ 通知表示成功: $title');
    } catch (e) {
      print('❌ 通知表示エラー: $e');
    }
  }

  // アクションボタン付き通知を表示
  Future<void> showNotificationWithActions({
    required int id,
    required String title,
    required String body,
    String? payload,
    List<AndroidNotificationAction>? androidActions,
  }) async {
    if (!_isInitialized) {
      print('❌ NotificationServiceが初期化されていません');
      return;
    }

    // 🔧 修正: デフォルトアクションもconstを削除
    final defaultActions = <AndroidNotificationAction>[
      AndroidNotificationAction(
        'action_yes',
        '✅ はい',
        showsUserInterface: true,
      ),
      AndroidNotificationAction(
        'action_no',
        '❌ いいえ',
        showsUserInterface: true,
      ),
    ];

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'task_completion_channel',
      'タスク完了通知',
      channelDescription: 'タスク完了時の達成確認通知',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      actions: androidActions ?? defaultActions,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notifications.show(
        id,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
      print('✅ アクションボタン付き通知表示成功: $title');
    } catch (e) {
      print('❌ アクションボタン付き通知表示エラー: $e');
    }
  }

  // タスク完了通知
Future<void> showTaskCompletionNotification({
  required int id,
  required String taskTitle,
  required String albumName,
  String? payload,
}) async {
  if (!_isInitialized) {
    print('❌ NotificationServiceが初期化されていません');
    return;
  }

  try {
    // 🆕 既存の同じIDの通知をキャンセル（重複防止）
    await cancelNotification(id);
    
    // 🆕 少し待機してからキャンセルが完了するのを確保
    await Future.delayed(const Duration(milliseconds: 100));
    
    final title = 'タスク再生完了！';
    final body = '「$taskTitle」を再生しました。このタスクはできましたか？';
    
    final taskActions = <AndroidNotificationAction>[
      AndroidNotificationAction(
        'task_completion_yes',
        '✅ 達成しました',
        showsUserInterface: true,
      ),
      AndroidNotificationAction(
        'task_completion_no',
        '❌ 未達成',
        showsUserInterface: true,
      ),
      AndroidNotificationAction(
        'task_completion_open',
        '📱 アプリを開く',
        showsUserInterface: true,
      ),
    ];
    
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'task_completion_channel',
      'タスク完了通知',
      channelDescription: 'タスク完了時の達成確認通知',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      ongoing: false,
      autoCancel: true,
      actions: taskActions,
      // 🆕 追加: タグを設定して同じタスクの通知を置き換える
      tag: 'task_completion_$taskTitle',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
    
    print('✅ タスク完了通知表示成功: $taskTitle (ID: $id)');
    
  } catch (e) {
    print('❌ タスク完了通知表示エラー: $e');
    rethrow;
  }
}

  // 遅延通知をスケジュール
  Future<void> scheduleDelayedNotification({
    required int id,
    required String title,
    required String body,
    required Duration delay,
    String? payload,
    bool withActions = false,
  }) async {
    if (!_isInitialized) {
      print('❌ NotificationServiceが初期化されていません');
      return;
    }

    await cancelNotification(id);

    // 🔧 修正: アクションを動的に作成
    List<AndroidNotificationAction>? actions;
    if (withActions) {
      actions = [
        AndroidNotificationAction(
          'task_completion_yes',
          '✅ 達成しました',
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'task_completion_no',
          '❌ 未達成',
          showsUserInterface: true,
        ),
      ];
    }

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      withActions ? 'task_completion_channel' : 'habit_breaker_channel',
      withActions ? 'タスク完了通知' : '習慣改善通知',
      channelDescription: withActions ? 'タスク完了時の達成確認通知' : 'SNS中毒抑制のための通知',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      actions: actions,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      final scheduledDate = tz.TZDateTime.now(tz.local).add(delay);
      
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        notificationDetails,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      
      print('✅ 遅延通知スケジュール成功: ${delay.inMinutes}分後');
    } catch (e) {
      print('❌ 遅延通知スケジュールエラー: $e');
    }
  }

  // 通知をキャンセル
  Future<void> cancelNotification(int id) async {
    try {
      await _notifications.cancel(id);
      print('✅ 通知キャンセル成功: ID=$id');
    } catch (e) {
      print('❌ 通知キャンセルエラー: $e');
    }
  }

  // すべての通知をキャンセル
  Future<void> cancelAllNotifications() async {
  try {
    await _notifications.cancelAll();
    print('✅ すべての通知をキャンセルしました');
  } catch (e) {
    print('❌ 通知一括キャンセルエラー: $e');
  }
}



  // 🆕 自動再生関連の通知をすべてキャンセル
  Future<void> cancelAutoPlayNotifications() async {
  try {
    // タスク切り替え通知をキャンセル
    for (int i = 0; i < 20; i++) {
      await cancelNotification(taskTransitionBaseId + i);
    }
    
    // アルバム完了通知をキャンセル
    await cancelNotification(albumCompletionBaseId);
    
    // 進捗更新通知をキャンセル
    for (int i = 0; i < 20; i++) {
      await cancelNotification(progressUpdateBaseId + i);
    }
    
    // 🆕 睡眠スケジュール通知もキャンセル
    await cancelNotification(bedtimeNotificationId);
    await cancelNotification(wakeUpNotificationId);
    
    print('✅ 自動再生関連通知をすべてキャンセルしました');
  } catch (e) {
    print('❌ 自動再生通知キャンセルエラー: $e');
  }
}

/// 睡眠スケジュール通知をキャンセル
Future<void> cancelSleepScheduleNotifications() async {
  try {
    await cancelNotification(bedtimeNotificationId);
    await cancelNotification(wakeUpNotificationId);
    print('✅ 睡眠スケジュール通知をキャンセルしました');
  } catch (e) {
    print('❌ 睡眠スケジュール通知キャンセルエラー: $e');
  }
}

/// 睡眠スケジュール通知のテスト
Future<void> testSleepScheduleNotifications() async {
  try {
    print('🧪 睡眠スケジュール通知テスト開始');
    
    // 就寝通知をテスト
    await showBedtimeNotification(
      message: getRandomBedtimeMessage(),
      payload: 'test_bedtime',
    );
    
    await Future.delayed(const Duration(seconds: 3));
    
    // 起床通知をテスト
    await showWakeUpNotification(
      message: getRandomWakeUpMessage(),
      payload: 'test_wakeup',
    );
    
    print('✅ 睡眠スケジュール通知テスト完了');
  } catch (e) {
    print('❌ 睡眠スケジュール通知テストエラー: $e');
  }
}



  // アクティブな通知一覧を取得
  Future<List<ActiveNotification>> getActiveNotifications() async {
    try {
      final notifications = await _notifications.getActiveNotifications();
      return notifications;
    } catch (e) {
      print('❌ アクティブ通知取得エラー: $e');
      return [];
    }
  }

  // 通知チャンネルを作成（Android用）
  Future<void> createNotificationChannels() async {
  if (!Platform.isAndroid) return;

  try {
    // 習慣改善通知チャンネル
    const AndroidNotificationChannel habitChannel = AndroidNotificationChannel(
      'habit_breaker_channel',
      '習慣改善通知',
      description: 'SNS中毒抑制のための定期通知',
      importance: Importance.high,
    );

    // タスク完了通知チャンネル
    const AndroidNotificationChannel taskChannel = AndroidNotificationChannel(
      'task_completion_channel',
      'タスク完了通知',
      description: 'タスク完了時の達成確認通知',
      importance: Importance.high,
    );

    // 自動再生切り替え通知チャンネル
    const AndroidNotificationChannel autoPlayTransitionChannel = AndroidNotificationChannel(
      'auto_play_transition_channel',
      '自動再生切り替え通知',
      description: '自動再生時のタスク切り替え通知',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );

    // 自動再生完了通知チャンネル
    const AndroidNotificationChannel autoPlayCompletionChannel = AndroidNotificationChannel(
      'auto_play_completion_channel',
      '自動再生完了通知',
      description: 'アルバム自動再生完了時の通知',
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
    );

    // 自動再生進捗通知チャンネル
    const AndroidNotificationChannel autoPlayProgressChannel = AndroidNotificationChannel(
      'auto_play_progress_channel',
      '自動再生進捗通知',
      description: '自動再生中の進捗更新通知',
      importance: Importance.low,
      enableVibration: false,
      playSound: false,
    );

    // 自動再生励まし通知チャンネル
    const AndroidNotificationChannel autoPlayMotivationChannel = AndroidNotificationChannel(
      'auto_play_motivation_channel',
      '自動再生励まし通知',
      description: '自動再生中の励まし・モチベーション通知',
      importance: Importance.defaultImportance,
      enableVibration: true,
      playSound: true,
    );

    // 🆕 就寝通知チャンネル
    const AndroidNotificationChannel bedtimeChannel = AndroidNotificationChannel(
      'bedtime_channel',
      'Bedtime Reminders',
      description: 'Notifications to remind you to rest',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );

    // 🆕 起床通知チャンネル
    const AndroidNotificationChannel wakeUpChannel = AndroidNotificationChannel(
      'wakeup_channel',
      'Wake Up Messages',
      description: 'Morning motivational messages',
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
    );

    final androidImplementation = _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(habitChannel);
      await androidImplementation.createNotificationChannel(taskChannel);
      await androidImplementation.createNotificationChannel(autoPlayTransitionChannel);
      await androidImplementation.createNotificationChannel(autoPlayCompletionChannel);
      await androidImplementation.createNotificationChannel(autoPlayProgressChannel);
      await androidImplementation.createNotificationChannel(autoPlayMotivationChannel);
      // 🆕 睡眠スケジュール通知チャンネルを作成
      await androidImplementation.createNotificationChannel(bedtimeChannel);
      await androidImplementation.createNotificationChannel(wakeUpChannel);
      print('✅ 通知チャンネルを作成しました（睡眠スケジュール対応）');
    }
  } catch (e) {
    print('❌ 通知チャンネル作成エラー: $e');
  }
}

  // 🆕 自動再生用のテスト通知シーケンス
  Future<void> testAutoPlayNotificationSequence() async {
    try {
      print('🧪 自動再生通知シーケンステスト開始');
      
      // 1. タスク切り替え通知
      await showTaskTransitionNotification(
        completedTaskTitle: 'テストタスク1',
        nextTaskTitle: 'テストタスク2',
        albumName: 'テストアルバム',
        currentTaskNumber: 2,
        totalTasks: 4,
        payload: 'type=test_transition',
      );
      
      await Future.delayed(const Duration(seconds: 3));
      
      // 2. 進捗更新通知
      await showProgressUpdateNotification(
        currentTaskTitle: 'テストタスク2',
        currentTaskNumber: 2,
        totalTasks: 4,
        albumName: 'テストアルバム',
        elapsedMinutes: 6,
        payload: 'type=test_progress',
      );
      
      await Future.delayed(const Duration(seconds: 3));
      
      // 3. 励まし通知
      await showMotivationalNotification(
        message: '順調に進んでいますね！この調子で最後まで頑張りましょう！',
        albumName: 'テストアルバム',
        currentTaskNumber: 3,
        totalTasks: 4,
        payload: 'type=test_motivation',
      );
      
      await Future.delayed(const Duration(seconds: 3));
      
      // 4. アルバム完了通知
      await showAlbumCompletionNotification(
        albumName: 'テストアルバム',
        totalTasks: 4,
        totalDurationMinutes: 12,
        payload: 'type=test_completion',
      );
      
      print('✅ 自動再生通知シーケンステスト完了');
    } catch (e) {
      print('❌ 自動再生通知シーケンステストエラー: $e');
    }
  }

  /// 就寝通知を表示
Future<void> showBedtimeNotification({
  required String message,
  String? payload,
}) async {
  if (!_isInitialized) {
    print('❌ NotificationServiceが初期化されていません');
    return;
  }

  try {
    final title = 'Bedtime Reminder';
    
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'bedtime_channel',
      'Bedtime Reminders',
      channelDescription: 'Notifications to remind you to rest',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      ongoing: false,
      autoCancel: true,
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: BigTextStyleInformation(
        message,
        htmlFormatBigText: false,
        htmlFormatContentTitle: false,
      ),
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      bedtimeNotificationId,
      title,
      message,
      notificationDetails,
      payload: payload ?? 'bedtime_notification',
    );
    
    print('✅ 就寝通知表示成功: $message');
  } catch (e) {
    print('❌ 就寝通知表示エラー: $e');
  }
}

/// 起床通知を表示
Future<void> showWakeUpNotification({
  required String message,
  String? payload,
}) async {
  if (!_isInitialized) {
    print('❌ NotificationServiceが初期化されていません');
    return;
  }

  try {
    final title = 'Good Morning!';
    
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'wakeup_channel',
      'Wake Up Messages',
      channelDescription: 'Morning motivational messages',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      ongoing: false,
      autoCancel: true,
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: BigTextStyleInformation(
        message,
        htmlFormatBigText: false,
        htmlFormatContentTitle: false,
      ),
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      wakeUpNotificationId,
      title,
      message,
      notificationDetails,
      payload: payload ?? 'wakeup_notification',
    );
    
    print('✅ 起床通知表示成功: $message');
  } catch (e) {
    print('❌ 起床通知表示エラー: $e');
  }
}

/// ランダムな就寝メッセージを取得
String getRandomBedtimeMessage() {
  final messages = [
    'Time to put your phone away and rest',
    'Good sleep helps you achieve tomorrow\'s goals',
    'Your ideal self needs quality rest tonight',
    'Let\'s end the day mindfully',
    'Sweet dreams! Tomorrow is a new opportunity',
  ];
  
  final random = Random();
  return messages[random.nextInt(messages.length)];
}

/// ランダムな起床メッセージを取得
String getRandomWakeUpMessage() {
  final messages = [
    'Good morning! Ready to conquer today?',
    'A new day to become your ideal self',
    'Let\'s make today count!',
    'Wake up and chase your dreams',
    'Rise and shine! Your goals are waiting!',
  ];
  
  final random = Random();
  return messages[random.nextInt(messages.length)];
}

}