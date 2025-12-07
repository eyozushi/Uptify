// main_wrapper.dart - 自動再生機能対応版（エラー修正）
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'dart:math' as math;
import 'dart:convert'; 
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/gestures.dart';

import 'screens/home_screen.dart';
import 'screens/player_screen.dart';
import 'screens/album_detail_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/onboarding/onboarding_wrapper.dart';
import 'screens/single_album_create_screen.dart';
import 'screens/charts_screen.dart';
import 'screens/playback_screen.dart'; 
import 'screens/app_settings_screen.dart';
import 'models/task_item.dart';
import 'models/single_album.dart';
import 'services/data_service.dart';
import 'services/main_wrapper_provider.dart';
import 'services/notification_service.dart';
import 'services/habit_breaker_service.dart';
import 'services/task_completion_service.dart';
import 'services/audio_service.dart';
import 'widgets/completion_dialog.dart';
import 'widgets/album_completion_dialog.dart';
import 'widgets/completion_result_dialog.dart';
import 'widgets/activity_widget.dart';
import 'screens/artist_screen.dart'; 
import 'services/live_activities_service.dart';
import 'models/live_activity_data.dart';
import 'models/activity_state.dart';

// main_wrapper.dart の上部に追加
enum NotificationType {
  NORMAL_TASK_COMPLETION,      // 通常モード用
  AUTO_PLAY_PROGRESS,          // 自動再生進行中
  AUTO_PLAY_FINAL_COMPLETION,  // 自動再生最終完了
}

class AutoPlayNotificationSystem {
  // 自動再生用のID範囲（20000番台）
  static const int AUTO_PLAY_BASE = 20000;
  static const int AUTO_PLAY_FINAL = 29999;
  
  // 通常モード用のID範囲（30000番台）
  static const int NORMAL_BASE = 30000;
  
  static int autoPlayTaskId(int index) => AUTO_PLAY_BASE + index;
  static int normalTaskId(int index) => NORMAL_BASE + index;
}

class AutoPlayNotificationManager {
  static const String AUTO_PLAY_KEY = 'auto_play_session';
  
  // 自動再生セッション情報を保存
  static String createAutoPlaySession({
    required List<String> taskIds,
    required String albumName,
    required bool isSingleAlbum,
    required DateTime startTime,
  }) {
    final session = {
      'sessionId': DateTime.now().millisecondsSinceEpoch.toString(),
      'taskIds': taskIds.join(','),
      'albumName': albumName,
      'isSingleAlbum': isSingleAlbum.toString(),
      'startTime': startTime.toIso8601String(),
      'version': '2.0', // バージョン管理で互換性を保つ
    };
    
    return session.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }
}


class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class NotificationIds {
  static const int AUTO_PLAY_BASE = 10000;  // 自動再生用の基準ID
  static const int TASK_BASE = 11000;       // タスク用の基準ID
  
  static int autoPlayTask(int index) => AUTO_PLAY_BASE + index;
  static int autoPlayAlbum() => AUTO_PLAY_BASE + 999;
}

class _MainWrapperState extends State<MainWrapper> with WidgetsBindingObserver, TickerProviderStateMixin {

  // 🆕 追加：PlaybackScreen用のGlobalKey
  final GlobalKey<State<PlaybackScreen>> _playbackScreenKey = GlobalKey<State<PlaybackScreen>>();

  // サービスインスタンス（引数なしで初期化 - エラー修正）
  late final DataService _dataService;
  late final NotificationService _notificationService;
  late final HabitBreakerService _habitBreakerService;
  late final TaskCompletionService _taskCompletionService;
  late final AudioService _audioService;

  final GlobalKey _playerScreenKey = GlobalKey(); // 🔧 変更：型指定を削除


  // 🆕 追加：アニメーション制御用
bool _isAnimating = false;


  // 🆕 PlayerScreenスライドアニメーション用（修正版）
double _playerDragOffset = 1.0; // 0.0 = 完全表示、1.0 = 完全非表示
bool _isDraggingPlayer = false;
double _playerDragVelocity = 0.0; // 🆕 追加：ドラッグ速度を記録
  
  // オンボーディング関連の状態
  bool _isCheckingFirstLaunch = true;
  bool _shouldShowOnboarding = false;
  
  // プレイヤー関連の状態
  String _currentIdealSelf = "理想の自分";
  String _currentArtistName = "You";
  List<TaskItem> _currentTasks = [];
  String _currentAlbumImagePath = "";
  int _currentTaskIndex = 0;
  bool _isPlaying = false;
  double _currentProgress = 0.0;
  Timer? _progressTimer;
  int _elapsedSeconds = 0;
  
  // 🆕 自動再生機能
  bool _isAutoPlayEnabled = false;
  bool _isAutoPlayInProgress = false;

  // 通知からの復帰フラグ
  bool _isNotificationReturning = false;
  
  // バックグラウンド対応のための開始時間記録
  DateTime? _taskStartTime;
  DateTime? _pauseStartTime;
  int _totalPausedSeconds = 0;
  
  // プレイヤーで実際に再生中のタスク
  List<TaskItem> _playingTasks = [];
  bool _isPlayingSingleAlbum = false;
  
  // 画像データ
  Uint8List? _imageBytes;
  
  // ページ管理
  int _selectedPageIndex = 0;

  // 🆕 追加: PlayerScreenのページ制御用
  int? _forcePlayerPageIndex;

  // 画面管理の拡張
  bool _isPlayerScreenVisible = false;
  bool _isAlbumDetailVisible = false;
  bool _isSettingsVisible = false;
  bool _isArtistScreenVisible = false;
  SingleAlbum? _currentSingleAlbum;
  SingleAlbum? _playingSingleAlbum;

  // 🆕 Live Activities関連の追加変数
  late final LiveActivitiesService _liveActivitiesService;
  bool _isActivityActive = false;
  Timer? _activityUpdateTimer;

  // 🆕 時刻ベース状態管理用の変数
  DateTime? _autoPlaySessionStartTime;
  List<int> _taskDurations = []; // 各タスクの時間（秒）
  bool _isTimeBasedRestorationEnabled = false;

  // 今日のタスク完了回数をリアルタイム管理
  Map<String, int> _todayTaskCompletions = {};

  late AnimationController _playerDragController;
late Animation<double> _playerDragAnimation;
  

  void _showArtistScreen() {
    setState(() {
      _isArtistScreenVisible = true;
    });
  }

  void _hideArtistScreen() {
    setState(() {
      _isArtistScreenVisible = false;
    });
  }

  void _showFullPlayerWithIdealPage() {
  _stopProgressTimer();
  
  setState(() {
    _playingTasks = List.from(_currentTasks);
    _isPlayingSingleAlbum = false;
    _playingSingleAlbum = null;
    _currentTaskIndex = -1;
    _isPlaying = false;
    _elapsedSeconds = 0;
    _currentProgress = 0.0;
    _isPlayerScreenVisible = true;
    _isDraggingPlayer = false;
  });
  
  // 🔧 修正：AnimationController を 0.0 に設定
  _playerDragController.value = 0.0;
  
  print('🌟 理想像ページでプレイヤーを開始しました（インデックス: -1）');
}

  // _toggleAutoPlay()メソッドまたは自動再生開始部分に追加
void _startAutoPlaySession() {
  if (!_isAutoPlayEnabled || _playingTasks.isEmpty) return;
  
  try {
    _autoPlaySessionStartTime = DateTime.now();
    _taskDurations = _playingTasks.map((task) => task.duration * 60).toList();
    _isTimeBasedRestorationEnabled = true;
    
    // SharedPreferencesに永続保存
    _saveAutoPlaySessionData();
    
    print('自動再生セッション開始: ${_autoPlaySessionStartTime}');
  } catch (e) {
    print('自動再生セッション開始エラー: $e');
  }
}

  @override
void initState() {
  super.initState();

  // 既存のサービス初期化...
  try {
    _liveActivitiesService = LiveActivitiesService();
    print('✅ LiveActivitiesService 初期化完了');
  } catch (e) {
    print('❌ LiveActivitiesService 初期化エラー: $e');
    rethrow;
  }
  
  // サービスを段階的に初期化してエラーを特定
  try {
    _dataService = DataService();
    print('✅ DataService 初期化完了');
  } catch (e) {
    print('❌ DataService 初期化エラー: $e');
    rethrow;
  }
  
  try {
    _notificationService = NotificationService();
    print('✅ NotificationService 初期化完了');
  } catch (e) {
    print('❌ NotificationService 初期化エラー: $e');
    rethrow;
  }
  
  try {
    _habitBreakerService = HabitBreakerService();
    print('✅ HabitBreakerService 初期化完了');
  } catch (e) {
    print('❌ HabitBreakerService 初期化エラー: $e');
    rethrow;
  }
  
  try {
    _taskCompletionService = TaskCompletionService();
    print('✅ TaskCompletionService 初期化完了');
  } catch (e) {
    print('❌ TaskCompletionService 初期化エラー: $e');
    rethrow;
  }
  
  try {
    _audioService = AudioService();
    // 🔧 追加: AudioServiceの安全な初期化
    _initializeAudioService();
    print('✅ AudioService 初期化完了');
  } catch (e) {
    print('❌ AudioService 初期化エラー: $e');
    rethrow;
  }


  
  
  WidgetsBinding.instance.addObserver(this);
  
  _checkFirstLaunchAndInitialize();
  _registerWithController();
  _initializeNotificationService();
  _loadTodayCompletions();

  // 🆕 追加：ドラッグ用 AnimationController
_playerDragController = AnimationController(
  vsync: this,
  value: 1.0, // 初期値：閉じた状態
);

_playerDragAnimation = Tween<double>(
  begin: 0.0,
  end: 1.0,
).animate(_playerDragController);
}

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    
    _progressTimer?.cancel();
    _unregisterFromController();
    _habitBreakerService.dispose();
    _audioService.dispose(); 
    _endLiveActivityIfNeeded();
    _activityUpdateTimer?.cancel();
    _playerDragController.dispose();

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.paused:
        _onAppPaused();
        break;
      case AppLifecycleState.resumed:
        _onAppResumed();
        break;
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.detached:
        break;
      case AppLifecycleState.hidden:
        _onAppPaused();
        break;
    }
  }

  void _onAppPaused() {
  print('🔧 アプリがバックグラウンドに移行開始');
  print('🔧 現在の状態: isPlaying=${_isPlaying}, playingTasks=${_playingTasks.length}, currentTaskIndex=${_currentTaskIndex}');
  print('🔧 現在の進捗: elapsed=${_elapsedSeconds}秒, progress=${_currentProgress}');
  
  if (_isPlaying && _playingTasks.isNotEmpty) {
    _pauseStartTime = DateTime.now();
    
    _habitBreakerService.pauseNotifications();
    
    // 🔧 修正：自動再生の場合のみ現在のタスクの通知をスケジュール
    if (_isAutoPlayEnabled && _currentTaskIndex >= 0) {
      print('🔔 自動再生モード: 現在のタスクの残り時間で通知をスケジュール');
      _scheduleCurrentTaskAutoPlayNotification();
    } else if (!_isAutoPlayEnabled) {
      print('🔔 通常モード: バックグラウンド通知をスケジュール');
      _scheduleBackgroundTaskCompletion();
    }
    
    print('🔧 アプリがバックグラウンドに移行完了 - 自動再生: $_isAutoPlayEnabled');
  } else {
    print('🔧 通知スケジュール条件に合わない: isPlaying=${_isPlaying}, tasksEmpty=${_playingTasks.isEmpty}');
  }
}

void _onAppResumed() {
  if (_isNotificationReturning) {
    _isNotificationReturning = false;
    return;
  }

  // 自動再生が有効で、タスクが再生中だった場合
  if (_isAutoPlayEnabled && _isPlaying && _playingTasks.isNotEmpty && _taskStartTime != null) {
    final now = DateTime.now();
    final totalElapsed = now.difference(_taskStartTime!).inSeconds - _totalPausedSeconds;
    
    // 現在のタスクの完了チェックと次タスクへの自動移行
    _checkAndProcessCompletedTasks(totalElapsed);
    
  } else if (_isPlaying && _playingTasks.isNotEmpty && _pauseStartTime != null) {
    // 通常モードの復帰処理（既存）
    final pauseDuration = DateTime.now().difference(_pauseStartTime!);
    _totalPausedSeconds += pauseDuration.inSeconds;
    
    if (_taskStartTime != null) {
      final totalElapsed = DateTime.now().difference(_taskStartTime!).inSeconds - _totalPausedSeconds;
      _checkAndProcessCompletedTasks(totalElapsed);
    }
    
    _pauseStartTime = null;
    _habitBreakerService.resumeNotifications();
    _cancelBackgroundTaskCompletion();
  }
}

void _checkAndProcessCompletedTasks(int totalElapsed) {
  if (_currentTaskIndex < 0 || _currentTaskIndex >= _playingTasks.length) return;
  
  int cumulativeTime = 0;
  int targetTaskIndex = _currentTaskIndex;
  
  // 完了したタスクを順次処理
  for (int i = _currentTaskIndex; i < _playingTasks.length; i++) {
    final taskDuration = _playingTasks[i].duration * 60;
    
    if (totalElapsed >= cumulativeTime + taskDuration) {
      // このタスクは完了済み
      if (i == _currentTaskIndex) {
        // 現在のタスクが完了
        _recordCompletedTaskInBackground(_playingTasks[i]);
      }
      
      cumulativeTime += taskDuration;
      targetTaskIndex = i + 1;
    } else {
      // このタスクは進行中
      break;
    }
  }
  
  // 状態を更新
  if (targetTaskIndex > _currentTaskIndex) {
    if (targetTaskIndex >= _playingTasks.length) {
      // 全タスク完了
      _completeAllTasksInBackground();
    } else {
      // 次のタスクに移行
      _moveToTaskInBackground(targetTaskIndex, totalElapsed - cumulativeTime);
    }
  } else {
    // 現在のタスクを継続
    _updateCurrentTaskState(totalElapsed - cumulativeTime);
  }
}

void _completeAllTasksInBackground() {
  final lastTaskIndex = _playingTasks.length - 1;
  final lastPageIndex = _isPlayingSingleAlbum ? lastTaskIndex : lastTaskIndex + 1;
  
  setState(() {
    _currentTaskIndex = lastTaskIndex;
    _forcePlayerPageIndex = lastPageIndex;
    _isPlaying = false;
    _isAutoPlayEnabled = false;
    _elapsedSeconds = _playingTasks[lastTaskIndex].duration * 60;
    _currentProgress = 1.0;
    _isPlayerScreenVisible = true;
  });
  
  // PlayerScreenに完了状態を通知
  _onPlayerStateChanged(
    currentTaskIndex: lastTaskIndex,
    isPlaying: false,
    progress: 1.0,
    elapsedSeconds: _playingTasks[lastTaskIndex].duration * 60,
    isAutoPlayEnabled: false,
    forcePageChange: lastPageIndex,
  );
  
  // アルバム完了ダイアログを表示
  Future.delayed(const Duration(milliseconds: 500), () {
    if (mounted) {
      _showAlbumCompletionDialog();
    }
  });
  
  print('バックグラウンド復帰: 全タスク完了状態に設定');
}

void _updateCurrentTaskState(int elapsedInCurrentTask) {
  if (_currentTaskIndex < 0 || _currentTaskIndex >= _playingTasks.length) return;
  
  final currentTask = _playingTasks[_currentTaskIndex];
  final maxElapsed = currentTask.duration * 60;
  
  setState(() {
    _elapsedSeconds = elapsedInCurrentTask.clamp(0, maxElapsed - 1);
    _currentProgress = _elapsedSeconds / maxElapsed;
    _isPlaying = true;
    
    // 🔧 修正：タスク開始時刻を正しく設定
    _taskStartTime = DateTime.now();  // 現在時刻を開始時刻とする
    _pauseStartTime = null;
    _totalPausedSeconds = 0;  // リセット
  });
  
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) {
      _onPlayerStateChanged(
        currentTaskIndex: _currentTaskIndex,
        isPlaying: true,
        progress: _currentProgress,
        elapsedSeconds: _elapsedSeconds,
        isAutoPlayEnabled: _isAutoPlayEnabled,
      );
      
      _startProgressTimer();
      
      print('バックグラウンド復帰: タスク${_currentTaskIndex + 1}継続 (${_elapsedSeconds}秒経過)');
    }
  });
}

void _moveToTaskInBackground(int taskIndex, int elapsedInCurrentTask) {
  final pageIndex = _isPlayingSingleAlbum ? taskIndex : taskIndex + 1;
  
  setState(() {
    _currentTaskIndex = taskIndex;
    _forcePlayerPageIndex = pageIndex;
    _elapsedSeconds = elapsedInCurrentTask.clamp(0, _playingTasks[taskIndex].duration * 60 - 1);
    _currentProgress = _elapsedSeconds / (_playingTasks[taskIndex].duration * 60);
    _isPlaying = true;
    _isAutoPlayEnabled = true;
    
    // 🔧 修正：タスク開始時刻を正しく設定
    _taskStartTime = DateTime.now();  // 現在時刻を開始時刻とする
    _pauseStartTime = null;
    _totalPausedSeconds = 0;  // リセット
  });
  
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) {
      _onPlayerStateChanged(
        currentTaskIndex: taskIndex,
        isPlaying: true,
        progress: _currentProgress,
        elapsedSeconds: _elapsedSeconds,
        isAutoPlayEnabled: true,
        forcePageChange: pageIndex,
      );
      
      _startProgressTimer();
      
      print('バックグラウンド復帰: タスク${taskIndex + 1}に移動 (${_elapsedSeconds}秒経過)');
    }
  });
}

Future<void> _recordCompletedTaskInBackground(TaskItem task) async {
  try {
    await _taskCompletionService.recordTaskCompletion(
      taskId: task.id,
      taskTitle: task.title,
      wasSuccessful: true,
      elapsedSeconds: task.duration * 60,
      albumType: _isPlayingSingleAlbum ? 'single' : 'life_dream',
      albumName: _isPlayingSingleAlbum && _playingSingleAlbum != null 
          ? _playingSingleAlbum!.albumName 
          : _currentIdealSelf,
      albumId: _isPlayingSingleAlbum && _playingSingleAlbum != null 
          ? _playingSingleAlbum!.id 
          : null,
    );
    
    setState(() {
      _todayTaskCompletions[task.id] = (_todayTaskCompletions[task.id] ?? 0) + 1;
    });
    
    print('バックグラウンド完了記録: ${task.title}');
  } catch (e) {
    print('バックグラウンド完了記録エラー: $e');
  }
}



// 🆕 自動再生状態の検証と修正
void _validateAndCorrectAutoPlayState() {
  if (!_isAutoPlayEnabled || _taskStartTime == null) return;
  
  // 実際の経過時間から現在いるべき状態を計算
  final actualElapsed = DateTime.now().difference(_taskStartTime!).inSeconds - _totalPausedSeconds;
  
  int expectedTaskIndex = _isPlayingSingleAlbum ? 0 : -1;
  int expectedElapsed = 0;
  int cumulativeTime = 0;
  
  for (int i = (_isPlayingSingleAlbum ? 0 : -1); i < _playingTasks.length; i++) {
    final taskDuration = i == -1 ? 0 : _playingTasks[i].duration * 60;
    
    if (actualElapsed <= cumulativeTime + taskDuration) {
      expectedTaskIndex = i;
      expectedElapsed = actualElapsed - cumulativeTime;
      break;
    }
    
    cumulativeTime += taskDuration;
  }
  
  // 状態が間違っていれば修正
  // 状態が間違っていれば修正
if (expectedTaskIndex != _currentTaskIndex || 
    (expectedElapsed - _elapsedSeconds).abs() > 5) {  // Math.abs → .abs()に修正
  
  print('🔧 状態修正: ${_currentTaskIndex} → ${expectedTaskIndex}, ${_elapsedSeconds}秒 → ${expectedElapsed}秒');
  
  setState(() {
    _currentTaskIndex = expectedTaskIndex;
    _elapsedSeconds = expectedElapsed;
    _updateProgress();
    _forcePlayerPageIndex = _isPlayingSingleAlbum ? expectedTaskIndex : expectedTaskIndex + 1;
  });
  
  _onPlayerStateChanged(
    currentTaskIndex: expectedTaskIndex,
    progress: _currentProgress,
    elapsedSeconds: expectedElapsed,
    forcePageChange: _forcePlayerPageIndex,
  );
}
}

// 🆕 自動再生状態の確認と修正
void _checkAndCorrectAutoPlayState() {
  if (!_isAutoPlayEnabled || _playingTasks.isEmpty) return;
  
  try {
    // 現在時刻と開始時刻から実際の進行状況を計算
    if (_taskStartTime != null) {
      final actualElapsed = DateTime.now().difference(_taskStartTime!).inSeconds - _totalPausedSeconds;
      
      // 累積で何秒経過したかを計算
      int cumulativeTime = 0;
      int correctTaskIndex = -1;
      int correctElapsedInCurrentTask = 0;
      
      for (int i = (_isPlayingSingleAlbum ? 0 : -1); i < _playingTasks.length; i++) {
        final taskDuration = i == -1 ? 0 : _playingTasks[i].duration * 60;
        
        if (actualElapsed <= cumulativeTime + taskDuration) {
          correctTaskIndex = i;
          correctElapsedInCurrentTask = actualElapsed - cumulativeTime;
          break;
        }
        
        cumulativeTime += taskDuration;
      }
      
      // 状態が間違っている場合は修正
      if (correctTaskIndex != _currentTaskIndex) {
        print('🔧 自動再生状態修正: ${_currentTaskIndex} → ${correctTaskIndex}');
        
        setState(() {
          _currentTaskIndex = correctTaskIndex;
          _elapsedSeconds = correctElapsedInCurrentTask;
          _updateProgress();
          
          // PlayerScreenページも更新
          _forcePlayerPageIndex = _isPlayingSingleAlbum 
              ? correctTaskIndex 
              : correctTaskIndex + 1;
        });
        
        // PlayerScreenに状態変更を通知
        _onPlayerStateChanged(
          currentTaskIndex: correctTaskIndex,
          isPlaying: true,
          progress: _currentProgress,
          elapsedSeconds: correctElapsedInCurrentTask,
          isAutoPlayEnabled: true,
          forcePageChange: _forcePlayerPageIndex,
        );
        
        _startNewTask();
      }
    }
  } catch (e) {
    print('❌ 自動再生状態確認エラー: $e');
  }
}

// 新規追加メソッド
Future<void> _checkForNewTasks() async {
  try {
    final currentTotalTasks = await _taskCompletionService.getTotalCompletedTasks();
    print('現在の累計タスク数: $currentTotalTasks');
    
    // このメソッドはmain_wrapperでは実際の処理は不要
    // ChartsScreenに通知のみ行う
    await _notifyChartsScreenOfCompletion();
  } catch (e) {
    print('タスク監視エラー: $e');
  }
}

// ChartsScreenに完了通知を送る
Future<void> _notifyChartsScreenOfCompletion() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final currentCount = prefs.getInt('charts_completion_notification_count') ?? 0;
    await prefs.setInt('charts_completion_notification_count', currentCount + 1);
    await prefs.setInt('charts_last_completion_timestamp', DateTime.now().millisecondsSinceEpoch);
    print('ChartsScreenに完了通知を送信: ${currentCount + 1}個目');
  } catch (e) {
    print('ChartsScreen完了通知エラー: $e');
  }
}

// 🆕 自動再生セッション復元チェック（修正版）
Future<void> _checkAndRestoreAutoPlaySession() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    
    // 🔧 修正: getBoolの正しい使用方法
    final isSessionActive = prefs.getBool('autoplay_session_active') ?? false;
    if (!isSessionActive) {
      return;
    }
    
    final startTimeStr = prefs.getString('autoplay_start_time');
    if (startTimeStr == null) return;
    
    final startTime = DateTime.parse(startTimeStr);
    final taskDurationStrings = prefs.getStringList('autoplay_task_durations') ?? [];
    final taskDurations = taskDurationStrings.map((d) => int.parse(d)).toList();
    final initialTaskIndex = prefs.getInt('autoplay_current_task_index') ?? 0;
    
    // 5分以上経過していたらセッションを破棄
    if (DateTime.now().difference(startTime).inMinutes > 300) {
      await _clearAutoPlaySessionData();
      return;
    }
    
    // 現在の状態を計算
    final calculatedState = _calculateCurrentStateFromTime(startTime, taskDurations, initialTaskIndex);
    
    // セッションデータを作成
    final sessionData = {
      'startTime': startTime,
      'currentTaskIndex': initialTaskIndex,
      'taskDurations': taskDurations,
      'albumName': prefs.getString('autoplay_album_name') ?? '',
      'isSingleAlbum': prefs.getBool('autoplay_is_single_album') ?? false,
    };
    
    // 計算結果でアプリ状態を復元
    await _restoreAutoPlayState(calculatedState, sessionData);
    
    print('自動再生セッション復元完了');
  } catch (e) {
    print('自動再生セッション復元エラー: $e');
    await _clearAutoPlaySessionData();
  }
}

// 🆕 自動再生状態の復元
Future<void> _restoreAutoPlayState(Map<String, dynamic> calculatedState, Map<String, dynamic> sessionData) async {
  try {
    final taskIndex = calculatedState['taskIndex'] as int;
    final elapsedSeconds = calculatedState['elapsedSeconds'] as int;
    final progress = calculatedState['progress'] as double;
    final isCompleted = calculatedState['isCompleted'] as bool;
    final isPlaying = calculatedState['isPlaying'] as bool;
    
    // タスクリストを復元（セッションデータに基づいて）
    final isSingleAlbum = sessionData['isSingleAlbum'] as bool;
    _isPlayingSingleAlbum = isSingleAlbum;
    
    final pageIndex = isSingleAlbum ? taskIndex : taskIndex + 1;
    
    setState(() {
      _currentTaskIndex = taskIndex;
      _elapsedSeconds = elapsedSeconds;
      _currentProgress = progress;
      _isPlaying = isPlaying && !isCompleted;
      _isAutoPlayEnabled = isPlaying && !isCompleted;
      _forcePlayerPageIndex = pageIndex;
      _isPlayerScreenVisible = true;
      _autoPlaySessionStartTime = sessionData['startTime'] as DateTime;
      _isTimeBasedRestorationEnabled = true;
    });
    
    if (isCompleted) {
      // アルバム完了状態
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _showAlbumCompletionDialog();
      });
    } else if (isPlaying) {
      // 継続再生状態
      _startNewTask();
      _startProgressTimer();
    }
    
    // PlayerScreenに状態を通知
    _onPlayerStateChanged(
      currentTaskIndex: taskIndex,
      isPlaying: isPlaying && !isCompleted,
      progress: progress,
      elapsedSeconds: elapsedSeconds,
      isAutoPlayEnabled: isPlaying && !isCompleted,
      forcePageChange: pageIndex,
    );
    
    print('状態復元完了: タスク${taskIndex + 1}, ${elapsedSeconds}秒経過, 進捗${(progress * 100).toInt()}%');
  } catch (e) {
    print('状態復元実行エラー: $e');
  }
}

// 🆕 自動再生セッションデータをクリア（修正版）
Future<void> _clearAutoPlaySessionData() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('autoplay_start_time');
    await prefs.remove('autoplay_current_task_index');
    await prefs.remove('autoplay_task_durations');
    await prefs.remove('autoplay_album_name');
    await prefs.remove('autoplay_is_single_album');
    await prefs.remove('autoplay_session_active'); // 🔧 修正: setBoolではなくremove
    
    _autoPlaySessionStartTime = null;
    _isTimeBasedRestorationEnabled = false;
    
    print('自動再生セッションデータをクリア');
  } catch (e) {
    print('セッションデータクリアエラー: $e');
  }
}

// 自動再生停止時またはアルバム完了時に呼び出し
void _stopAutoPlaySession() {
  _clearAutoPlaySessionData();
  print('自動再生セッション終了');
}

Future<void> _scheduleAutoPlayTaskCompletions() async {
  print('🔧 自動再生モード: タスク切り替え通知をスケジュール');
  
  // 完了済みタスクのIDリスト
  List<String> completedTaskIds = [];
  for (int i = 0; i < _currentTaskIndex; i++) {
    if (i >= 0 && i < _playingTasks.length) {
      completedTaskIds.add(_playingTasks[i].id);
    }
  }
  
  int cumulativeSeconds = 0;
  
  for (int i = _currentTaskIndex; i < _playingTasks.length; i++) {
    final task = _playingTasks[i];
    
    // 時間計算
    if (i == _currentTaskIndex) {
      cumulativeSeconds = (task.duration * 60) - _elapsedSeconds;
    } else {
      cumulativeSeconds += (task.duration * 60);
    }
    
    // この時点での完了タスクリスト
    List<String> taskIdsUpToNow = List.from(completedTaskIds);
    for (int j = _currentTaskIndex; j <= i; j++) {
      if (j < _playingTasks.length) {
        taskIdsUpToNow.add(_playingTasks[j].id);
      }
    }
    
    final isLastTask = (i == _playingTasks.length - 1);
    final notificationId = AutoPlayNotificationSystem.autoPlayTaskId(i);
    
    // ペイロード作成（自動再生用の特別な形式）
    final payload = _createAutoPlayPayload(
      taskIndex: i,
      isLastTask: isLastTask,
      completedTaskIds: taskIdsUpToNow,
      albumName: _isPlayingSingleAlbum && _playingSingleAlbum != null 
          ? _playingSingleAlbum!.albumName 
          : _currentIdealSelf,
    );
    
    // タイトルとボディをタスクに応じて変更
    String title;
    String body;
    
    if (isLastTask) {
      title = '🎉 アルバム完了！';
      body = 'すべてのタスクが完了しました。達成状況を記録してください。';
    } else {
      final nextTask = _playingTasks[i + 1];
      title = '⏭️ タスク切り替え';
      body = '「${task.title}」が完了。次は「${nextTask.title}」です。';
    }
    
    await _notificationService.scheduleDelayedNotification(
      id: notificationId,
      title: title,
      body: body,
      delay: Duration(seconds: cumulativeSeconds),
      payload: payload,
      withActions: false,
    );
    
    print('🔧 自動再生通知[$i]: ID=$notificationId, ${cumulativeSeconds}秒後');
  }
}

// 自動再生用ペイロード作成
String _createAutoPlayPayload({
  required int taskIndex,
  required bool isLastTask,
  required List<String> completedTaskIds,
  required String albumName,
}) {
  return [
    'mode=AUTO_PLAY',
    'taskIndex=$taskIndex',
    'isLastTask=$isLastTask',
    'completedTaskIds=${completedTaskIds.join(",")}',
    'albumName=${Uri.encodeComponent(albumName)}',
    'isSingleAlbum=$_isPlayingSingleAlbum',
    'timestamp=${DateTime.now().millisecondsSinceEpoch}',
  ].join('&');
}

Future<void> _scheduleNormalTaskCompletion() async {
  print('🔧 通常モード通知スケジュール開始');
  
  if (_currentTaskIndex < 0 || _currentTaskIndex >= _playingTasks.length) {
    print('🔧 タスクインデックス範囲外: $_currentTaskIndex');
    return;
  }
  
  final currentTask = _playingTasks[_currentTaskIndex];
  final remainingSeconds = (currentTask.duration * 60) - _elapsedSeconds;
  final notificationId = AutoPlayNotificationSystem.normalTaskId(_currentTaskIndex);
  
  print('🔧 通知詳細: タスク=${currentTask.title}, 残り時間=${remainingSeconds}秒, ID=${notificationId}');
  
  if (remainingSeconds <= 0) {
    print('🔧 残り時間が0以下のため通知スキップ');
    return;
  }
  
  final payload = [
    'mode=NORMAL',
    'taskIndex=$_currentTaskIndex',
    'taskId=${currentTask.id}',
    'taskTitle=${Uri.encodeComponent(currentTask.title)}',
    'albumName=${Uri.encodeComponent(_currentIdealSelf)}',
  ].join('&');
  
  try {
    await _notificationService.scheduleDelayedNotification(
      id: notificationId,
      title: 'タスク完了',
      body: '「${currentTask.title}」の時間が終了しました',
      delay: Duration(seconds: remainingSeconds),
      payload: payload,
      withActions: true,
    );
    
    print('✅ 通常モード通知スケジュール成功: ID=$notificationId, ${remainingSeconds}秒後');
  } catch (e) {
    print('❌ 通常モード通知スケジュールエラー: $e');
  }
}

// 削除: _scheduleAutoPlayFinalNotification()メソッド全体

// 復活: _scheduleBackgroundTaskCompletion()メソッドの修正
Future<void> _scheduleBackgroundTaskCompletion() async {
  print('🔧 バックグラウンド通知スケジュール開始');
  
  if (_currentTaskIndex == -1) {
    print('🔧 理想像ページのためスキップ');
    return;
  }
  
  if (_isAutoPlayEnabled) {
    // 自動再生時も個別タスク完了通知をスケジュール
    await _scheduleAutoPlayTaskNotifications();
  } else {
    await _scheduleNormalTaskCompletion();
  }
}


Future<void> _scheduleAutoPlayTaskNotifications() async {
  try {
    // 現在のタスクの残り時間を計算
    final currentTask = _playingTasks[_currentTaskIndex];
    final remainingSeconds = (currentTask.duration * 60) - _elapsedSeconds;
    
    if (remainingSeconds <= 0) {
      print('残り時間が0以下のためスケジュールをスキップ');
      return;
    }
    
    final notificationId = 20000 + _currentTaskIndex;
    final isLastTask = _currentTaskIndex >= _playingTasks.length - 1;
    
    // ペイロード作成（シンプルに）
    final payload = [
      'mode=AUTO_PLAY_TASK',
      'completedTaskIndex=$_currentTaskIndex',
      'isLastTask=$isLastTask',
    ].join('&');
    
    await _notificationService.scheduleDelayedNotification(
      id: notificationId,
      title: isLastTask ? 'アルバム完了！' : 'タスク切り替え',
      body: isLastTask
          ? '全てのタスクが完了しました。結果を確認してください。'
          : '「${currentTask.title}」完了→次のタスクを開始',
      delay: Duration(seconds: remainingSeconds),
      payload: payload,
      withActions: false,
    );
    
    print('自動再生タスク通知スケジュール: ${currentTask.title} - ${remainingSeconds}秒後');
    
    // ここが重要：バックグラウンドでも次のタスクに自動で進むようにタイマーを設定
    if (!isLastTask && _isAutoPlayEnabled) {
      Future.delayed(Duration(seconds: remainingSeconds), () {
        if (_isAutoPlayEnabled && !_isPlayerScreenVisible && mounted) {
          // バックグラウンドで次のタスクに自動移動
          _autoMoveToNextTaskInBackground();
        }
      });
    }
    
  } catch (e) {
    print('自動再生タスク通知スケジュールエラー: $e');
  }
}

// バックグラウンドで次のタスクに自動移動
void _autoMoveToNextTaskInBackground() {
  if (!_isAutoPlayEnabled) return;
  
  // 最後のタスクかチェック
  if (_currentTaskIndex >= _playingTasks.length - 1) {
    // アルバム完了
    setState(() {
      _isPlaying = false;
      _isAutoPlayEnabled = false;
    });
    return;
  }
  
  // 次のタスクに移動
  final nextTaskIndex = _currentTaskIndex + 1;
  final nextPageIndex = _isPlayingSingleAlbum ? nextTaskIndex : nextTaskIndex + 1;
  
  setState(() {
    _currentTaskIndex = nextTaskIndex;
    _forcePlayerPageIndex = nextPageIndex;
    _elapsedSeconds = 0;
    _currentProgress = 0.0;
    _isPlaying = true;
    _taskStartTime = DateTime.now();
    _totalPausedSeconds = 0;
  });
  
  print('🔄 バックグラウンド自動タスク切り替え: タスク${nextTaskIndex}開始');
  
  // 次のタスクの通知もスケジュール
  _scheduleAutoPlayTaskNotifications();
}

// 新規追加メソッド
Future<void> _scheduleNextTaskAutoPlayNotifications(int nextTaskIndex, int delayFromNow) async {
  if (nextTaskIndex >= _playingTasks.length) return;
  
  final nextTask = _playingTasks[nextTaskIndex];
  final totalDelay = delayFromNow + (nextTask.duration * 60);
  final isLastTask = nextTaskIndex >= _playingTasks.length - 1;
  
  final notificationId = 20000 + nextTaskIndex;
  
  final payload = [
    'mode=AUTO_PLAY_TASK',
    'completedTaskIndex=$nextTaskIndex',
    'nextTaskIndex=${nextTaskIndex + 1}',
    'isLastTask=$isLastTask',
    'albumName=${Uri.encodeComponent(_isPlayingSingleAlbum && _playingSingleAlbum != null ? _playingSingleAlbum!.albumName : _currentIdealSelf)}',
    'isSingleAlbum=$_isPlayingSingleAlbum',
    'shouldContinueAutoPlay=true',
    'timestamp=${DateTime.now().millisecondsSinceEpoch}',
  ].join('&');
  
  await _notificationService.scheduleDelayedNotification(
    id: notificationId,
    title: isLastTask ? 'アルバム完了！' : 'タスク切り替え',
    body: isLastTask
        ? '全てのタスクが完了しました。'
        : '「${nextTask.title}」を開始します',
    delay: Duration(seconds: totalDelay),
    payload: payload,
    withActions: false,
  );
  
  // 再帰的に次のタスクもスケジュール
  if (!isLastTask) {
    _scheduleNextTaskAutoPlayNotifications(nextTaskIndex + 1, totalDelay);
  }
}

// 🆕 自動再生セッションデータを永続保存
Future<void> _saveAutoPlaySessionData() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    
    if (_autoPlaySessionStartTime != null) {
      await prefs.setString('autoplay_start_time', _autoPlaySessionStartTime!.toIso8601String());
      await prefs.setInt('autoplay_current_task_index', _currentTaskIndex);
      await prefs.setStringList('autoplay_task_durations', _taskDurations.map((d) => d.toString()).toList());
      await prefs.setString('autoplay_album_name', _isPlayingSingleAlbum && _playingSingleAlbum != null 
          ? _playingSingleAlbum!.albumName 
          : _currentIdealSelf);
      await prefs.setBool('autoplay_is_single_album', _isPlayingSingleAlbum);
      await prefs.setBool('autoplay_session_active', true);
      
      print('自動再生セッションデータ保存完了');
    }
  } catch (e) {
    print('自動再生セッションデータ保存エラー: $e');
  }
}



// 🆕 時刻ベースの状態計算
Map<String, dynamic> _calculateCurrentStateFromTime(DateTime startTime, List<int> taskDurations, int initialTaskIndex) {
  final elapsedSeconds = DateTime.now().difference(startTime).inSeconds;
  
  // 初期タスクまでの累積時間を計算
  int cumulativeSeconds = 0;
  for (int i = (_isPlayingSingleAlbum ? 0 : -1); i < initialTaskIndex; i++) {
    if (i >= 0 && i < taskDurations.length) {
      cumulativeSeconds += taskDurations[i];
    }
  }
  
  // 初期タスクの進行時間も加算
  cumulativeSeconds += _elapsedSeconds;
  
  // 現在いるべきタスクを特定
  int currentTaskIndex = _isPlayingSingleAlbum ? 0 : -1;
  int currentElapsedInTask = 0;
  int totalElapsed = cumulativeSeconds + (elapsedSeconds - _elapsedSeconds);
  
  int tempCumulative = 0;
  for (int i = (_isPlayingSingleAlbum ? 0 : -1); i < taskDurations.length; i++) {
    final taskDuration = i == -1 ? 0 : taskDurations[i];
    
    if (totalElapsed <= tempCumulative + taskDuration) {
      currentTaskIndex = i;
      currentElapsedInTask = totalElapsed - tempCumulative;
      break;
    }
    
    tempCumulative += taskDuration;
  }
  
  // 全タスク完了チェック
  final totalDuration = taskDurations.fold(0, (sum, duration) => sum + duration);
  final isCompleted = totalElapsed >= totalDuration;
  
  return {
    'taskIndex': isCompleted ? taskDurations.length - 1 : currentTaskIndex,
    'elapsedSeconds': isCompleted ? taskDurations.last : currentElapsedInTask.clamp(0, currentTaskIndex >= 0 && currentTaskIndex < taskDurations.length ? taskDurations[currentTaskIndex] : 0),
    'progress': isCompleted ? 1.0 : (currentTaskIndex >= 0 && currentTaskIndex < taskDurations.length && taskDurations[currentTaskIndex] > 0 
        ? currentElapsedInTask / taskDurations[currentTaskIndex] 
        : 0.0),
    'isCompleted': isCompleted,
    'isPlaying': !isCompleted,
  };
}



Future<void> _cancelBackgroundTaskCompletion() async {
  if (_isAutoPlayEnabled) {
    // 自動再生の全通知をキャンセル
    for (int i = 0; i < _playingTasks.length; i++) {
      await _notificationService.cancelNotification(
        AutoPlayNotificationSystem.autoPlayTaskId(i)
      );
    }
    print('✅ 自動再生通知をすべてキャンセル');
  } else {
    // 通常モードの現在のタスク通知をキャンセル
    await _notificationService.cancelNotification(
      AutoPlayNotificationSystem.normalTaskId(_currentTaskIndex)
    );
    print('✅ 通常モード通知をキャンセル');
  }
}


// _scheduleCurrentTaskCompletion メソッド内を修正
Future<void> _scheduleCurrentTaskCompletion() async {
  if (_currentTaskIndex >= 0 && _currentTaskIndex < _playingTasks.length) {
    final currentTask = _playingTasks[_currentTaskIndex];
    final remainingSeconds = (currentTask.duration * 60) - _elapsedSeconds;
    
    if (remainingSeconds > 0) {
      // ペイロードを直接作成（メソッド呼び出しを避ける）
      final payload = 'type=background_task_completed'
          '&taskId=${currentTask.id}'
          '&taskTitle=${currentTask.title}'
          '&albumName=${_isPlayingSingleAlbum && _playingSingleAlbum != null ? _playingSingleAlbum!.albumName : _currentIdealSelf}'
          '&albumType=${_isPlayingSingleAlbum ? 'single' : 'life_dream'}'
          '&albumId=${_isPlayingSingleAlbum && _playingSingleAlbum != null ? _playingSingleAlbum!.id : ''}'
          '&elapsedSeconds=${currentTask.duration * 60}'
          '&notificationType=background_task_completed';
      
      await _notificationService.scheduleDelayedNotification(
        id: 9900 + _currentTaskIndex,
        title: 'タスク完了！',
        body: '「${currentTask.title}」の時間が終了しました。このタスクはできましたか？',
        delay: Duration(seconds: remainingSeconds),
        payload: payload,
        withActions: true,
      );
      
      print('🔧 通常モード: バックグラウンド完了通知をスケジュール: ${remainingSeconds}秒後');
    }
  }
}

Future<void> _scheduleAutoPlayNotifications() async {
  print('🎯 自動再生専用通知システムを起動');
  
  // 全タスクのIDリストを作成
  final allTaskIds = _playingTasks.map((t) => t.id).toList();
  
  // セッション情報を作成
  final sessionInfo = AutoPlayNotificationManager.createAutoPlaySession(
    taskIds: allTaskIds,
    albumName: _isPlayingSingleAlbum && _playingSingleAlbum != null 
        ? _playingSingleAlbum!.albumName 
        : _currentIdealSelf,
    isSingleAlbum: _isPlayingSingleAlbum,
    startTime: DateTime.now(),
  );
  
  // 最後のタスクのみ通知をスケジュール（シンプルに）
  int totalSeconds = 0;
  
  // 残り時間を計算
  for (int i = _currentTaskIndex; i < _playingTasks.length; i++) {
    if (i == _currentTaskIndex) {
      totalSeconds = (_playingTasks[i].duration * 60) - _elapsedSeconds;
    } else {
      totalSeconds += (_playingTasks[i].duration * 60);
    }
  }
  
  // 最終完了通知のみスケジュール
  await _notificationService.scheduleDelayedNotification(
    id: 99999, // 固定ID
    title: '🎉 すべてのタスク完了！',
    body: 'お疲れ様でした！タスクの達成状況を記録してください。',
    delay: Duration(seconds: totalSeconds),
    payload: 'notification_type=AUTO_PLAY_FINAL&$sessionInfo',
    withActions: false,
  );
  
  print('✅ 自動再生最終通知をスケジュール: ${totalSeconds}秒後');
}

// 通常モード用の通知（既存のものを簡略化）
Future<void> _scheduleNormalTaskNotification() async {
  if (_currentTaskIndex < 0 || _currentTaskIndex >= _playingTasks.length) return;
  
  final currentTask = _playingTasks[_currentTaskIndex];
  final remainingSeconds = (currentTask.duration * 60) - _elapsedSeconds;
  
  await _notificationService.scheduleDelayedNotification(
    id: 50000 + _currentTaskIndex,
    title: 'タスク完了',
    body: '「${currentTask.title}」の時間が終了しました',
    delay: Duration(seconds: remainingSeconds),
    payload: 'notification_type=NORMAL&taskIndex=$_currentTaskIndex',
    withActions: true,
  );
}

// main_wrapper.dart - 自動再生専用通知システム修正版

Future<void> _scheduleAllRemainingTasksCompletion() async {
  print('🔧 自動再生モード: 全タスクの通知をスケジュール');
  
  // 既に完了したタスクのIDリスト
  List<String> completedTaskIds = [];
  for (int i = 0; i < _currentTaskIndex; i++) {
    if (i >= 0 && i < _playingTasks.length) {
      completedTaskIds.add(_playingTasks[i].id);
    }
  }
  
  int cumulativeSeconds = 0;
  
  for (int i = _currentTaskIndex; i < _playingTasks.length; i++) {
    final task = _playingTasks[i];
    
    // 時間計算
    if (i == _currentTaskIndex) {
      cumulativeSeconds = (task.duration * 60) - _elapsedSeconds;
    } else {
      cumulativeSeconds += (task.duration * 60);
    }
    
    // このタスクまでの完了リスト
    List<String> taskIdsAtThisPoint = List.from(completedTaskIds);
    for (int j = _currentTaskIndex; j <= i; j++) {
      if (j < _playingTasks.length) {
        taskIdsAtThisPoint.add(_playingTasks[j].id);
      }
    }
    
    final isLastTask = (i == _playingTasks.length - 1);
    final notificationId = NotificationIds.autoPlayTask(i);
    
    // ペイロード作成
    final payload = [
      'type=${isLastTask ? "album_completed" : "task_completed"}',
      'taskIndex=$i',
      'totalTasks=${_playingTasks.length}',
      'completedTasks=${taskIdsAtThisPoint.join(",")}',
      'albumName=${_isPlayingSingleAlbum && _playingSingleAlbum != null ? _playingSingleAlbum!.albumName : _currentIdealSelf}',
      'isLastTask=$isLastTask',
      'timestamp=${DateTime.now().millisecondsSinceEpoch}',
    ].join('&');

    print('📝 通知ペイロード: $payload');
    
    await _notificationService.scheduleDelayedNotification(
      id: notificationId,
      title: isLastTask ? 'アルバム完了！' : '「${task.title}」完了',
      body: isLastTask 
          ? 'すべてのタスクが完了しました'
          : '次のタスクに進みます',
      delay: Duration(seconds: cumulativeSeconds),
      payload: payload,
      withActions: isLastTask,
    );
    
    print('🔧 通知スケジュール: ID=$notificationId, ${cumulativeSeconds}秒後');
  }
}

// 🆕 新しいメソッド: アルバム完了専用通知のスケジュール
Future<void> _scheduleAlbumCompletionNotification(int delaySeconds, int finalTaskIndex) async {
  try {
    // 完了済みタスクのIDリストを作成
    List<String> allCompletedTaskIds = [];
    for (int i = 0; i < _playingTasks.length; i++) {
      allCompletedTaskIds.add(_playingTasks[i].id);
    }
    
    // 🔧 修正: 専用の「アルバム完了」ペイロードを作成
    final payload = _createAlbumCompletionPayload(
      finalTaskIndex: finalTaskIndex,
      completedTaskIds: allCompletedTaskIds,
      totalElapsedSeconds: _playingTasks.fold(0, (sum, task) => sum + (task.duration * 60)),
    );
    
    await _notificationService.scheduleDelayedNotification(
      id: 8900, // 専用のID
      title: '🎉 アルバム完了！',
      body: '「${_isPlayingSingleAlbum && _playingSingleAlbum != null ? _playingSingleAlbum!.albumName : _currentIdealSelf}」のすべてのタスクが完了しました。\n\nお疲れ様でした！結果を確認しましょう。',
      delay: Duration(seconds: delaySeconds),
      payload: payload,
      withActions: true,
    );
    
    print('🔧 アルバム完了通知をスケジュール: ${delaySeconds}秒後');
  } catch (e) {
    print('❌ アルバム完了通知スケジュールエラー: $e');
  }
}

// 🆕 新しいメソッド: タスク進行通知のスケジュール
Future<void> _scheduleTaskProgressNotification(int delaySeconds, TaskItem task, int taskIndex) async {
  try {
    // 現在のタスクまでの完了済みIDリストを作成
    List<String> completedTaskIds = [];
    for (int i = 0; i <= taskIndex; i++) {
      if (i < _playingTasks.length) {
        completedTaskIds.add(_playingTasks[i].id);
      }
    }
    
    // 🔧 修正: 専用の「進行通知」ペイロードを作成
    final payload = _createTaskProgressPayload(
      currentTaskIndex: taskIndex,
      completedTaskIds: completedTaskIds,
      totalElapsedSeconds: completedTaskIds.length * 60 * 3, // 簡易計算
    );
    
    await _notificationService.scheduleDelayedNotification(
      id: 8800 + taskIndex, // 進行通知専用のID範囲
      title: '🔄 次のタスクを開始',
      body: '「${task.title}」が完了しました。\n次のタスクに自動で進みます。',
      delay: Duration(seconds: delaySeconds),
      payload: payload,
      withActions: false,
    );
    
    print('🔧 タスク進行通知をスケジュール: タスク${taskIndex + 1}「${task.title}」- ${delaySeconds}秒後');
  } catch (e) {
    print('❌ タスク進行通知スケジュールエラー: $e');
  }
}

// 🆕 新しいメソッド: アルバム完了専用ペイロード作成
String _createAlbumCompletionPayload({
  required int finalTaskIndex,
  required List<String> completedTaskIds,
  required int totalElapsedSeconds,
}) {
  return 'type=auto_play_album_completed'
      '&finalTaskIndex=$finalTaskIndex'
      '&totalTasks=${_playingTasks.length}'
      '&completedTaskIds=${completedTaskIds.join(',')}'
      '&albumName=${_isPlayingSingleAlbum && _playingSingleAlbum != null ? _playingSingleAlbum!.albumName : _currentIdealSelf}'
      '&albumType=${_isPlayingSingleAlbum ? 'single' : 'life_dream'}'
      '&albumId=${_isPlayingSingleAlbum && _playingSingleAlbum != null ? _playingSingleAlbum!.id : ''}'
      '&totalElapsedSeconds=$totalElapsedSeconds'
      '&isAutoPlayCompleted=true'
      '&notificationType=auto_play_album_completed';
}

// 🆕 新しいメソッド: タスク進行専用ペイロード作成
String _createTaskProgressPayload({
  required int currentTaskIndex,
  required List<String> completedTaskIds,
  required int totalElapsedSeconds,
}) {
  return 'type=auto_play_task_progress'
      '&currentTaskIndex=$currentTaskIndex'
      '&totalTasks=${_playingTasks.length}'
      '&completedTaskIds=${completedTaskIds.join(',')}'
      '&albumName=${_isPlayingSingleAlbum && _playingSingleAlbum != null ? _playingSingleAlbum!.albumName : _currentIdealSelf}'
      '&albumType=${_isPlayingSingleAlbum ? 'single' : 'life_dream'}'
      '&albumId=${_isPlayingSingleAlbum && _playingSingleAlbum != null ? _playingSingleAlbum!.id : ''}'
      '&totalElapsedSeconds=$totalElapsedSeconds'
      '&isAutoPlayInProgress=true'
      '&notificationType=auto_play_task_progress';
}


// 🆕 新しいメソッド: 自動再生アルバム完了通知の処理
Future<void> _handleAutoPlayAlbumCompletedNotification(Map<String, String> payloadData) async {
  try {
    print('🎉 自動再生アルバム完了通知処理開始');
    
    _isNotificationReturning = true;
    
    // ペイロードから状態を復元
    final finalTaskIndex = int.tryParse(payloadData['finalTaskIndex'] ?? '') ?? _playingTasks.length - 1;
    final completedTaskIdsStr = payloadData['completedTaskIds'] ?? '';
    final completedTaskIds = completedTaskIdsStr.split(',').where((id) => id.isNotEmpty).toList();
    final totalElapsedSeconds = int.tryParse(payloadData['totalElapsedSeconds'] ?? '0') ?? 0;
    
    // 🔧 修正: すべてのタスクを完了済みとして記録
    for (final taskId in completedTaskIds) {
      final taskIndex = _playingTasks.indexWhere((t) => t.id == taskId);
      if (taskIndex >= 0) {
        final task = _playingTasks[taskIndex];
        
        // 重複記録を防ぐため、今日の完了回数をチェック
        final currentCount = _todayTaskCompletions[task.id] ?? 0;
        if (currentCount == 0) {
          await _taskCompletionService.recordTaskCompletion(
            taskId: task.id,
            taskTitle: task.title,
            wasSuccessful: true,
            elapsedSeconds: task.duration * 60,
            albumType: _isPlayingSingleAlbum ? 'single' : 'life_dream',
            albumName: _isPlayingSingleAlbum && _playingSingleAlbum != null 
                ? _playingSingleAlbum!.albumName 
                : _currentIdealSelf,
            albumId: _isPlayingSingleAlbum && _playingSingleAlbum != null 
                ? _playingSingleAlbum!.id 
                : null,
          );
          
          setState(() {
            _todayTaskCompletions[task.id] = 1;
          });
        }
      }
    }
    
    // 🔧 修正: アプリを「アルバム完了」状態に設定
    final lastPageIndex = _isPlayingSingleAlbum ? finalTaskIndex : finalTaskIndex + 1;
    
    setState(() {
      _isPlaying = false;
      _isAutoPlayEnabled = false;
      _currentTaskIndex = finalTaskIndex;
      _forcePlayerPageIndex = lastPageIndex;
      _elapsedSeconds = _playingTasks[finalTaskIndex].duration * 60;
      _currentProgress = 1.0;
      _isPlayerScreenVisible = true;
    });
    
    // PlayerScreenに完了状態を通知
    _onPlayerStateChanged(
      currentTaskIndex: finalTaskIndex,
      isPlaying: false,
      progress: 1.0,
      elapsedSeconds: _playingTasks[finalTaskIndex].duration * 60,
      isAutoPlayEnabled: false,
      forcePageChange: lastPageIndex,
    );
    
    await _loadUserData();
    
    // 🎉 アルバム完了申告ダイアログを表示
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        _showAlbumCompletionDialog();
      }
    });
    
    print('✅ 自動再生アルバム完了処理完了 - 全${completedTaskIds.length}タスク完了');
    
  } catch (e) {
    print('❌ 自動再生アルバム完了処理エラー: $e');
  }
}

// 🆕 新しいメソッド: 自動再生タスク進行通知の処理
Future<void> _handleAutoPlayTaskProgressNotification(Map<String, String> payloadData) async {
  try {
    print('🔄 自動再生タスク進行通知処理開始');
    
    _isNotificationReturning = true;
    
    // ペイロードから状態を復元
    final currentTaskIndex = int.tryParse(payloadData['currentTaskIndex'] ?? '') ?? 0;
    final completedTaskIdsStr = payloadData['completedTaskIds'] ?? '';
    final completedTaskIds = completedTaskIdsStr.split(',').where((id) => id.isNotEmpty).toList();
    
    // 完了済みタスクを記録
    for (final taskId in completedTaskIds) {
      final taskIndex = _playingTasks.indexWhere((t) => t.id == taskId);
      if (taskIndex >= 0 && taskIndex < currentTaskIndex) {
        final task = _playingTasks[taskIndex];
        
        final currentCount = _todayTaskCompletions[task.id] ?? 0;
        if (currentCount == 0) {
          await _taskCompletionService.recordTaskCompletion(
            taskId: task.id,
            taskTitle: task.title,
            wasSuccessful: true,
            elapsedSeconds: task.duration * 60,
            albumType: _isPlayingSingleAlbum ? 'single' : 'life_dream',
            albumName: _isPlayingSingleAlbum && _playingSingleAlbum != null 
                ? _playingSingleAlbum!.albumName 
                : _currentIdealSelf,
            albumId: _isPlayingSingleAlbum && _playingSingleAlbum != null 
                ? _playingSingleAlbum!.id 
                : null,
          );
          
          setState(() {
            _todayTaskCompletions[task.id] = 1;
          });
        }
      }
    }
    
    // 現在のタスクの状態に設定（自動再生継続）
    final pageIndex = _isPlayingSingleAlbum ? currentTaskIndex : currentTaskIndex + 1;
    
    setState(() {
      _currentTaskIndex = currentTaskIndex;
      _forcePlayerPageIndex = pageIndex;
      _elapsedSeconds = 0;
      _currentProgress = 0.0;
      _isPlaying = true;
      _isAutoPlayEnabled = true;
      _isPlayerScreenVisible = true;
    });
    
    _startNewTask();
    _startProgressTimer();
    
    _onPlayerStateChanged(
      currentTaskIndex: currentTaskIndex,
      isPlaying: true,
      progress: 0.0,
      elapsedSeconds: 0,
      isAutoPlayEnabled: true,
      forcePageChange: pageIndex,
    );
    
    await _loadUserData();
    
    print('✅ 自動再生タスク進行処理完了 - タスク${currentTaskIndex + 1}を継続');
    
  } catch (e) {
    print('❌ 自動再生タスク進行処理エラー: $e');
  }
}


Future<void> _scheduleAutoPlayProgressNotification(int delaySeconds, TaskItem task, int taskIndex) async {
  // ペイロードを直接作成
  final payload = 'type=background_auto_play_progress'
      '&taskId=${task.id}'
      '&taskTitle=${task.title}'
      '&albumName=${_isPlayingSingleAlbum && _playingSingleAlbum != null ? _playingSingleAlbum!.albumName : _currentIdealSelf}'
      '&albumType=${_isPlayingSingleAlbum ? 'single' : 'life_dream'}'
      '&albumId=${_isPlayingSingleAlbum && _playingSingleAlbum != null ? _playingSingleAlbum!.id : ''}'
      '&elapsedSeconds=${task.duration * 60}'
      '&notificationType=background_auto_play_progress';
  
  await _notificationService.scheduleDelayedNotification(
    id: 9900 + taskIndex,
    title: 'タスク完了（自動再生）',
    body: '「${task.title}」が完了しました。次のタスクに進みます。',
    delay: Duration(seconds: delaySeconds),
    payload: payload,
    withActions: false,
  );
  
  print('🔧 自動再生進行通知をスケジュール: タスク${taskIndex + 1}「${task.title}」- ${delaySeconds}秒後');
}



  // 🔧 追加: AudioServiceの安全な初期化メソッド
Future<void> _initializeAudioService() async {
  try {
    await _audioService.initialize();
    final audioStatus = _audioService.getAudioStatus();
    print('🔊 AudioService状態: $audioStatus');
    
    if (!audioStatus['hasAudioFiles']) {
      print('⚠️ 音声ファイルが見つかりません。音声なしで動作します。');
      print('📁 音声ファイルを追加する場合：');
      print('   1. assets/sounds/ フォルダを作成');
      print('   2. 以下のファイルを配置：');
      print('      - task_completed.mp3');
      print('      - achievement.mp3');
      print('      - notification.mp3');
      print('   3. pubspec.yaml にアセットを追加');
    }
  } catch (e) {
    print('❌ AudioService初期化で非致命的エラー: $e');
    print('🔊 音声なしで動作を継続します');
  }
}



  Future<void> _loadTodayCompletions() async {
    try {
      final completions = <String, int>{};
      for (final task in _currentTasks) {
        final count = await _taskCompletionService.getTodayTaskSuccesses(task.id);
        completions[task.id] = count;
      }
      if (mounted) {
        setState(() {
          _todayTaskCompletions = completions;
        });
      }
    } catch (e) {
      print('❌ 今日の完了回数読み込みエラー: $e');
    }
  }

  Future<void> _checkFirstLaunchAndInitialize() async {
  setState(() {
    _isCheckingFirstLaunch = true;
  });

  try {
    final minDisplayTime = Future.delayed(const Duration(seconds: 2));
    
    final isFirstLaunch = await _dataService.isFirstLaunch();
    final isOnboardingCompleted = await _dataService.isOnboardingCompleted();
    
    await Future.delayed(const Duration(milliseconds: 800));
    await Future.delayed(const Duration(milliseconds: 500));
    
    await _loadUserData();
    
    // 🆕 自動再生セッション復元チェックを追加
    await _checkAndRestoreAutoPlaySession();
    
    await minDisplayTime;
    
    if (isFirstLaunch || !isOnboardingCompleted) {
      setState(() {
        _shouldShowOnboarding = true;
        _isCheckingFirstLaunch = false;
      });
    } else {
      setState(() {
        _shouldShowOnboarding = false;
        _isCheckingFirstLaunch = false;
      });
    }
  } catch (e) {
    await Future.delayed(const Duration(seconds: 1));
    await _loadUserData();
    setState(() {
      _shouldShowOnboarding = false;
      _isCheckingFirstLaunch = false;
    });
  }
}

  Future<void> _onOnboardingCompleted() async {
    await _loadUserData();
    setState(() {
      _shouldShowOnboarding = false;
    });
  }

  void _registerWithController() {
    mainWrapperController.register(
      showFullPlayer: _showFullPlayer,
      togglePlayPause: _togglePlayPause,
      nextTask: _nextTask,
      previousTask: _previousTask,
      hasActiveTasks: () => _playingTasks.isNotEmpty,
      isPlayerScreenVisible: () => _isPlayerScreenVisible || _isAlbumDetailVisible || _isSettingsVisible,
      getMiniPlayerHeight: _getMiniPlayerHeight,
    );
  }

  void _unregisterFromController() {
    mainWrapperController.unregister();
  }

  double _getMiniPlayerHeight() {
    if (_playingTasks.isNotEmpty && !(_isPlayerScreenVisible || _isAlbumDetailVisible || _isSettingsVisible)) {
      return 72 + 3;
    }
    return 0;
  }

  Future<void> _loadUserData() async {
  try {
    final data = await _dataService.loadUserData();
    setState(() {
      _currentIdealSelf = data['idealSelf'] ?? '理想の自分';
      _currentArtistName = data['artistName'] ?? 'You';
      _currentAlbumImagePath = data['albumImagePath'] ?? '';
      
      final savedImageBytes = _dataService.getSavedImageBytes();
      if (savedImageBytes != null) {
        _imageBytes = savedImageBytes;
      }
      
      if (data['tasks'] != null) {
        if (data['tasks'] is List<TaskItem>) {
          _currentTasks = List<TaskItem>.from(data['tasks']);
        } else if (data['tasks'] is List) {
          _currentTasks = (data['tasks'] as List)
              .map((taskJson) => TaskItem.fromJson(taskJson))
              .take(4)
              .toList();
        }
      }
      
      if (_currentTasks.isEmpty) {
        _currentTasks = _dataService.getDefaultTasks();
      }
      
      // 🔧 修正：シングルアルバム再生中は_playingTasksを上書きしない
      if (!_isPlayingSingleAlbum) {
        _playingTasks = List.from(_currentTasks);
      }
    });
    
    await _loadTodayCompletions();
  } catch (e) {
    setState(() {
      _currentTasks = _dataService.getDefaultTasks();
    });
  }
}

  void _onPlayerStateChanged({
  int? currentTaskIndex,
  bool? isPlaying,
  double? progress,
  int? elapsedSeconds,
  bool? isAutoPlayEnabled,
  int? forcePageChange, 
}) {
  print('🔧 MainWrapper: PlayerScreenから状態変更受信');
  
  // 🔧 修正: 状態が変更された場合は常に setState を呼ぶ
  bool shouldUpdate = false;
  
  if (currentTaskIndex != null && _currentTaskIndex != currentTaskIndex) {
    _currentTaskIndex = currentTaskIndex;
    shouldUpdate = true;
    print('🔧 タスクインデックス更新: $_currentTaskIndex');
  }
  
  if (isPlaying != null && _isPlaying != isPlaying) {
    if (!_isPlaying && isPlaying) {
      _isPlaying = true;
      // バックグラウンド復帰時は _startNewTask() をスキップ
      if (_taskStartTime == null) {
        _startNewTask();
      }
      _startProgressTimer();
    } else if (_isPlaying && !isPlaying) {
      _isPlaying = false;
      _pauseCurrentTask();
      _stopProgressTimer();
    }
    shouldUpdate = true;
  }
  
  if (progress != null && _currentProgress != progress) {
    _currentProgress = progress;
    shouldUpdate = true;
  }
  
  if (elapsedSeconds != null && _elapsedSeconds != elapsedSeconds) {
    _elapsedSeconds = elapsedSeconds;
    shouldUpdate = true;
  }
  
  if (isAutoPlayEnabled != null && _isAutoPlayEnabled != isAutoPlayEnabled) {
    _isAutoPlayEnabled = isAutoPlayEnabled;
    print('🔄 MainWrapper: 自動再生状態変更 → $_isAutoPlayEnabled');
    
    if (!_isAutoPlayEnabled) {
      _isAutoPlayInProgress = false;
    }
    shouldUpdate = true;
  }
  
  // 🔧 修正: いずれかの状態が変更された場合に setState を呼ぶ
  if (shouldUpdate) {
    setState(() {
      // 状態はすでに更新済み
    });
  }
}

  void _startNewTask() {
    _taskStartTime = DateTime.now();
    _pauseStartTime = null;
    _totalPausedSeconds = 0;
    _elapsedSeconds = 0;
    _currentProgress = 0.0;
    
    if (_currentTaskIndex == -1) {
      print('🔧 新しいタスクを開始: 理想像ページ');
      return;
    }
    
    if (_playingTasks.isNotEmpty && _currentTaskIndex >= 0 && _currentTaskIndex < _playingTasks.length) {
      print('🔧 新しいタスクを開始: ${_playingTasks[_currentTaskIndex].title}');
    } else {
      print('🔧 新しいタスクを開始: インデックス範囲外 (${_currentTaskIndex})');
    }
  }

  void _pauseCurrentTask() {
    if (_taskStartTime != null && _pauseStartTime == null) {
      _pauseStartTime = DateTime.now();
    }
  }

  void _updateProgress() {
  if (_currentTaskIndex == -1) {
    _currentProgress = 0.0;
    return;
  }
  
  if (_playingTasks.isNotEmpty && _currentTaskIndex >= 0 && _currentTaskIndex < _playingTasks.length) {
    final currentTask = _playingTasks[_currentTaskIndex];
    final totalSeconds = currentTask.duration * 60;
    
    if (totalSeconds > 0) {
      final progress = _elapsedSeconds / totalSeconds;
      // 🔧 修正: 99%で制限して意図しない完了を防ぐ
      _currentProgress = progress.clamp(0.0, 0.99);
    } else {
      _currentProgress = 0.0;
    }
  }
}

  void _showFullPlayer() {
  _stopProgressTimer();
  
  if (!_isPlayingSingleAlbum) {
    setState(() {
      _playingTasks = List.from(_currentTasks);
      _isPlayingSingleAlbum = false;
      _playingSingleAlbum = null;
      _startNewTask();
      _isPlayerScreenVisible = true;
      _isDraggingPlayer = false;
    });
  } else {
    setState(() {
      _isPlayerScreenVisible = true;
      _isDraggingPlayer = false;
    });
  }
  
  // 🔧 修正：AnimationController を 0.0 に設定
  _playerDragController.value = 0.0;
}

  void _showFullPlayerWithTask(int taskIndex) {
  _stopProgressTimer();
  
  // 🔧 修正：最新のタスクデータを読み込み直す
  _loadUserData().then((_) {
    setState(() {
      _playingTasks = List.from(_currentTasks);
      _isPlayingSingleAlbum = false;
      _playingSingleAlbum = null;
      _currentTaskIndex = taskIndex == -1 ? 0 : taskIndex;
      _isPlaying = true;
      _startNewTask();
      _isPlayerScreenVisible = true;
      _isDraggingPlayer = false;
    });
    
    _playerDragController.value = 0.0;
  });
}
  void _showSingleAlbumPlayer(SingleAlbum album, {int taskIndex = 0}) async {
  _stopProgressTimer();
  
  print('🎵 シングルアルバムプレイヤー開始: ${album.albumName}, タスクインデックス: $taskIndex');
  
  final latestAlbum = await _dataService.getSingleAlbum(album.id);
  final albumToPlay = latestAlbum ?? album;
  
  // 🔧 修正: タスク完了回数を先に読み込む
  await _loadSingleAlbumTaskCompletions(albumToPlay);
  
  setState(() {
    _playingTasks = List.from(albumToPlay.tasks);
    _isPlayingSingleAlbum = true;
    _playingSingleAlbum = albumToPlay;
    _currentTaskIndex = taskIndex;
    _isPlaying = false;
    _startNewTask();
    
    _isPlayerScreenVisible = true;
    
    _isAnimating = false;
    _isDraggingPlayer = false;
  });
  
  _playerDragController.value = 0.0;
  
  print('🎵 PlayerScreen表示完了: isVisible=$_isPlayerScreenVisible, isPlaying=$_isPlaying');
  print('📊 読み込まれたタスクカウント: ${_todayTaskCompletions.length}件');
}

// 🆕 シングルアルバムのタスク完了回数を読み込み
Future<void> _loadSingleAlbumTaskCompletions(SingleAlbum album) async {
  try {
    // 🔧 修正: 既存のカウントを保持
    final existingCounts = Map<String, int>.from(_todayTaskCompletions);
    
    for (final task in album.tasks) {
      final count = await _taskCompletionService.getTodayTaskSuccesses(task.id);
      existingCounts[task.id] = count;
      print('📊 タスクカウント読み込み: ${task.title} (ID: ${task.id}) = $count回');
    }
    
    setState(() {
      _todayTaskCompletions = existingCounts;
    });
    
    print('✅ シングルアルバムのタスク完了回数読み込み完了: ${album.albumName}');
    print('📊 総カウント数: ${_todayTaskCompletions.length}件');
  } catch (e) {
    print('❌ シングルアルバムのタスク完了回数読み込みエラー: $e');
  }
}


  void _hideFullPlayer() {

  print('🔍 _hideFullPlayer呼び出し');
  print('  - _currentTaskIndex: $_currentTaskIndex');
  print('  - _isPlayingSingleAlbum: $_isPlayingSingleAlbum');
  print('  - _playingTasks.length: ${_playingTasks.length}');
  if (_currentTaskIndex >= 0 && _currentTaskIndex < _playingTasks.length) {
    print('  - 現在のタスク: ${_playingTasks[_currentTaskIndex].title}');
  }
  _closePlayerWithAnimation();
  
  print('🔧 MainWrapper: プレイヤーを閉じました - タイマー継続: $_isPlaying');
  
  // 🔧 追加：アルバム詳細が残っていればそれを表示
  if (_currentSingleAlbum != null) {
    setState(() {
      _isAlbumDetailVisible = true;
    });
    print('🔙 アルバム詳細画面に戻ります: ${_currentSingleAlbum!.albumName}');
  }
}

  void _showAlbumDetail() {
    setState(() {
      _currentSingleAlbum = null;
      _isAlbumDetailVisible = true;
    });
  }

  void _showSingleAlbumDetail(SingleAlbum album) {
    setState(() {
      _currentSingleAlbum = album;
      _isAlbumDetailVisible = true;
    });
    
    print('🎵 アルバム詳細表示: ${album.albumName} (表示用), 再生中: ${_playingSingleAlbum?.albumName}');
  }

  void _hideAlbumDetail() {
    setState(() {
      _currentSingleAlbum = null;
      _isAlbumDetailVisible = false;
    });
    
    print('🎵 アルバム詳細を閉じました');
    print('🎵 - 表示用アルバムリセット: $_currentSingleAlbum');
    print('🎵 - 再生中アルバム保持: ${_playingSingleAlbum?.albumName}');
  }

  void _showSettings() {
    setState(() {
      _isSettingsVisible = true;
    });
  }

// 🔧 修正：シングルアルバムの設定画面を表示
void _showSingleAlbumSettings(SingleAlbum album) {
  setState(() {
    _currentSingleAlbum = album;
    _isSettingsVisible = true;
  });
  
  print('📝 シングルアルバム設定画面を表示: ${album.albumName}');
}

// 🆕 新規追加メソッド：アルバムインスタンスを直接受け取る設定画面表示
void _showSingleAlbumSettingsWithAlbum(SingleAlbum album) {
  setState(() {
    _currentSingleAlbum = album;  // アルバムを設定
    _isSettingsVisible = true;
  });
  
  print('📝 シングルアルバム設定画面を表示: ${album.albumName}');
}

// 🆕 新規追加メソッド：シングルアルバム設定画面のWidget構築
Widget _buildSingleAlbumSettingsScreen(SingleAlbum album) {
  return SettingsScreen(
    idealSelf: album.albumName,
    artistName: _currentArtistName,
    todayLyrics: '',
    albumImage: null,
    albumCoverImage: album.albumCoverImage,
    tasks: album.tasks,
    isEditingLifeDream: false,
    albumId: album.id,
    onClose: () {  // 🔧 修正：クローズ時の処理を改善
      setState(() {
        _isSettingsVisible = false;
        
        // 🔧 修正：PlayerScreenから開いた場合のみPlayerScreenに戻る
        if (_isPlayingSingleAlbum && _playingSingleAlbum?.id == album.id && !_isAlbumDetailVisible) {
          _isPlayerScreenVisible = true;
        } else {
          // 🔧 修正：アルバム詳細から開いた場合は必ずアルバム詳細に戻る
          _currentSingleAlbum = album;  // アルバム情報を保持
          _isAlbumDetailVisible = true;
        }
      });
    },
    onSave: (result) async {
      try {
        final updatedAlbum = SingleAlbum(
          id: album.id,
          albumName: result['idealSelf'] ?? album.albumName,
          albumCoverImage: result['hasImageChanged'] == true 
              ? result['imageBytes'] 
              : album.albumCoverImage,
          tasks: List<TaskItem>.from(result['tasks'] ?? album.tasks),
          createdAt: album.createdAt,
        );
        
        await _dataService.saveSingleAlbum(updatedAlbum);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '「${updatedAlbum.albumName}」を更新しました！',
                      style: const TextStyle(fontFamily: 'Hiragino Sans'),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF1DB954),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }
        
        // 🔧 修正：保存後の遷移処理を改善
        setState(() {
          _isSettingsVisible = false;
          
          // 再生中のアルバムを更新していた場合
          if (_isPlayingSingleAlbum && _playingSingleAlbum?.id == album.id) {
            _playingSingleAlbum = updatedAlbum;
            _playingTasks = List.from(updatedAlbum.tasks);
            
            // 🔧 修正：アルバム詳細が開かれていた場合の判定
            if (!_isAlbumDetailVisible) {
              _isPlayerScreenVisible = true;  // PlayerScreenに戻る
            } else {
              _currentSingleAlbum = updatedAlbum;  // アルバム情報を更新
              _isAlbumDetailVisible = true;  // アルバム詳細に戻る
            }
          } else {
            // 🔧 修正：アルバム詳細を更新して戻る
            _currentSingleAlbum = updatedAlbum;
            _isAlbumDetailVisible = true;
          }
        });
        
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('アルバムの更新に失敗しました'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    },
    onDelete: () async {
      await _deleteSingleAlbum(album);
    },
  );
}

// 🆕 新規追加メソッド：シングルアルバム削除処理
Future<void> _deleteSingleAlbum(SingleAlbum album) async {
  try {
    await _dataService.deleteSingleAlbum(album.id);
    
    if (_isPlayingSingleAlbum && _playingSingleAlbum?.id == album.id) {
      _stopProgressTimer();
      
      setState(() {
        _isPlaying = false;
        _isAutoPlayEnabled = false;
        _isPlayingSingleAlbum = false;
        _playingSingleAlbum = null;
        _playingTasks = [];
        _currentTaskIndex = 0;
        _elapsedSeconds = 0;
        _currentProgress = 0.0;
      });
      
      print('🗑️ 再生中のアルバムを削除したため再生を停止');
    }
    
    // 🔧 修正：設定画面とアルバム詳細を閉じる
    setState(() {
      _isSettingsVisible = false;
      _isAlbumDetailVisible = false;
      _currentSingleAlbum = null;  // 🔧 追加：ここでクリア
      _selectedPageIndex = 0;  // ホーム画面に戻る
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '「${album.albumName}」を削除しました',
                  style: const TextStyle(fontFamily: 'Hiragino Sans'),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
    
    print('✅ シングルアルバム削除完了: ${album.albumName} (ID: ${album.id})');
    
  } catch (e) {
    print('❌ シングルアルバム削除エラー: $e');
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'アルバムの削除に失敗しました',
                  style: TextStyle(fontFamily: 'Hiragino Sans'),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}


  void _hideSettings() {
  setState(() {
    _isSettingsVisible = false;
  });
}

  void _onSingleAlbumSave(Map<String, dynamic> albumData) async {
  try {
    final album = SingleAlbum(
      id: _dataService.generateAlbumId(),
      albumName: albumData['albumName'],
      albumCoverImage: albumData['albumCoverImage'],
      tasks: List<TaskItem>.from(albumData['tasks']),
      createdAt: DateTime.parse(albumData['createdAt']),
    );
    
    await _dataService.saveSingleAlbum(album);
    
    // 🔧 修正：すぐにホーム画面に反映させるため、ユーザーデータを再読み込み
    await _loadUserData();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.album, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '「${album.albumName}」をリリースしました！',
                  style: const TextStyle(fontFamily: 'Hiragino Sans'),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1DB954),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      
      // 🔧 修正：ホーム画面に戻る
      setState(() {
        _selectedPageIndex = 0;
      });
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('アルバムの保存に失敗しました'),
          backgroundColor: Colors.red,
        ),
      );
    }
    return;
  }
}

  void _onDataUpdated() {
    _loadUserData();
  }

  void _togglePlayPause() {
  setState(() {
    _isPlaying = !_isPlaying;
  });
  
  if (_isPlaying) {
    _startProgressTimer();
  } else {
    _stopProgressTimer();
  }
  
  // 🆕 Live Activity状態変更通知
  _notifyActivityStateChange(isPlaying: _isPlaying);
}

void _startProgressTimer() {
  _stopProgressTimer();

  print('🔧 タイマー開始時の状態: isPlaying=$_isPlaying, taskIndex=$_currentTaskIndex');
  
  // 🔧 修正：_isPlayingのチェックを削除し、強制的にタイマーを開始
  if (_playingTasks.isEmpty) {
    print('🔧 タイマー停止: playingTasksが空');
    return;
  }
  
  if (!_isActivityActive) {
    _isActivityActive = true;
  }
  
  _progressTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
  print('🔧 タイマーコールバック実行: isPlaying=$_isPlaying');
  
  if (_playingTasks.isEmpty) {
    print('🔧 タイマー停止: playingTasksが空');
    timer.cancel();
    return;
  }
  
  setState(() {
    // 🔧 修正：シンプルなインクリメント方式に変更
    _elapsedSeconds++;
    
    if (_currentTaskIndex == -1) {
      _currentProgress = 0.0;
      return;
    }
    
    if (_currentTaskIndex >= 0 && _currentTaskIndex < _playingTasks.length) {
      final currentTask = _playingTasks[_currentTaskIndex];
      final totalSeconds = currentTask.duration * 60;
      final progress = totalSeconds > 0 ? _elapsedSeconds / totalSeconds : 0.0;
      _currentProgress = progress.clamp(0.0, 1.0);
      
      _onPlayerStateChanged(
        progress: _currentProgress,
        elapsedSeconds: _elapsedSeconds,
      );
      print('🔧 MainWrapper→PlayerScreen通知: progress=$_currentProgress, elapsed=$_elapsedSeconds');
      
      if (_isPlayerScreenVisible && mounted) {
        WidgetsBinding.instance.ensureVisualUpdate();
      }
      
      if (_currentProgress >= 1.0 && !_isAutoPlayInProgress) {
  print('タスク完了検知: ${currentTask.title}');
  
  final maxElapsed = totalSeconds;
  _elapsedSeconds = math.min(_elapsedSeconds, maxElapsed);
  _currentProgress = 1.0;
  
  if (_isAutoPlayEnabled) {
    print('自動再生処理を開始します');
    
    // 🔧 修正：フラグ設定をここでは行わない（_handleAutoPlayTaskCompletionで行う）
    
    // 即座にタイマーを停止
    timer.cancel();
    
    // 処理を実行
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted && _isAutoPlayEnabled) {
        _handleAutoPlayTaskCompletion(currentTask);
      }
    });
  } else {
    _isPlaying = false;
    print('通常モード: 完了通知を送信');
    _stopProgressTimer();
    _sendTaskPlayCompletedNotification(currentTask);
  }
  
  return;
}
    }
  });
});
  
  print('⏱️ MainWrapper: プログレスタイマーを開始しました');
}

void _startLiveActivityIfNeeded() async {  // asyncを追加
  if (_playingTasks.isEmpty || _isActivityActive) return;
  
  try {
    final started = await _liveActivitiesService.startActivity(  // awaitを追加
      tasks: _playingTasks,
      currentTaskIndex: _currentTaskIndex,
      albumName: _isPlayingSingleAlbum && _playingSingleAlbum != null
          ? _playingSingleAlbum!.albumName
          : _currentIdealSelf,
      artistName: _currentArtistName,
      isAutoPlay: _isAutoPlayEnabled,
      isPlayingSingleAlbum: _isPlayingSingleAlbum,
    );
    
    if (started) {
      _isActivityActive = true;
    }
  } catch (e) {
    // エラー処理
  }
}


void _endLiveActivityIfNeeded() {
  if (!_isActivityActive) return;
  
  try {
    _liveActivitiesService.endActivity();
    _isActivityActive = false;
    // ログ出力を削除
  } catch (e) {
    // エラーログも削除
  }
}

void _updateLiveActivity() {
  // Live Activities無効化中のため処理をスキップ
  return;
}

// 🆕 Live Activity状態変更通知
void _notifyActivityStateChange({
  required bool isPlaying,
  bool? isAutoPlayEnabled,
}) {
  if (!_isActivityActive) return;
  
  try {
    // 現在の状態でActivity更新
    _updateLiveActivity();
    
    print('Live Activity状態変更通知: 再生=${isPlaying ? "開始" : "停止"}');
  } catch (e) {
    print('Live Activity状態変更通知エラー: $e');
  }
}

void _handleAutoPlayTaskCompletion(TaskItem completedTask) async {
  print('アプリ内自動再生タスク完了: ${completedTask.title}');
  
  // 🔧 修正：フラグチェックを削除し、常に処理を実行
  print('🔧 自動再生タスク完了処理を開始');
  
  // 🔧 修正：二重実行防止のためにフラグを設定
  _isAutoPlayInProgress = true;
  
  try {
    await _audioService.playTaskCompletedSound();
    
    // タイマーを一時停止
    _stopProgressTimer();
    
    // 500ms待機してから次の処理（UIの更新を待つ）
    await Future.delayed(const Duration(milliseconds: 500));
    
    // 次のタスクがあるかチェック
    if (_hasNextTaskFixed()) {
      print('🔄 次のタスクに自動移動します');
      _moveToNextTaskAutomatically();
    } else {
      print('🎉 最後のタスクです。アルバム完了処理を実行');
      _completeAllTasksInAutoPlay();
    }
    
  } catch (e) {
    print('❌ アプリ内自動再生タスク完了処理エラー: $e');
  } finally {
    // 🔧 修正：処理完了後にフラグをリセット
    Future.delayed(const Duration(milliseconds: 100), () {
      _isAutoPlayInProgress = false;
    });
  }
}

void _completeAllTasksInAutoPlay() {
  print('🎉 自動再生アルバム完了処理開始');
  
  // 🔧 修正：最後のタスクの完了時刻に設定
  final lastTaskIndex = _playingTasks.length - 1;
  final lastTask = _playingTasks[lastTaskIndex];
  final lastTaskDuration = lastTask.duration * 60;
  
  setState(() {
    _isPlaying = false;
    _isAutoPlayEnabled = false;
    _currentTaskIndex = lastTaskIndex;
    _currentProgress = 1.0;
    _elapsedSeconds = lastTaskDuration; // 🔧 修正：正確な完了時間に設定
  });
  
  _stopProgressTimer(); // 🔧 修正：タイマーを確実に停止
  
  // 🔧 修正：PlayerScreenに完了状態を通知
  _onPlayerStateChanged(
    currentTaskIndex: lastTaskIndex,
    isPlaying: false,
    progress: 1.0,
    elapsedSeconds: lastTaskDuration,
    isAutoPlayEnabled: false,
  );
  
  // アルバム完了ダイアログを表示
  Future.delayed(const Duration(milliseconds: 800), () {
    if (mounted) {
      _showAlbumCompletionDialog();
    }
  });
  
  print('✅ 自動再生アルバム完了処理完了');
}

// 🔧 修正版: 次のタスクがあるかチェック（ライフドリームアルバム対応）
bool _hasNextTaskFixed() {
  if (_isPlayingSingleAlbum) {
    // シングルアルバムの場合：通常のインデックス
    return _currentTaskIndex < _playingTasks.length - 1;
  } else {
    // ライフドリームアルバムの場合：理想像ページ(-1)を考慮
    if (_currentTaskIndex == -1) {
      // 理想像ページから最初のタスクへ
      return _playingTasks.isNotEmpty;
    } else {
      // タスクから次のタスクへ
      return _currentTaskIndex < _playingTasks.length - 1;
    }
  }
}

// 🔧 修正版: 次のタスクを取得（ライフドリームアルバム対応）
TaskItem? _getNextTaskFixed() {
  if (!_hasNextTaskFixed()) return null;
  
  if (_isPlayingSingleAlbum) {
    // シングルアルバムの場合：通常のインデックス
    return _playingTasks[_currentTaskIndex + 1];
  } else {
    // ライフドリームアルバムの場合：理想像ページ(-1)を考慮
    if (_currentTaskIndex == -1) {
      // 理想像ページから最初のタスクへ
      return _playingTasks.isNotEmpty ? _playingTasks[0] : null;
    } else {
      // 現在のタスクから次のタスクへ
      final nextIndex = _currentTaskIndex + 1;
      return nextIndex < _playingTasks.length ? _playingTasks[nextIndex] : null;
    }
  }
}

  // 🔧 修正版: 総経過時間の計算
int _calculateTotalElapsedMinutes() {
  int totalMinutes = 0;
  
  if (_isPlayingSingleAlbum) {
    // シングルアルバムの場合
    for (int i = 0; i <= _currentTaskIndex && i < _playingTasks.length; i++) {
      totalMinutes += _playingTasks[i].duration;
    }
  } else {
    // ライフドリームアルバムの場合：理想像ページ(-1)を考慮
    if (_currentTaskIndex == -1) {
      totalMinutes = 0; // 理想像ページでは時間なし
    } else {
      for (int i = 0; i <= _currentTaskIndex && i < _playingTasks.length; i++) {
        totalMinutes += _playingTasks[i].duration;
      }
    }
  }
  
  return totalMinutes;
}

  // 🔧 修正版: 連続完了チェック（簡易版）
Future<bool> _checkConsecutiveCompletion() async {
  try {
    // 簡易的な連続完了判定を実装
    if (_isPlayingSingleAlbum && _playingSingleAlbum != null) {
      // シングルアルバムの場合：アルバム名で判定
      return await _checkAlbumConsecutiveCompletion(_playingSingleAlbum!.albumName);
    } else {
      // ライフドリームアルバムの場合：理想像で判定
      return await _checkAlbumConsecutiveCompletion(_currentIdealSelf);
    }
  } catch (e) {
    print('❌ 連続完了チェックエラー: $e');
    return false;
  }
}

  // 🔧 修正版: アルバム連続完了の簡易判定
Future<bool> _checkAlbumConsecutiveCompletion(String albumIdentifier) async {
  try {
    // 過去7日間のタスク完了記録を取得
    final now = DateTime.now();
    
    // 簡易的に今日のタスク完了回数をチェック
    int todayCompletions = 0;
    for (final task in _playingTasks) {
      final count = await _taskCompletionService.getTodayTaskSuccesses(task.id);
      todayCompletions += count;
    }
    
    // 今日複数のタスクが完了している場合は「連続」とみなす
    return todayCompletions >= _playingTasks.length;
  } catch (e) {
    print('❌ アルバム連続完了判定エラー: $e');
    return false;
  }
}

  // 🆕 次のタスクがあるかチェック
  bool _hasNextTask() {
    if (_isPlayingSingleAlbum) {
      return _currentTaskIndex < _playingTasks.length - 1;
    } else {
      return _currentTaskIndex < _playingTasks.length - 1;
    }
  }

  // 🆕 次のタスクを取得
  TaskItem? _getNextTask() {
    if (!_hasNextTask()) return null;
    
    return _playingTasks[_currentTaskIndex + 1];
  }

void _moveToNextTaskAutomatically() {
  print('🔄 _moveToNextTaskAutomatically開始');
  print('🔄 移動前 - currentTaskIndex: $_currentTaskIndex, isPlayingSingleAlbum: $_isPlayingSingleAlbum');
  
  // 最後のタスクかチェック
  final isLastTask = _currentTaskIndex >= _playingTasks.length - 1;
  
  if (isLastTask) {
    print('🎉 最後のタスクです。アルバム完了処理を実行');
    _completeAllTasksInAutoPlay();
    return;
  }
  
  // 次のタスクへ移動
  int newTaskIndex;
  int newPageIndex;
  
  if (_isPlayingSingleAlbum) {
    newTaskIndex = _currentTaskIndex + 1;
    newPageIndex = newTaskIndex;
  } else {
    newTaskIndex = _currentTaskIndex + 1;
    newPageIndex = newTaskIndex + 1;
  }
  
  print('🔄 移動先 - newTaskIndex: $newTaskIndex, newPageIndex: $newPageIndex');
  
  setState(() {
    _currentTaskIndex = newTaskIndex;
    _forcePlayerPageIndex = newPageIndex;
    _elapsedSeconds = 0;
    _currentProgress = 0.0;
    _isPlaying = true;
    _isAutoPlayEnabled = true;
    _taskStartTime = DateTime.now();
    _pauseStartTime = null;
    _totalPausedSeconds = 0;
  });
  
  // PlayerScreenに状態変更を通知
  _onPlayerStateChanged(
    currentTaskIndex: _currentTaskIndex,
    isPlaying: true,
    progress: 0.0,
    elapsedSeconds: 0,
    isAutoPlayEnabled: true,
    forcePageChange: _forcePlayerPageIndex,
  );
  
  // 🔧 修正：新しいタスクの通知をスケジュール
  print('🔔 新しいタスクの通知をスケジュール中...');
  _scheduleCurrentTaskAutoPlayNotification();
  
  _startProgressTimer();
  
  print('✅ 自動再生: 次のタスクに移動完了 (タスク${_currentTaskIndex + 1})');
}

// 🆕 新しいメソッド：現在のタスクの自動再生通知をスケジュール
Future<void> _scheduleCurrentTaskAutoPlayNotification() async {
  print('🔔 _scheduleCurrentTaskAutoPlayNotification開始');
  
  if (_currentTaskIndex < 0 || _currentTaskIndex >= _playingTasks.length) {
    print('❌ タスクインデックス範囲外: $_currentTaskIndex');
    return;
  }
  
  final currentTask = _playingTasks[_currentTaskIndex];
  final taskTotalDuration = currentTask.duration * 60; // タスクの総時間
  final remainingSeconds = taskTotalDuration - _elapsedSeconds; // 🔧 修正：残り時間を計算
  final isLastTask = _currentTaskIndex >= _playingTasks.length - 1;
  
  print('🔔 タスク詳細: index=$_currentTaskIndex, 総時間=${taskTotalDuration}秒, 経過=${_elapsedSeconds}秒, 残り=${remainingSeconds}秒, isLast=$isLastTask');
  
  // 🔧 修正：残り時間が0以下の場合はスケジュールしない
  if (remainingSeconds <= 0) {
    print('⚠️ 残り時間が0以下のため通知スケジュールをスキップ');
    return;
  }
  
  try {
    if (isLastTask) {
      print('🔔 最後のタスク: アルバム完了通知をスケジュール');
      await _scheduleAutoPlayAlbumCompletionNotification(remainingSeconds);
    } else {
      print('🔔 中間タスク: 切り替え通知をスケジュール');
      final nextTask = _playingTasks[_currentTaskIndex + 1];
      await _scheduleAutoPlayTaskTransitionNotification(
        currentTask, 
        nextTask, 
        remainingSeconds // 🔧 修正：残り時間を使用
      );
    }
    
    print('✅ タスク${_currentTaskIndex + 1}の自動再生通知をスケジュール完了: ${remainingSeconds}秒後');
  } catch (e) {
    print('❌ 自動再生通知スケジュールエラー: $e');
  }
}

// 🆕 新しいメソッド：タスク切り替え通知のスケジュール
Future<void> _scheduleAutoPlayTaskTransitionNotification(
  TaskItem currentTask, 
  TaskItem nextTask, 
  int delaySeconds
) async {
  // 🔧 修正：既存の通知をキャンセル
  final notificationId = 30000 + _currentTaskIndex;
  await _notificationService.cancelNotification(notificationId);
  
  final payload = [
    'mode=AUTO_PLAY_TRANSITION',
    'completedTaskIndex=$_currentTaskIndex',
    'nextTaskIndex=${_currentTaskIndex + 1}',
    'currentTaskId=${currentTask.id}',
    'nextTaskId=${nextTask.id}',
    'albumName=${_isPlayingSingleAlbum && _playingSingleAlbum != null ? _playingSingleAlbum!.albumName : _currentIdealSelf}',
    'isSingleAlbum=$_isPlayingSingleAlbum',
    'timestamp=${DateTime.now().millisecondsSinceEpoch}',
  ].join('&');
  
  await _notificationService.scheduleDelayedNotification(
    id: notificationId,
    title: '🔄 タスク切り替え',
    body: '「${currentTask.title}」完了！\n次は「${nextTask.title}」を開始します',
    delay: Duration(seconds: delaySeconds),
    payload: payload,
    withActions: false,
  );
  
  print('🔔 タスク切り替え通知スケジュール: ${currentTask.title} → ${nextTask.title} (残り${delaySeconds}秒後)');
}

// 🆕 新しいメソッド：アルバム完了通知のスケジュール
Future<void> _scheduleAutoPlayAlbumCompletionNotification(int delaySeconds) async {
  // 🔧 修正：既存の通知をキャンセル
  final notificationId = 31000;
  await _notificationService.cancelNotification(notificationId);
  
  final albumName = _isPlayingSingleAlbum && _playingSingleAlbum != null 
      ? _playingSingleAlbum!.albumName 
      : _currentIdealSelf;
  
  final payload = [
    'mode=AUTO_PLAY_ALBUM_COMPLETED',
    'albumName=${Uri.encodeComponent(albumName)}',
    'totalTasks=${_playingTasks.length}',
    'isSingleAlbum=$_isPlayingSingleAlbum',
    'timestamp=${DateTime.now().millisecondsSinceEpoch}',
  ].join('&');
  
  await _notificationService.scheduleDelayedNotification(
    id: notificationId,
    title: '🎉 アルバム完了！',
    body: '「$albumName」のすべてのタスクが完了しました。\n結果を報告してください。',
    delay: Duration(seconds: delaySeconds),
    payload: payload,
    withActions: true,
  );
  
  print('🔔 アルバム完了通知スケジュール: $albumName (残り${delaySeconds}秒後)');
}

// 🔧 修正版: 通知用の現在のタスク番号を取得
int _getCurrentTaskNumberForNotification() {
  if (_isPlayingSingleAlbum) {
    return _currentTaskIndex + 1;
  } else {
    // ライフドリームアルバムの場合：理想像ページ(-1)は除外
    return _currentTaskIndex == -1 ? 1 : _currentTaskIndex + 1;
  }
}

  // 🆕 タスク切り替え通知を送信
  Future<void> _sendTaskTransitionNotification(TaskItem completedTask, TaskItem nextTask) async {
    try {
      final title = 'タスク切り替え';
      final body = '「${completedTask.title}」が完了しました。\n「${nextTask.title}」を再生します。';
      
      await _notificationService.showNotification(
        id: 5000 + _currentTaskIndex,
        title: title,
        body: body,
        payload: 'type=task_transition&from=${completedTask.id}&to=${nextTask.id}',
      );
      
      // 音声フィードバック
      await _audioService.playTaskCompletedSound();
      
      print('🔔 タスク切り替え通知を送信: ${completedTask.title} → ${nextTask.title}');
    } catch (e) {
      print('❌ タスク切り替え通知送信エラー: $e');
    }
  }

  // 🆕 アルバム完了通知を送信
  Future<void> _sendAlbumCompletionNotification() async {
    try {
      final albumName = _isPlayingSingleAlbum && _playingSingleAlbum != null 
          ? _playingSingleAlbum!.albumName 
          : _currentIdealSelf;
      
      final title = 'アルバム完了！';
      final body = '「$albumName」のすべてのタスクが完了しました。\nタスクを実行できましたか？';
      
      await _notificationService.showNotificationWithActions(
        id: 6000,
        title: title,
        body: body,
        payload: 'type=album_completion&albumName=$albumName',
        androidActions: [
          const AndroidNotificationAction(
            'album_completion_yes',
            '✅ 全て達成しました',
            showsUserInterface: true,
          ),
          const AndroidNotificationAction(
            'album_completion_no',
            '❌ 一部未達成',
            showsUserInterface: true,
          ),
          const AndroidNotificationAction(
            'album_completion_open',
            '📱 アプリを開く',
            showsUserInterface: true,
          ),
        ],
      );
      
      // 達成音を再生
      await _audioService.playAchievementSound();
      
      print('🔔 アルバム完了通知を送信: $albumName');
    } catch (e) {
      print('❌ アルバム完了通知送信エラー: $e');
    }
  }

  Future<void> _sendTaskPlayCompletedNotification(TaskItem task) async {
  try {
    final albumName = _isPlayingSingleAlbum && _playingSingleAlbum != null 
        ? _playingSingleAlbum!.albumName 
        : _currentIdealSelf;
    
    final albumType = _isPlayingSingleAlbum ? 'single' : 'life_dream';
    final albumId = _isPlayingSingleAlbum && _playingSingleAlbum != null 
        ? _playingSingleAlbum!.id 
        : null;
    
    // 🔧 修正: 音声のみ再生（通知は sendTaskPlayCompletedNotification 内で送信される）
    await _audioService.playTaskCompletedSound();
    
    // 🔧 修正: アプリがフォアグラウンドの場合のみダイアログを表示
    if (mounted && _isPlayerScreenVisible) {
      // 🔧 重要: 通知は送信せず、ダイアログのみ表示
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          _showTaskCompletionDialogInApp(task, albumName, task.duration * 60);
        }
      });
    } else {
      // 🔧 修正: バックグラウンドの場合のみ通知を送信
      await _taskCompletionService.sendTaskPlayCompletedNotification(
        task: task,
        albumName: albumName,
        albumType: albumType,
        albumId: albumId,
        elapsedSeconds: task.duration * 60,
      );
      
      print('🔔 バックグラウンド: タスク再生完了通知を送信しました: ${task.title}');
    }
  } catch (e) {
    print('❌ タスク再生完了通知送信エラー: $e');
  }
}

  void _showTaskCompletionDialogInApp(TaskItem task, String albumName, int elapsedSeconds) {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => CompletionDialog(
            task: task,
            albumName: albumName,
            elapsedSeconds: elapsedSeconds,
            onYes: () async {
              Navigator.of(context).pop();
              await _recordTaskCompletionInApp(task, albumName, elapsedSeconds, true);
              _resetProgressOnly();
            },
            onNo: () async {
              Navigator.of(context).pop();
              await _recordTaskCompletionInApp(task, albumName, elapsedSeconds, false);
              _resetProgressOnly();
            },
            onCancel: () {
              Navigator.of(context).pop();
              _resetProgressOnly();
            },
          ),
        );
      }
    });
  }

  void _resetProgressOnly() {
    setState(() {
      _elapsedSeconds = 0;
      _currentProgress = 0.0;
      _isPlaying = false;
    });
    
    _taskStartTime = null;
    _pauseStartTime = null;
    _totalPausedSeconds = 0;
    
    print('🔧 MainWrapper: 進捗をリセットしました（現在のタスクに留まります）');
  }

  Future<void> _recordTaskCompletionInApp(TaskItem task, String albumName, int elapsedSeconds, bool wasSuccessful) async {
  try {
    final albumType = _isPlayingSingleAlbum ? 'single' : 'life_dream';
    final albumId = _isPlayingSingleAlbum && _playingSingleAlbum != null 
        ? _playingSingleAlbum!.id 
        : null;

    await _taskCompletionService.recordTaskCompletion(
      taskId: task.id,
      taskTitle: task.title,
      wasSuccessful: wasSuccessful,
      elapsedSeconds: elapsedSeconds,
      albumType: albumType,
      albumName: albumName,
      albumId: albumId,
    );
    
    if (wasSuccessful) {
      await _audioService.playAchievementSound();
      
      // 🔧 修正: カウントを即座に更新
      setState(() {
        _todayTaskCompletions[task.id] = (_todayTaskCompletions[task.id] ?? 0) + 1;
      });
      
      print('✅ タスク完了カウント更新: ${task.title} → ${_todayTaskCompletions[task.id]}');
      
      // 🆕 追加: PlayerScreenに即座に通知
      if (mounted) {
        // PlayerScreenの状態を強制更新
        setState(() {});
      }
      
      await _notifyNewTaskCompletion();
    } else {
      await _audioService.playNotificationSound();
    }
    
    // 🔧 修正: データ再読み込み後も最新のカウントを保持
    final currentCounts = Map<String, int>.from(_todayTaskCompletions);
    await _loadUserData();
    
    // 🔧 重要: 再読み込み後に最新のカウントをマージ
    setState(() {
      _todayTaskCompletions = {
        ..._todayTaskCompletions,
        ...currentCounts,
      };
    });
    
    print('✅ タスク完了記録完了: ${task.title} (成功: $wasSuccessful)');
  } catch (e) {
    print('❌ アプリ内タスク完了記録エラー: $e');
  }
}
  // main_wrapper.dart の _buildCurrentScreen メソッド

Widget _buildCurrentScreen() {
  final screenHeight = MediaQuery.of(context).size.height;
  
  return Stack(
    children: [
      // メインコンテンツ
      if (!_isSettingsVisible && !_isAlbumDetailVisible) _buildMainContent(),  // 🔧 修正：アルバム詳細表示中は非表示
      
      // 🔧 修正：アルバム詳細を常に表示（PlayerScreenの下）
      if (_isAlbumDetailVisible) _buildAlbumDetailScreen(),
      
      // PlayerScreen
if (_playingTasks.isNotEmpty && (_isDraggingPlayer || _playerDragController.value < 1.0 || _isPlayerScreenVisible))
  Positioned(
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (details) {
        final isAtTop = PlayerScreen.isAtTopOfScroll(_playerScreenKey);
        if (!isAtTop) return;
        
        if (_isAnimating) {
          setState(() {
            _isAnimating = false;
          });
        }
        
        setState(() {
          _isDraggingPlayer = true;
          _isPlayerScreenVisible = true;
        });
      },
      onVerticalDragUpdate: (details) {
        if (_isDraggingPlayer && !_isAnimating) {
          final deltaOffset = details.delta.dy / screenHeight;
          _playerDragController.value = (_playerDragController.value + deltaOffset).clamp(0.0, 1.0);
        }
      },
      onVerticalDragEnd: (details) {
  if (!_isDraggingPlayer) return;
  
  // 🔧 修正：setState を削除して即座にアニメーション開始
  _isDraggingPlayer = false;
  
  final velocity = details.primaryVelocity ?? 0;
  final currentValue = _playerDragController.value;
  
  if (velocity > 500 || currentValue > 0.3) {
    _closePlayerWithAnimation();
  } else {
    _openPlayerWithAnimation();
  }
},
      child: AnimatedBuilder(
        animation: _playerDragAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, screenHeight * _playerDragAnimation.value),
            child: child,
          );
        },
        child: RepaintBoundary(
          child: Container(
            height: screenHeight,
            width: double.infinity,
            color: Colors.transparent,
            child: _buildPlayerScreen(),
          ),
        ),
      ),
    ),
  ),
      
      // 設定画面（最前面）
      if (_isSettingsVisible) _buildSettingsScreen(),
      
      if (_isArtistScreenVisible) _buildArtistScreen(),
    ],
  );
}
Widget _buildMainContent() {
  return IndexedStack(
    index: _selectedPageIndex,
    children: [
      // ホーム画面
      _buildBlackScreen(
        child: HomeScreen(
          onDataUpdated: _onDataUpdated,
          imageBytes: _imageBytes,
          albumImagePath: _currentAlbumImagePath,
          onNavigateToAlbumDetail: _showAlbumDetail,
          onNavigateToSettings: _showSettings,
          onNavigateToPlayer: _showFullPlayer,
          onNavigateToIdealPage: _showFullPlayerWithIdealPage,
          onNavigateToSingleAlbumDetail: _showSingleAlbumDetail,
          onNavigateToArtist: _showArtistScreen,
        ),
      ),
      
      // チャート画面
      _buildBlackScreen(
        child: ChartsScreen(),
      ),
      
      // プレイバック画面（🔧 変更：ValueKeyを削除してGlobalKeyに変更）
      _buildBlackScreen(
        child: PlaybackScreen(
          key: _playbackScreenKey, // 🔧 変更
        ),
      ),
      
      // シングルアルバム作成画面
      Container(
        color: Colors.black,
        child: Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top,
          ),
          child: SingleAlbumCreateScreen(
            onClose: () {
              setState(() {
                _selectedPageIndex = 0;
              });
            },
            onSave: _onSingleAlbumSave,
          ),
        ),
      ),
    ],
  );
}

  Widget _buildBlackScreen({required Widget child}) {
    return Container(
      color: Colors.black,
      child: Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top,
        ),
        child: Material(
          color: Colors.transparent,
          child: child,
        ),
      ),
    );
  }

  Widget _buildAlbumDetailScreen() {
  if (_currentSingleAlbum != null) {
    final album = _currentSingleAlbum!;
    
    return AlbumDetailScreen(
      albumImagePath: '',
      idealSelf: album.albumName,
      artistName: _currentArtistName,
      tasks: album.tasks,
      imageBytes: album.albumCoverImage,
      albumId: album.id,              // 🔧 追加
      isSingleAlbum: true,            // 🔧 追加
      onPlayPressed: () {
        // 🔧 修正：PlayerScreenを開く（アルバム詳細は非表示）
        if (_isPlayingSingleAlbum && _playingSingleAlbum != null && _playingSingleAlbum!.id == album.id) {
          print('🎵 同じアルバム - 現在の再生状態を保持');
          setState(() {
            _isPlayerScreenVisible = true;
            // _isAlbumDetailVisible はtrueのまま（背景に残す）
          });
        } else {
          print('🎵 違うアルバム - 新しい再生開始');
          _showSingleAlbumPlayer(album, taskIndex: 0);
        }
      },
      onPlayTaskPressed: (taskIndex) {
  // 🔧 修正: タスク切り替え時にもPlayerScreenを開く
  if (_isPlayingSingleAlbum && _playingSingleAlbum != null && _playingSingleAlbum!.id == album.id) {
    print('🎵 同じアルバム タスク$taskIndex - タスク切り替え');
    setState(() {
      _currentTaskIndex = taskIndex;
      _forcePlayerPageIndex = taskIndex;
      _startNewTask();
      _isPlayerScreenVisible = true;  // 🔧 追加: PlayerScreenを表示
    });
    
    _onPlayerStateChanged(
      currentTaskIndex: taskIndex,
      forcePageChange: taskIndex,
    );
    
    // 🔧 追加: PlayerScreenを開くアニメーションを実行
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        print('🎵 PostFrameCallback: _openPlayerWithAnimation()を実行');
        _openPlayerWithAnimation();
      }
    });
  } else {
    print('🎵 違うアルバム タスク$taskIndex - 新しい再生開始');
    _showSingleAlbumPlayer(album, taskIndex: taskIndex);
  }
},
      onClose: _hideAlbumDetail,
      onNavigateToSettings: () {
        final albumToEdit = album;
        
        setState(() {
          _isAlbumDetailVisible = false;
          _currentSingleAlbum = albumToEdit;
          _isSettingsVisible = true;
        });
        
        print('📝 シングルアルバム設定画面を表示: ${albumToEdit.albumName}');
      },
    );
  } else {
    return AlbumDetailScreen(
      albumImagePath: _currentAlbumImagePath,
      idealSelf: _currentIdealSelf,
      artistName: _currentArtistName,
      tasks: _currentTasks,
      imageBytes: _imageBytes,
      albumId: null,                  // 🔧 追加
      isSingleAlbum: false,           // 🔧 追加
      onPlayPressed: () {
        // 🔧 修正：PlayerScreenを開く（アルバム詳細は非表示）
        setState(() {
          _isPlayerScreenVisible = true;
          // _isAlbumDetailVisible はtrueのまま（背景に残す）
        });
        _showFullPlayer();
      },
      onPlayTaskPressed: (taskIndex) {
        print('🎵 ライフドリームアルバム タスク$taskIndex をタップ（理想像考慮で${taskIndex + 1}に変換）');
        
        // 🔧 修正：PlayerScreenを開く（アルバム詳細は非表示）
        setState(() {
          _isPlayerScreenVisible = true;
          // _isAlbumDetailVisible はtrueのまま（背景に残す）
        });
        _showFullPlayerWithTask(taskIndex);
      },
      onClose: _hideAlbumDetail,
      onNavigateToSettings: () {
        setState(() {
          _isAlbumDetailVisible = false;
          _currentSingleAlbum = null;
          _isSettingsVisible = true;
        });
        
        print('📝 ライフドリームアルバム設定画面を表示');
      },
    );
  }
}

Widget _buildPlayerScreen() {
  String playerIdealSelf;
  String playerAlbumImagePath;
  Uint8List? playerAlbumCoverImage;
  String? playingSingleAlbumId;
  
  if (_isPlayingSingleAlbum && _playingSingleAlbum != null) {
    playerIdealSelf = _playingSingleAlbum!.albumName;
    playerAlbumImagePath = '';
    playerAlbumCoverImage = _playingSingleAlbum!.albumCoverImage;
    playingSingleAlbumId = _playingSingleAlbum!.id;
  } else {
    playerIdealSelf = _currentIdealSelf;
    playerAlbumImagePath = _currentAlbumImagePath;
    playerAlbumCoverImage = _imageBytes;
    playingSingleAlbumId = null;
  }

  return Container(
    color: Colors.black,
    child: PlayerScreen(
      key: _playerScreenKey,
      idealSelf: playerIdealSelf,
      artistName: _currentArtistName,
      tasks: _playingTasks,
      albumImagePath: playerAlbumImagePath,
      albumCoverImage: playerAlbumCoverImage,
      isPlayingSingleAlbum: _isPlayingSingleAlbum,
      playingSingleAlbumId: playingSingleAlbumId,
      initialTaskIndex: _currentTaskIndex,
      initialIsPlaying: _isPlaying,
      initialElapsedSeconds: _elapsedSeconds,
      initialAutoPlayEnabled: _isAutoPlayEnabled,
      initialProgress: _currentProgress,
      forcePageIndex: _forcePlayerPageIndex,
      todayTaskCompletions: _todayTaskCompletions,
      onDataChanged: _onDataUpdated,
      onStateChanged: _onPlayerStateChanged,
      onClose: _hideFullPlayer,
      onTaskCompleted: _onTaskCompletedFromPlayer,
      onCompletionCountsChanged: _onCompletionCountsChanged,
      onNavigateToSettings: () {  // 🔧 修正：遅延を削除
        // PlayerScreenを閉じずに設定画面を最前面に表示
        if (_isPlayingSingleAlbum && _playingSingleAlbum != null) {
          final albumToEdit = _playingSingleAlbum!;
          
          setState(() {
            _isPlayerScreenVisible = false;
            _currentSingleAlbum = albumToEdit;
            _isSettingsVisible = true;
          });
          
          print('📝 シングルアルバム設定画面を表示: ${albumToEdit.albumName}');
        } else {
          setState(() {
            _isPlayerScreenVisible = false;
            _currentSingleAlbum = null;
            _isSettingsVisible = true;
          });
          
          print('📝 ライフドリームアルバム設定画面を表示');
        }
      },
      onNavigateToAlbumDetail: () {
        _hideFullPlayer();
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_isPlayingSingleAlbum && _playingSingleAlbum != null) {
            _showSingleAlbumDetail(_playingSingleAlbum!);
          } else {
            _showAlbumDetail();
          }
        });
      },
    ),
  );
}

  // アルバム完了申告ダイアログを表示
void _showAlbumCompletionDialog() {
  final albumName = _isPlayingSingleAlbum && _playingSingleAlbum != null 
      ? _playingSingleAlbum!.albumName 
      : _currentIdealSelf;
  
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlbumCompletionDialog(
      albumName: albumName,
      tasks: _playingTasks,
      onYes: () async {
        Navigator.of(context).pop();
        await _recordAllTasksCompletion(true);
      },
      onNo: () async {
        Navigator.of(context).pop();
        await _recordAllTasksCompletion(false);
      },
    ),
  );
}

// 全タスクの完了記録
Future<void> _recordAllTasksCompletion(bool allCompleted) async {
  try {
    if (allCompleted) {
      int completedCount = 0;
      for (final task in _playingTasks) {
        await _taskCompletionService.recordTaskCompletion(
          taskId: task.id,
          taskTitle: task.title,
          wasSuccessful: true,
          elapsedSeconds: task.duration * 60,
          albumType: _isPlayingSingleAlbum ? 'single' : 'life_dream',
          albumName: _isPlayingSingleAlbum && _playingSingleAlbum != null 
              ? _playingSingleAlbum!.albumName 
              : _currentIdealSelf,
          albumId: _isPlayingSingleAlbum && _playingSingleAlbum != null 
              ? _playingSingleAlbum!.id 
              : null,
        );
        
        setState(() {
          _todayTaskCompletions[task.id] = (_todayTaskCompletions[task.id] ?? 0) + 1;
        });
        completedCount++;
      }
      
      await _audioService.playAchievementSound();
      
      for (int i = 0; i < completedCount; i++) {
        await _notifyNewTaskCompletion();
      }
      
      _showCompletionResultDialog(true);
    } else {
      _showCompletionResultDialog(false);
    }
    
    _resetPlayerAfterCompletion();
    
    // 🆕 重要：ホーム画面のデータを更新
    await _loadUserData();
    
    // 🆕 追加：ホーム画面に通知を送る
    await _notifyHomeScreenToRefresh();
    
  } catch (e) {
    print('❌ アルバム完了記録エラー: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('記録の保存に失敗しました'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

Future<void> _notifyHomeScreenToRefresh() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('home_screen_refresh_trigger', DateTime.now().millisecondsSinceEpoch);
    print('🔔 ホーム画面更新トリガーを設定');
  } catch (e) {
    print('❌ ホーム画面更新通知エラー: $e');
  }
}

// 新規追加メソッド
Future<void> _notifyNewTaskCompletion() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final currentCount = prefs.getInt('new_task_completion_count') ?? 0;
    await prefs.setInt('new_task_completion_count', currentCount + 1);
    await prefs.setInt('last_task_completion_timestamp', DateTime.now().millisecondsSinceEpoch);
    print('新規タスク完了を通知: ${currentCount + 1}個目');
  } catch (e) {
    print('新規タスク完了通知エラー: $e');
  }
}

// SharedPreferencesからタスク完了通知をチェック
Future<void> _checkTaskCompletionNotification() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final lastNotification = prefs.getInt('new_task_completed_timestamp') ?? 0;
    final lastCheck = prefs.getInt('charts_last_check') ?? 0;
    
    if (lastNotification > lastCheck) {
      // 新しい完了通知がある
      print('新しいタスク完了通知を検出');
      await _checkForNewTasks();
      await prefs.setInt('charts_last_check', DateTime.now().millisecondsSinceEpoch);
    }
  } catch (e) {
    print('完了通知チェックエラー: $e');
  }
}



// 🆕 新しいメソッド：報告完了後のプレイヤーリセット
void _resetPlayerAfterCompletion() {
  print('🔄 報告完了後のプレイヤーリセット開始');
  
  setState(() {
    // プレイヤー状態をリセット
    _isPlaying = false;
    _isAutoPlayEnabled = false;
    _currentProgress = 0.0;
    _elapsedSeconds = 0;
    _currentTaskIndex = _isPlayingSingleAlbum ? 0 : -1; // 理想像ページまたは最初のタスクに戻す
    
    // タイマー関連をリセット
    _taskStartTime = null;
    _pauseStartTime = null;
    _totalPausedSeconds = 0;
    _isAutoPlayInProgress = false;
    
    // ページインデックスをリセット
    _forcePlayerPageIndex = _isPlayingSingleAlbum ? 0 : 0; // 最初のページに戻す
  });
  
  // タイマーを停止
  _stopProgressTimer();
  
  // PlayerScreenに リセット状態を通知
  _onPlayerStateChanged(
    currentTaskIndex: _isPlayingSingleAlbum ? 0 : -1,
    isPlaying: false,
    progress: 0.0,
    elapsedSeconds: 0,
    isAutoPlayEnabled: false,
    forcePageChange: _isPlayingSingleAlbum ? 0 : 0,
  );
  
  print('✅ プレイヤーリセット完了');
}


// 完了結果ダイアログを表示
void _showCompletionResultDialog(bool allCompleted) {
  final albumName = _isPlayingSingleAlbum && _playingSingleAlbum != null 
      ? _playingSingleAlbum!.albumName 
      : _currentIdealSelf;
  
  showDialog(
    context: context,
    builder: (context) => CompletionResultDialog(
      albumName: albumName,
      tasks: _playingTasks,
      allCompleted: allCompleted,
      todayTaskCompletions: _todayTaskCompletions,
      onClose: () {
        Navigator.of(context).pop();
      },
    ),
  );
}

  Future<void> _onTaskCompletedFromPlayer(TaskItem task, bool wasSuccessful) async {
  print('🔍 MainWrapper._onTaskCompletedFromPlayer 呼び出し');
  print('  - taskId: ${task.id}');
  print('  - taskTitle: ${task.title}');
  print('  - wasSuccessful: $wasSuccessful');
  print('  - isPlayingSingleAlbum: $_isPlayingSingleAlbum');
  print('  - 現在のカウント: ${_todayTaskCompletions[task.id] ?? 0}');
  
  // 🔧 修正: 完了前のカウントを保存
  final previousCount = _todayTaskCompletions[task.id] ?? 0;
  
  await _recordTaskCompletionInApp(
    task, 
    _isPlayingSingleAlbum && _playingSingleAlbum != null 
        ? _playingSingleAlbum!.albumName 
        : _currentIdealSelf,
    _elapsedSeconds,
    wasSuccessful,
  );
  
  // 🔧 修正: カウントが更新されたことを確認
  final newCount = _todayTaskCompletions[task.id] ?? 0;
  print('✅ MainWrapper._onTaskCompletedFromPlayer 完了');
  print('  - 更新前カウント: $previousCount');
  print('  - 更新後カウント: $newCount');
  
  // 🆕 追加: PlayerScreenに最新のカウントを通知
  if (mounted && _isPlayerScreenVisible) {
    // 強制的に再描画
    setState(() {});
  }
}

  void _onCompletionCountsChanged(Map<String, int> newCounts) {
  print('🔍 MainWrapper._onCompletionCountsChanged 呼び出し');
  print('  - 受信したカウント: $newCounts');
  
  setState(() {
    // 🔧 修正: 既存のカウントとマージ
    _todayTaskCompletions = {
      ..._todayTaskCompletions,
      ...newCounts,
    };
  });
  
  print('✅ MainWrapper._onCompletionCountsChanged 完了');
  print('  - 更新後の_todayTaskCompletions: $_todayTaskCompletions');
  
  // 🆕 追加: PlayerScreenに即座に反映
  if (mounted && _isPlayerScreenVisible) {
    setState(() {});
  }
}

  Widget _buildSettingsScreen() {
  // シングルアルバムの設定を編集中の場合
  if (_currentSingleAlbum != null) {
    return _buildSingleAlbumSettingsScreen(_currentSingleAlbum!);
  }
  
  // ライフドリームアルバム
  return SettingsScreen(
    idealSelf: _currentIdealSelf,
    artistName: _currentArtistName,
    todayLyrics: '今日という日を大切に生きよう\n一歩ずつ理想の自分に近づいていく\n昨日の自分を超えていこう\n今この瞬間を輝かせよう',
    albumImage: _currentAlbumImagePath.isNotEmpty ? File(_currentAlbumImagePath) : null,
    albumCoverImage: _imageBytes,
    tasks: _currentTasks,
    isEditingLifeDream: true,
    onClose: () {  // 🔧 修正：クローズ時の処理を変更
      setState(() {
        _isSettingsVisible = false;
        
        // PlayerScreenから開いた場合
        if (!_isPlayingSingleAlbum && _playingTasks.isNotEmpty) {
          _isPlayerScreenVisible = true;  // PlayerScreenに戻る
        } else {
          // アルバム詳細から開いた場合
          _isAlbumDetailVisible = true;  // アルバム詳細に戻る
        }
      });
    },
    onSave: (result) {
      setState(() {
        _currentIdealSelf = result['idealSelf'] ?? _currentIdealSelf;
        _currentArtistName = result['artistName'] ?? _currentArtistName;
        _currentTasks = List<TaskItem>.from(result['tasks'] ?? _currentTasks);
        
        if (result['hasImageChanged'] == true) {
          _imageBytes = result['imageBytes'];
        }
      });
      
      _onDataUpdated();
      
      // 🔧 修正：保存後の遷移処理
      setState(() {
        _isSettingsVisible = false;
        
        // PlayerScreenから開いた場合
        if (!_isPlayingSingleAlbum && _playingTasks.isNotEmpty) {
          _playingTasks = List.from(_currentTasks);  // タスクを更新
          _isPlayerScreenVisible = true;  // PlayerScreenに戻る
        } else {
          // アルバム詳細から開いた場合
          _isAlbumDetailVisible = true;  // アルバム詳細に戻る
        }
      });
    },
  );
}




  Widget _buildOtherScreen(String text) {
    return Container(
      color: Colors.transparent,
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildBottomSection() {
  return AnimatedBuilder(
    animation: _playerDragController,
    builder: (context, child) {
      if (_playerDragController.value < 0.1 || _isSettingsVisible) {
        return const SizedBox.shrink();
      }
      
      // 🔧 value が変わるたびに再計算
      final opacity = _playerDragController.value >= 0.95 
          ? 1.0 
          : _playerDragController.value <= 0.7
              ? 0.0 
              : ((_playerDragController.value - 0.7) / 0.25);
      
      return Opacity(
        opacity: opacity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_playingTasks.isNotEmpty) _buildMiniPlayerWithDrag(),
            if (_playingTasks.isNotEmpty) _buildFullWidthProgressBar(),
            _buildPageSelector(),
          ],
        ),
      );
    },
  );
}

// main_wrapper.dart の _buildMiniPlayerWithDrag メソッド

Widget _buildMiniPlayerWithDrag() {
  final screenHeight = MediaQuery.of(context).size.height;
  
  print('🔍 _buildMiniPlayerWithDrag 呼び出し:');
  print('  - _currentTaskIndex: $_currentTaskIndex');
  print('  - _isPlayingSingleAlbum: $_isPlayingSingleAlbum');
  print('  - _playingTasks.length: ${_playingTasks.length}');
  if (_playingTasks.isNotEmpty && _currentTaskIndex >= 0 && _currentTaskIndex < _playingTasks.length) {
    print('  - 表示するタスク: ${_playingTasks[_currentTaskIndex].title}');
  }
  
  return GestureDetector(
    onVerticalDragStart: (details) {
      print('🎵 簡易プレイヤー: ドラッグ開始');
      
      if (_isAnimating) {
        setState(() {
          _isAnimating = false;
        });
      }
      
      setState(() {
        _isDraggingPlayer = true;
        _isPlayerScreenVisible = true;
      });
    },
    onVerticalDragUpdate: (details) {
  if (_isDraggingPlayer && !_isAnimating) {
    final deltaOffset = details.delta.dy / screenHeight;
    _playerDragController.value = (_playerDragController.value + deltaOffset).clamp(0.0, 1.0);
  }
},
    onVerticalDragEnd: (details) {
  if (!_isDraggingPlayer) return;
  
  // 🔧 修正：setState を削除
  _isDraggingPlayer = false;
  
  final velocity = details.primaryVelocity ?? 0;
  final currentValue = _playerDragController.value;
  
  if (velocity < -500 || currentValue < 0.7) {
    _openPlayerWithAnimation();
  } else {
    _closePlayerWithAnimation();
  }
},
    onTap: () {
      print('🎵 簡易プレイヤー: タップで開く');
      _openPlayerWithAnimation();
    },
    child: Container(
      height: 64,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF282828),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Album Cover
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: _buildMiniPlayerAlbumCover(),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Song Info
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // 🔧 修正：インデックスのバリデーション
                  _playingTasks.isNotEmpty && _currentTaskIndex >= 0 && _currentTaskIndex < _playingTasks.length
                      ? (_playingTasks[_currentTaskIndex].title.isEmpty
                          ? 'タスク${_currentTaskIndex + 1}'
                          : _playingTasks[_currentTaskIndex].title)
                      : _playingTasks.isNotEmpty && _currentTaskIndex == -1
                          ? (_isPlayingSingleAlbum && _playingSingleAlbum != null 
                              ? _playingSingleAlbum!.albumName 
                              : _currentIdealSelf)
                          : 'タスク',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Hiragino Sans',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _currentArtistName,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'Hiragino Sans',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Play/Pause Button
          GestureDetector(
            onTap: () {
              setState(() {
                if (_isPlaying) {
                  _stopProgressTimer();
                  _isPlaying = false;
                  print('⏸️ 簡易プレイヤー: 一時停止');
                } else {
                  _startProgressTimer();
                  _isPlaying = true;
                  print('▶️ 簡易プレイヤー: 再生');
                }
              });
              
              if (_isPlayerScreenVisible) {
                _onPlayerStateChanged(
                  isPlaying: _isPlaying,
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// 🔧 修正：簡易プレイヤーのアルバムカバー
Widget _buildMiniPlayerAlbumCover() {
  // シングルアルバム再生中の場合
  if (_isPlayingSingleAlbum && _playingSingleAlbum != null && _playingSingleAlbum!.albumCoverImage != null) {
    return Image.memory(
      _playingSingleAlbum!.albumCoverImage!,  // 🔧 修正：! を追加
      width: 48,
      height: 48,
      fit: BoxFit.cover,
    );
  }
  
  // ライフドリームアルバム再生中の場合
  if (_imageBytes != null) {
    return Image.memory(
      _imageBytes!,
      width: 48,
      height: 48,
      fit: BoxFit.cover,
    );
  }
  
  // 画像がない場合はデフォルト表示
  return Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF1DB954),
          Color(0xFF1ED760),
          Color(0xFF17A2B8),
        ],
      ),
    ),
    child: const Center(
      child: Icon(
        Icons.album,
        size: 24,
        color: Colors.white,
      ),
    ),
  );
}




  Widget _buildMiniPlayer() {
  final miniPlayerOpacity = (_playerDragOffset - 0.9) / 0.1;
final clampedOpacity = miniPlayerOpacity.clamp(0.0, 1.0);
  
  if (clampedOpacity < 0.01) {
    return const SizedBox.shrink();
  }
  
  if (_currentTaskIndex == -1) {
    return Opacity(
      opacity: clampedOpacity,
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(12),
          ),
        ),
        child: Row(
          children: [
            _buildCurrentPlayingAlbumCover(size: 48),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _currentIdealSelf,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Hiragino Sans',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1DB954).withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '理想像',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _currentArtistName,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      fontFamily: 'Hiragino Sans',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: _togglePlayPause,
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  if (_playingTasks.isEmpty || _currentTaskIndex < 0 || _currentTaskIndex >= _playingTasks.length) {
    return const SizedBox.shrink();
  }
  
  final currentTask = _playingTasks[_currentTaskIndex];
  
  return Opacity(
    opacity: clampedOpacity,
    child: Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          _buildCurrentPlayingAlbumCover(size: 48),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        currentTask.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Hiragino Sans',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_isAutoPlayEnabled)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1DB954).withOpacity(0.8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                              size: 10,
                            ),
                            SizedBox(width: 2),
                            Text(
                              '自動',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: currentTask.color.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_currentTaskIndex + 1}/${_playingTasks.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _isPlayingSingleAlbum && _playingSingleAlbum != null 
                      ? _playingSingleAlbum!.albumName 
                      : _currentIdealSelf,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'Hiragino Sans',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: _togglePlayPause,
            child: Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 28,
            ),
          ),
        ],
      ),
    ),
  );
}

void _openPlayerWithAnimation() {
  if (!mounted) return;
  
  _isAnimating = true;
  _isPlayerScreenVisible = true;
  
  final remainingDistance = _playerDragController.value;
  final duration = (400 * remainingDistance).toInt().clamp(250, 400); // 🔧 修正：250〜400ms
  
  _playerDragController.animateTo(
    0.0,
    duration: Duration(milliseconds: duration),
    curve: Curves.easeOutCubic,
  ).then((_) {
    if (mounted) {
      setState(() {
        _isAnimating = false;
      });
    }
  });
}

void _closePlayerWithAnimation() {
  if (!mounted) return;
  
  _isAnimating = true;
  
  final remainingDistance = 1.0 - _playerDragController.value;
  final duration = (400 * remainingDistance).toInt().clamp(250, 400); // 🔧 修正：250〜400ms
  
  _playerDragController.animateTo(
    1.0,
    duration: Duration(milliseconds: duration),
    curve: Curves.easeOutCubic,
  ).then((_) {
    if (mounted) {
      setState(() {
        _isPlayerScreenVisible = false;
        _isAnimating = false;
      });
    }
  });
}






  Widget _buildFullWidthProgressBar() {
    if (_currentTaskIndex == -1) {
      return Container(
        width: double.infinity,
        height: 3,
        color: Colors.white.withOpacity(0.1),
      );
    }
    
    if (_playingTasks.isEmpty || _currentTaskIndex < 0 || _currentTaskIndex >= _playingTasks.length) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      height: 3,
      color: Colors.transparent,
      child: LinearProgressIndicator(
        value: _currentProgress.clamp(0.0, 1.0),
        backgroundColor: Colors.white.withOpacity(0.2),
        valueColor: AlwaysStoppedAnimation<Color>(
          _isAutoPlayEnabled ? const Color(0xFF1DB954) : Colors.white
        ),
      ),
    );
  }

  Widget _buildCurrentPlayingAlbumCover({double size = 48}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: _isPlayingSingleAlbum && _playingSingleAlbum != null
            ? (_playingSingleAlbum!.albumCoverImage != null
                  ? Image.memory(
                      _playingSingleAlbum!.albumCoverImage!,
                      width: size,
                      height: size,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF8B5CF6),
                            Color(0xFF06B6D4),
                          ],
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.music_note,
                          color: Colors.white,
                          size: size * 0.5,
                        ),
                      ),
                    ))
            : (_imageBytes != null
                  ? Image.memory(
                      _imageBytes!,
                      width: size,
                      height: size,
                      fit: BoxFit.cover,
                    )
                  : _currentAlbumImagePath.isNotEmpty && File(_currentAlbumImagePath).existsSync()
                      ? Image.file(
                          File(_currentAlbumImagePath),
                          width: size,
                          height: size,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF1DB954),
                                Color(0xFF1ED760),
                              ],
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.album,
                              color: Colors.white,
                              size: size * 0.5,
                            ),
                          ),
                        )),
      ),
    );
  }

  Widget _buildPageSelector() {
  if (_isSettingsVisible) {
    return const SizedBox.shrink();
  }
  
  final pages = [
    {'icon': Icons.home, 'label': 'Home'},
    {'icon': Icons.music_note, 'label': 'Concert'},
    {'icon': Icons.leaderboard, 'label': 'Playback'},
    {'icon': Icons.add_circle_outline, 'label': 'Release'},
  ];

  return Container(
    height: 80,
    decoration: const BoxDecoration(
      color: Colors.black,
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: List.generate(pages.length, (index) {
        final isSelected = _selectedPageIndex == index;
        final page = pages[index];
        
        return GestureDetector(
          onTap: () {
            // 🆕 追加：PlaybackScreen表示時のみデータ更新を呼び出し
            if (index == 2 && _selectedPageIndex != 2) {
              _refreshPlaybackScreen();
            }
            
            setState(() {
              _selectedPageIndex = index;
              if (_isAlbumDetailVisible) {
                _isAlbumDetailVisible = false;
                _currentSingleAlbum = null;
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  page['icon'] as IconData,
                  color: isSelected 
                      ? const Color(0xFF1DB954) 
                      : Colors.white.withOpacity(0.6),
                  size: 26,
                ),
                const SizedBox(height: 6),
                Text(
                  page['label'] as String,
                  style: TextStyle(
                    color: isSelected 
                        ? const Color(0xFF1DB954) 
                        : Colors.white.withOpacity(0.6),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Hiragino Sans',
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    ),
  );
}

/// 【新規追加】PlaybackScreenのデータを更新
void _refreshPlaybackScreen() {
  try {
    final playbackState = _playbackScreenKey.currentState;
    if (playbackState != null) {
      // 🔧 修正：dynamic経由でメソッド呼び出し
      (playbackState as dynamic).refreshData();
    }
  } catch (e) {
    print('PlaybackScreen更新エラー: $e');
  }
}

  // _initializeNotificationService を修正
Future<void> _initializeNotificationService() async {
  try {
    // 初期化前にコールバックを設定（重要）
    _notificationService.setNotificationResponseCallback(_handleNotificationResponse);
    print('🔔 通知応答コールバックを設定');
    
    final initialized = await _notificationService.initialize();
    if (initialized) {
      print('🔔 通知サービス初期化完了');
      
      // 保留中の通知応答を確認
      final NotificationAppLaunchDetails? details = 
          await _notificationService.getNotificationAppLaunchDetails();
      
      if (details?.didNotificationLaunchApp ?? false) {
        if (details!.notificationResponse != null) {
          print('🔔 アプリ起動時の通知を検出');
          await _handleNotificationResponse(details.notificationResponse!);
        }
      }
    }
  } catch (e) {
    print('❌ 通知サービス初期化エラー: $e');
  }
}

Future<void> _handleNotificationResponse(NotificationResponse response) async {
  if (response.payload == null) return;
  
  final params = <String, String>{};
  for (final pair in response.payload!.split('&')) {
    final parts = pair.split('=');
    if (parts.length == 2) {
      params[parts[0]] = Uri.decodeComponent(parts[1]);
    }
  }
  
  final mode = params['mode'] ?? '';
  
  if (mode == 'AUTO_PLAY_TRANSITION') {
    await _handleAutoPlayTransitionNotification(params);
  } else if (mode == 'AUTO_PLAY_ALBUM_COMPLETED') {
    await _handleAutoPlayAlbumCompletedNotification(params);
  } else if (mode == 'AUTO_PLAY_TASK') {
    await _handleAutoPlayTaskNotification(params);
  } else if (mode == 'NORMAL') {
    await _handleNormalModeNotification(params);
  }
}

// 🆕 新しいメソッド：自動再生タスク切り替え通知の処理
Future<void> _handleAutoPlayTransitionNotification(Map<String, String> params) async {
  try {
    _isNotificationReturning = true;
    
    final nextTaskIndex = int.tryParse(params['nextTaskIndex'] ?? '') ?? 0;
    final pageIndex = _isPlayingSingleAlbum ? nextTaskIndex : nextTaskIndex + 1;
    
    // 次のタスクを開始状態に設定
    setState(() {
      _currentTaskIndex = nextTaskIndex;
      _forcePlayerPageIndex = pageIndex;
      _elapsedSeconds = 0;
      _currentProgress = 0.0;
      _isPlaying = true;
      _isAutoPlayEnabled = true;
      _isPlayerScreenVisible = true;
      _taskStartTime = DateTime.now();
      _pauseStartTime = null;
      _totalPausedSeconds = 0;
    });
    
    _startProgressTimer();
    
    _onPlayerStateChanged(
      currentTaskIndex: nextTaskIndex,
      isPlaying: true,
      progress: 0.0,
      elapsedSeconds: 0,
      isAutoPlayEnabled: true,
      forcePageChange: pageIndex,
    );
    
    print('✅ タスク切り替え通知処理完了: タスク${nextTaskIndex + 1}を開始');
  } catch (e) {
    print('❌ タスク切り替え通知処理エラー: $e');
  }
}


Future<void> _handleAutoPlayTaskNotification(Map<String, String> params) async {
  try {
    print('自動再生タスク通知処理開始');
    
    final completedTaskIndex = int.tryParse(params['completedTaskIndex'] ?? '') ?? 0;
    final nextTaskIndex = int.tryParse(params['nextTaskIndex'] ?? '') ?? 0;
    final isLastTask = params['isLastTask'] == 'true';
    final shouldContinueAutoPlay = params['shouldContinueAutoPlay'] == 'true';
    
    _isNotificationReturning = true;
    
    // 完了したタスクを記録
    if (completedTaskIndex >= 0 && completedTaskIndex < _playingTasks.length) {
      final completedTask = _playingTasks[completedTaskIndex];
      
      await _taskCompletionService.recordTaskCompletion(
        taskId: completedTask.id,
        taskTitle: completedTask.title,
        wasSuccessful: true,
        elapsedSeconds: completedTask.duration * 60,
        albumType: _isPlayingSingleAlbum ? 'single' : 'life_dream',
        albumName: _isPlayingSingleAlbum && _playingSingleAlbum != null 
            ? _playingSingleAlbum!.albumName 
            : _currentIdealSelf,
        albumId: _isPlayingSingleAlbum && _playingSingleAlbum != null 
            ? _playingSingleAlbum!.id 
            : null,
      );
      
      setState(() {
        _todayTaskCompletions[completedTask.id] = (_todayTaskCompletions[completedTask.id] ?? 0) + 1;
      });
    }
    
    if (isLastTask) {
      // 最後のタスク完了
      await _handleAutoPlayAlbumCompletion(completedTaskIndex);
    } else if (shouldContinueAutoPlay && nextTaskIndex < _playingTasks.length) {
      // 次のタスクを自動開始
      final pageIndex = _isPlayingSingleAlbum ? nextTaskIndex : nextTaskIndex + 1;
      
      setState(() {
        _currentTaskIndex = nextTaskIndex;
        _forcePlayerPageIndex = pageIndex;
        _elapsedSeconds = 0;
        _currentProgress = 0.0;
        _isPlaying = true;  // 重要：自動再生継続
        _isAutoPlayEnabled = true;
        _isPlayerScreenVisible = false;  // バックグラウンドの場合は表示しない
        
        // タスク開始時刻を記録
        _taskStartTime = DateTime.now();
        _pauseStartTime = null;
        _totalPausedSeconds = 0;
      });
      
      // プログレスタイマーを開始（アプリがフォアグラウンドの場合のみ）
      if (!_isPlayerScreenVisible) {
        // バックグラウンドで次のタスクの通知をスケジュール
        _scheduleAutoPlayTaskNotifications();
      } else {
        _startProgressTimer();
      }
      
      print('自動再生: タスク${nextTaskIndex}を開始しました');
    }
    
  } catch (e) {
    print('自動再生タスク通知処理エラー: $e');
  }
}
// タスク切り替えの実行
Future<void> _executeTaskTransition(int completedTaskIndex, int nextTaskIndex, int sessionStartTime) async {
  try {
    // 完了したタスクを記録
    if (completedTaskIndex >= 0 && completedTaskIndex < _playingTasks.length) {
      final completedTask = _playingTasks[completedTaskIndex];
      
      await _taskCompletionService.recordTaskCompletion(
        taskId: completedTask.id,
        taskTitle: completedTask.title,
        wasSuccessful: true,
        elapsedSeconds: completedTask.duration * 60,
        albumType: _isPlayingSingleAlbum ? 'single' : 'life_dream',
        albumName: _isPlayingSingleAlbum && _playingSingleAlbum != null 
            ? _playingSingleAlbum!.albumName 
            : _currentIdealSelf,
        albumId: _isPlayingSingleAlbum && _playingSingleAlbum != null 
            ? _playingSingleAlbum!.id 
            : null,
      );
      
      setState(() {
        _todayTaskCompletions[completedTask.id] = (_todayTaskCompletions[completedTask.id] ?? 0) + 1;
      });
    }
    
    // 次のタスクの状態に設定
    if (nextTaskIndex < _playingTasks.length) {
      final pageIndex = _isPlayingSingleAlbum ? nextTaskIndex : nextTaskIndex + 1;
      
      setState(() {
        _currentTaskIndex = nextTaskIndex;
        _forcePlayerPageIndex = pageIndex;
        _elapsedSeconds = 0;
        _currentProgress = 0.0;
        _isPlaying = true;
        _isAutoPlayEnabled = true;
        _isPlayerScreenVisible = true;
      });
      
      _startNewTask();
      _startProgressTimer();
      
      // PlayerScreenに状態を通知
      _onPlayerStateChanged(
        currentTaskIndex: nextTaskIndex,
        isPlaying: true,
        progress: 0.0,
        elapsedSeconds: 0,
        isAutoPlayEnabled: true,
        forcePageChange: pageIndex,
      );
      
      print('タスク切り替え完了: ${completedTaskIndex} → ${nextTaskIndex}');
      
      // 次のタスクの通知もスケジュール
      await _scheduleAutoPlayTaskNotifications();
    }
    
  } catch (e) {
    print('タスク切り替え実行エラー: $e');
  }
}

// 🆕 自動再生アルバム完了処理
Future<void> _handleAutoPlayAlbumCompletion(int finalTaskIndex) async {
  try {
    _isNotificationReturning = true;
    
    // 最後のタスクの完了状態に設定
    final lastPageIndex = _isPlayingSingleAlbum ? finalTaskIndex : finalTaskIndex + 1;
    
    setState(() {
      _currentTaskIndex = finalTaskIndex;
      _forcePlayerPageIndex = lastPageIndex;
      _isPlaying = false;
      _isAutoPlayEnabled = false;
      _elapsedSeconds = _playingTasks[finalTaskIndex].duration * 60;
      _currentProgress = 1.0;
      _isPlayerScreenVisible = true;
    });
    
    // PlayerScreenに完了状態を通知
    _onPlayerStateChanged(
      currentTaskIndex: finalTaskIndex,
      isPlaying: false,
      progress: 1.0,
      elapsedSeconds: _playingTasks[finalTaskIndex].duration * 60,
      isAutoPlayEnabled: false,
      forcePageChange: lastPageIndex,
    );
    
    await _loadUserData();
    
    // アルバム完了申告ダイアログを表示
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        _showAlbumCompletionDialog();
      }
    });
    
    print('✅ 自動再生アルバム完了処理完了');
    
  } catch (e) {
    print('❌ 自動再生アルバム完了処理エラー: $e');
  }
}

// 🆕 時刻ベースの状態復元
Future<void> _handleAutoPlayTaskTransition(int completedTaskIndex, int startTimeMs) async {
  try {
    _isNotificationReturning = true;
    
    // 開始時刻から現在いるべき状態を計算
    final startTime = DateTime.fromMillisecondsSinceEpoch(startTimeMs);
    final elapsedTime = DateTime.now().difference(startTime);
    
    // どのタスクにいるべきか計算
    int currentTaskIndex = -1;
    int currentElapsedSeconds = 0;
    int cumulativeSeconds = 0;
    
    for (int i = (_isPlayingSingleAlbum ? 0 : -1); i < _playingTasks.length; i++) {
      final taskDuration = i == -1 ? 0 : _playingTasks[i].duration * 60;
      
      if (elapsedTime.inSeconds <= cumulativeSeconds + taskDuration) {
        currentTaskIndex = i;
        currentElapsedSeconds = elapsedTime.inSeconds - cumulativeSeconds;
        break;
      }
      
      cumulativeSeconds += taskDuration;
    }
    
    // 計算結果でアプリ状態を更新
    final pageIndex = _isPlayingSingleAlbum ? currentTaskIndex : currentTaskIndex + 1;
    
    setState(() {
      _currentTaskIndex = currentTaskIndex;
      _elapsedSeconds = currentElapsedSeconds;
      _currentProgress = currentTaskIndex >= 0 && currentTaskIndex < _playingTasks.length
          ? currentElapsedSeconds / (_playingTasks[currentTaskIndex].duration * 60)
          : 0.0;
      _isPlaying = true;
      _isAutoPlayEnabled = true;
      _forcePlayerPageIndex = pageIndex;
      _isPlayerScreenVisible = true;
    });
    
    _startNewTask();
    _startProgressTimer();
    
    // PlayerScreenに状態を通知
    _onPlayerStateChanged(
      currentTaskIndex: currentTaskIndex,
      isPlaying: true,
      progress: _currentProgress,
      elapsedSeconds: currentElapsedSeconds,
      isAutoPlayEnabled: true,
      forcePageChange: pageIndex,
    );
    
    print('✅ 時刻ベース状態復元完了: タスク${currentTaskIndex + 1}, 経過${currentElapsedSeconds}秒');
    
  } catch (e) {
    print('❌ 時刻ベース状態復元エラー: $e');
  }
}




// 自動再生通知の処理
Future<void> _handleAutoPlayNotification(Map<String, String> params) async {
  print('🎯 自動再生通知を処理');
  
  _isNotificationReturning = true;
  
  final taskIndex = int.tryParse(params['taskIndex'] ?? '') ?? 0;
  final isLastTask = params['isLastTask'] == 'true';
  final completedTaskIdsStr = params['completedTaskIds'] ?? '';
  final completedTaskIds = completedTaskIdsStr.split(',').where((id) => id.isNotEmpty).toList();
  final isSingleAlbum = params['isSingleAlbum'] == 'true';
  
  print('📍 タスクインデックス: $taskIndex');
  print('📍 最後のタスク: $isLastTask');
  print('📍 完了タスク数: ${completedTaskIds.length}');
  
  // 完了タスクを記録
  for (final taskId in completedTaskIds) {
    for (final task in _playingTasks) {
      if (task.id == taskId) {
        final count = _todayTaskCompletions[task.id] ?? 0;
        if (count == 0) {
          await _taskCompletionService.recordTaskCompletion(
            taskId: task.id,
            taskTitle: task.title,
            wasSuccessful: true,
            elapsedSeconds: task.duration * 60,
            albumType: isSingleAlbum ? 'single' : 'life_dream',
            albumName: params['albumName'] ?? _currentIdealSelf,
            albumId: isSingleAlbum && _playingSingleAlbum != null 
                ? _playingSingleAlbum!.id 
                : null,
          );
          
          setState(() {
            _todayTaskCompletions[task.id] = 1;
          });
        }
        break;
      }
    }
  }
  
  if (isLastTask) {
    // 最後のタスク完了状態
    final pageIndex = isSingleAlbum ? taskIndex : taskIndex + 1;
    
    setState(() {
      _currentTaskIndex = taskIndex;
      _forcePlayerPageIndex = pageIndex;
      _isPlaying = false;
      _isAutoPlayEnabled = false;
      _elapsedSeconds = _playingTasks[taskIndex].duration * 60;
      _currentProgress = 1.0;
      _isPlayerScreenVisible = true;
    });
    
    // アルバム完了ダイアログ
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _showAlbumCompletionDialog();
    });
    
  } else {
    // 次のタスク開始状態
    final nextIndex = taskIndex + 1;
    final pageIndex = isSingleAlbum ? nextIndex : nextIndex + 1;
    
    setState(() {
      _currentTaskIndex = nextIndex;
      _forcePlayerPageIndex = pageIndex;
      _isPlaying = true;
      _isAutoPlayEnabled = true;
      _elapsedSeconds = 0;
      _currentProgress = 0.0;
      _isPlayerScreenVisible = true;
    });
    
    _startNewTask();
    _startProgressTimer();
  }
  
  // PlayerScreenに通知
  _onPlayerStateChanged(
    currentTaskIndex: _currentTaskIndex,
    isPlaying: _isPlaying,
    progress: _currentProgress,
    elapsedSeconds: _elapsedSeconds,
    isAutoPlayEnabled: _isAutoPlayEnabled,
    forcePageChange: _forcePlayerPageIndex,
  );
}

// 通常モード通知の処理（既存維持）
Future<void> _handleNormalModeNotification(Map<String, String> params) async {
  print('📱 通常モード通知を処理');
  
  final taskIndex = int.tryParse(params['taskIndex'] ?? '') ?? 0;
  final pageIndex = _isPlayingSingleAlbum ? taskIndex : taskIndex + 1;
  
  setState(() {
    _currentTaskIndex = taskIndex;
    _forcePlayerPageIndex = pageIndex;
    _elapsedSeconds = _playingTasks[taskIndex].duration * 60;
    _currentProgress = 1.0;
    _isPlaying = false;
    _isPlayerScreenVisible = true;
  });
  
  // タスク完了ダイアログ
  Future.delayed(const Duration(milliseconds: 500), () {
    if (mounted && taskIndex < _playingTasks.length) {
      _showTaskCompletionDialogInApp(
        _playingTasks[taskIndex],
        _currentIdealSelf,
        _playingTasks[taskIndex].duration * 60,
      );
    }
  });
}
// 新しいヘルパーメソッド
Future<void> _setAlbumCompletedState(List<String> completedTasks) async {
  // 完了タスクを記録
  for (final taskId in completedTasks) {
    for (final task in _playingTasks) {
      if (task.id == taskId) {
        final count = _todayTaskCompletions[task.id] ?? 0;
        if (count == 0) {
          await _recordTaskCompletion(task, true);
        }
        break;
      }
    }
  }
  
  // 最後のタスクの完了状態に設定
  final lastIndex = _playingTasks.length - 1;
  final lastPageIndex = _isPlayingSingleAlbum ? lastIndex : lastIndex + 1;
  
  setState(() {
    _currentTaskIndex = lastIndex;
    _forcePlayerPageIndex = lastPageIndex;
    _isPlaying = false;
    _isAutoPlayEnabled = false;
    _elapsedSeconds = _playingTasks[lastIndex].duration * 60;
    _currentProgress = 1.0;
    _isPlayerScreenVisible = true;
  });
  
  // PlayerScreenに通知
  _onPlayerStateChanged(
    currentTaskIndex: lastIndex,
    isPlaying: false,
    progress: 1.0,
    elapsedSeconds: _playingTasks[lastIndex].duration * 60,
    isAutoPlayEnabled: false,
    forcePageChange: lastPageIndex,
  );
  
  // ダイアログ表示
  Future.delayed(const Duration(milliseconds: 1000), () {
    if (mounted) _showAlbumCompletionDialog();
  });
}

Future<void> _setTaskProgressState(int taskIndex, List<String> completedTasks) async {
  // 完了タスクを記録
  for (final taskId in completedTasks) {
    for (final task in _playingTasks) {
      if (task.id == taskId) {
        final count = _todayTaskCompletions[task.id] ?? 0;
        if (count == 0) {
          await _recordTaskCompletion(task, true);
        }
        break;
      }
    }
  }
  
  // 次のタスクの開始状態に設定
  final nextIndex = taskIndex < _playingTasks.length - 1 ? taskIndex + 1 : taskIndex;
  final pageIndex = _isPlayingSingleAlbum ? nextIndex : nextIndex + 1;
  
  setState(() {
    _currentTaskIndex = nextIndex;
    _forcePlayerPageIndex = pageIndex;
    _isPlaying = true;
    _isAutoPlayEnabled = true;
    _elapsedSeconds = 0;
    _currentProgress = 0.0;
    _isPlayerScreenVisible = true;
  });
  
  _startNewTask();
  _startProgressTimer();
  
  // PlayerScreenに通知
  _onPlayerStateChanged(
    currentTaskIndex: nextIndex,
    isPlaying: true,
    progress: 0.0,
    elapsedSeconds: 0,
    isAutoPlayEnabled: true,
    forcePageChange: pageIndex,
  );
}

Future<void> _recordTaskCompletion(TaskItem task, bool wasSuccessful) async {
  try {
    final albumType = _isPlayingSingleAlbum ? 'single' : 'life_dream';
    final albumId = _isPlayingSingleAlbum && _playingSingleAlbum != null 
        ? _playingSingleAlbum!.id 
        : null;
    final albumName = _isPlayingSingleAlbum && _playingSingleAlbum != null 
        ? _playingSingleAlbum!.albumName 
        : _currentIdealSelf;

    await _taskCompletionService.recordTaskCompletion(
      taskId: task.id,
      taskTitle: task.title,
      wasSuccessful: wasSuccessful,
      elapsedSeconds: task.duration * 60,
      albumType: albumType,
      albumName: albumName,
      albumId: albumId,
    );
    
    // 既存メソッドの変更 - 以下の部分のみ変更
if (wasSuccessful) {
  await _audioService.playAchievementSound();
  setState(() {
    _todayTaskCompletions[task.id] = (_todayTaskCompletions[task.id] ?? 0) + 1;
  });
  
  // この行を追加
  await _notifyChartsScreenOfCompletion();
} else {
  await _audioService.playNotificationSound();
}
    
    print('✅ タスク完了記録: ${task.title} (成功: $wasSuccessful)');
  } catch (e) {
    print('❌ タスク完了記録エラー: $e');
  }
}

// main_wrapper.dart に追加

Future<void> _handleDetailedBackgroundAlbumCompletion(Map<String, String> payloadData) async {
  try {
    print('🎉 詳細バックグラウンドアルバム完了処理開始');
    
    _isNotificationReturning = true;
    
    // ペイロードから完全な状態を復元
    final completedTaskIdsStr = payloadData['completedTaskIds'] ?? '';
    final completedTaskIds = completedTaskIdsStr.split(',').where((id) => id.isNotEmpty).toList();
    
    // 最後のタスクのインデックスと状態を設定
    final lastTaskIndex = _playingTasks.length - 1;
    final lastPageIndex = _isPlayingSingleAlbum ? lastTaskIndex : lastTaskIndex + 1;
    
    // すべての完了タスクを記録（重複記録を防ぐ）
    for (final taskId in completedTaskIds) {
      final taskIndex = _playingTasks.indexWhere((t) => t.id == taskId);
      if (taskIndex >= 0) {
        final task = _playingTasks[taskIndex];
        
        // 今日の完了回数をチェックして重複を防ぐ
        final currentCount = _todayTaskCompletions[task.id] ?? 0;
        if (currentCount == 0) {
          await _taskCompletionService.recordTaskCompletion(
            taskId: task.id,
            taskTitle: task.title,
            wasSuccessful: true,
            elapsedSeconds: task.duration * 60,
            albumType: _isPlayingSingleAlbum ? 'single' : 'life_dream',
            albumName: _isPlayingSingleAlbum && _playingSingleAlbum != null 
                ? _playingSingleAlbum!.albumName 
                : _currentIdealSelf,
            albumId: _isPlayingSingleAlbum && _playingSingleAlbum != null 
                ? _playingSingleAlbum!.id 
                : null,
          );
          
          setState(() {
            _todayTaskCompletions[task.id] = 1;
          });
        }
      }
    }
    
    // アプリ状態を完全な最終状態に設定
    setState(() {
      _isPlaying = false;
      _isAutoPlayEnabled = false;
      _currentTaskIndex = lastTaskIndex;
      _forcePlayerPageIndex = lastPageIndex;
      _elapsedSeconds = _playingTasks[lastTaskIndex].duration * 60;
      _currentProgress = 1.0;
      _isPlayerScreenVisible = true;
    });
    
    // PlayerScreenに完了状態を通知
    _onPlayerStateChanged(
      currentTaskIndex: lastTaskIndex,
      isPlaying: false,
      progress: 1.0,
      elapsedSeconds: _playingTasks[lastTaskIndex].duration * 60,
      isAutoPlayEnabled: false,
      forcePageChange: lastPageIndex,
    );
    
    await _loadUserData();
    
    // アルバム完了ダイアログを表示
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        _showAlbumCompletionDialog();
      }
    });
    
    print('✅ 詳細バックグラウンドアルバム完了処理完了');
    
  } catch (e) {
    print('❌ 詳細バックグラウンドアルバム完了処理エラー: $e');
  }
}

Future<void> _handleDetailedBackgroundAutoPlayProgress(Map<String, String> payloadData) async {
  try {
    print('🔄 詳細バックグラウンド自動再生進行処理開始');
    
    _isNotificationReturning = true;
    
    // ペイロードから状態を復元
    final currentTaskIndex = int.tryParse(payloadData['currentTaskIndex'] ?? '') ?? 0;
    final completedTaskIdsStr = payloadData['completedTaskIds'] ?? '';
    final completedTaskIds = completedTaskIdsStr.split(',').where((id) => id.isNotEmpty).toList();
    
    // 完了済みタスクを記録（重複記録を防ぐ）
    for (final taskId in completedTaskIds) {
      final taskIndex = _playingTasks.indexWhere((t) => t.id == taskId);
      if (taskIndex >= 0 && taskIndex < currentTaskIndex) {
        final task = _playingTasks[taskIndex];
        
        final currentCount = _todayTaskCompletions[task.id] ?? 0;
        if (currentCount == 0) {
          await _taskCompletionService.recordTaskCompletion(
            taskId: task.id,
            taskTitle: task.title,
            wasSuccessful: true,
            elapsedSeconds: task.duration * 60,
            albumType: _isPlayingSingleAlbum ? 'single' : 'life_dream',
            albumName: _isPlayingSingleAlbum && _playingSingleAlbum != null 
                ? _playingSingleAlbum!.albumName 
                : _currentIdealSelf,
            albumId: _isPlayingSingleAlbum && _playingSingleAlbum != null 
                ? _playingSingleAlbum!.id 
                : null,
          );
          
          setState(() {
            _todayTaskCompletions[task.id] = 1;
          });
        }
      }
    }
    
    // 現在のタスクの正しい状態に設定
    final pageIndex = _isPlayingSingleAlbum ? currentTaskIndex : currentTaskIndex + 1;
    
    setState(() {
      _currentTaskIndex = currentTaskIndex;
      _forcePlayerPageIndex = pageIndex;
      _elapsedSeconds = 0;
      _currentProgress = 0.0;
      _isPlaying = true;
      _isAutoPlayEnabled = true;
      _isPlayerScreenVisible = true;
    });
    
    _startNewTask();
    _startProgressTimer();
    
    _onPlayerStateChanged(
      currentTaskIndex: currentTaskIndex,
      isPlaying: true,
      progress: 0.0,
      elapsedSeconds: 0,
      isAutoPlayEnabled: true,
      forcePageChange: pageIndex,
    );
    
    await _loadUserData();
    
    print('✅ 詳細バックグラウンド自動再生進行処理完了');
    
  } catch (e) {
    print('❌ 詳細バックグラウンド自動再生進行処理エラー: $e');
  }
}

// main_wrapper.dart の _handleBackgroundAlbumCompletionNotificationTap を修正

Future<void> _handleBackgroundAlbumCompletionNotificationTap(Map<String, String> payloadData) async {
  try {
    print('🎉 バックグラウンドアルバム完了通知処理開始');
    
    _isNotificationReturning = true;
    
    // ペイロードから完全な状態を復元
    final currentTaskIndex = int.tryParse(payloadData['currentTaskIndex'] ?? '') ?? _playingTasks.length - 1;
    final totalElapsedSeconds = int.tryParse(payloadData['totalElapsedSeconds'] ?? '0') ?? 0;
    final completedTaskIdsStr = payloadData['completedTaskIds'] ?? '';
    final completedTaskIds = completedTaskIdsStr.split(',').where((id) => id.isNotEmpty).toSet();
    
    // 最後のタスクが実際に完了した状態に設定
    final lastTaskIndex = _playingTasks.length - 1;
    final lastPageIndex = _isPlayingSingleAlbum ? lastTaskIndex : lastTaskIndex + 1;
    
    // 完了したタスクを全て記録
    for (int i = 0; i <= lastTaskIndex; i++) {
      final task = _playingTasks[i];
      if (completedTaskIds.contains(task.id)) {
        // このタスクは既に完了済みとして記録
        await _taskCompletionService.recordTaskCompletion(
          taskId: task.id,
          taskTitle: task.title,
          wasSuccessful: true,
          elapsedSeconds: task.duration * 60,
          albumType: _isPlayingSingleAlbum ? 'single' : 'life_dream',
          albumName: _isPlayingSingleAlbum && _playingSingleAlbum != null 
              ? _playingSingleAlbum!.albumName 
              : _currentIdealSelf,
          albumId: _isPlayingSingleAlbum && _playingSingleAlbum != null 
              ? _playingSingleAlbum!.id 
              : null,
        );
        
        setState(() {
          _todayTaskCompletions[task.id] = (_todayTaskCompletions[task.id] ?? 0) + 1;
        });
      }
    }
    
    // アプリ状態を完全な最終状態に設定
    setState(() {
      _isPlaying = false;
      _isAutoPlayEnabled = false;
      _currentTaskIndex = lastTaskIndex;
      _forcePlayerPageIndex = lastPageIndex;
      _elapsedSeconds = _playingTasks[lastTaskIndex].duration * 60;  // 最後のタスクの完了時間
      _currentProgress = 1.0;
      _isPlayerScreenVisible = true;
    });
    
    // PlayerScreenに完了状態を通知
    _onPlayerStateChanged(
      currentTaskIndex: lastTaskIndex,
      isPlaying: false,
      progress: 1.0,
      elapsedSeconds: _playingTasks[lastTaskIndex].duration * 60,
      isAutoPlayEnabled: false,
      forcePageChange: lastPageIndex,
    );
    
    await _loadUserData();
    
    // アルバム完了ダイアログを表示
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _showAlbumCompletionDialog();
      }
    });
    
  } catch (e) {
    print('❌ バックグラウンドアルバム完了通知処理エラー: $e');
  }
}



// main_wrapper.dart の _handleBackgroundAutoPlayProgressNotificationTap を修正

Future<void> _handleBackgroundAutoPlayProgressNotificationTap(Map<String, String> payloadData) async {
  try {
    _isNotificationReturning = true;
    
    // ペイロードから状態を復元
    final currentTaskIndex = int.tryParse(payloadData['currentTaskIndex'] ?? '') ?? 0;
    final totalElapsedSeconds = int.tryParse(payloadData['totalElapsedSeconds'] ?? '0') ?? 0;
    final completedTaskIdsStr = payloadData['completedTaskIds'] ?? '';
    final completedTaskIds = completedTaskIdsStr.split(',').where((id) => id.isNotEmpty).toSet();
    
    // 完了済みタスクを記録
    for (final taskId in completedTaskIds) {
      final task = _playingTasks.firstWhere(
        (t) => t.id == taskId,
        orElse: () => throw StateError('Task not found'),
      );
      
      if (!_todayTaskCompletions.containsKey(taskId) || _todayTaskCompletions[taskId] == 0) {
        await _taskCompletionService.recordTaskCompletion(
          taskId: task.id,
          taskTitle: task.title,
          wasSuccessful: true,
          elapsedSeconds: task.duration * 60,
          albumType: _isPlayingSingleAlbum ? 'single' : 'life_dream',
          albumName: _isPlayingSingleAlbum && _playingSingleAlbum != null 
              ? _playingSingleAlbum!.albumName 
              : _currentIdealSelf,
          albumId: _isPlayingSingleAlbum && _playingSingleAlbum != null 
              ? _playingSingleAlbum!.id 
              : null,
        );
        
        setState(() {
          _todayTaskCompletions[task.id] = 1;
        });
      }
    }
    
    // 現在のタスクの正しい状態に設定
    final pageIndex = _isPlayingSingleAlbum ? currentTaskIndex : currentTaskIndex + 1;
    
    setState(() {
      _currentTaskIndex = currentTaskIndex;
      _forcePlayerPageIndex = pageIndex;
      _elapsedSeconds = 0;  // 現在のタスクは開始直後
      _currentProgress = 0.0;
      _isPlaying = true;
      _isAutoPlayEnabled = true;
      _isPlayerScreenVisible = true;
    });
    
    _startNewTask();
    _startProgressTimer();
    
    _onPlayerStateChanged(
      currentTaskIndex: currentTaskIndex,
      isPlaying: true,
      progress: 0.0,
      elapsedSeconds: 0,
      isAutoPlayEnabled: true,
      forcePageChange: pageIndex,
    );
    
    await _loadUserData();
    
  } catch (e) {
    print('❌ バックグラウンド進行通知処理エラー: $e');
  }
}

Future<void> _handleNormalNotification(Map<String, String> params) async {
  print('📱 通常モード通知を処理');
  
  final taskIndex = int.tryParse(params['taskIndex'] ?? '') ?? 0;
  
  setState(() {
    _currentTaskIndex = taskIndex;
    _forcePlayerPageIndex = _isPlayingSingleAlbum ? taskIndex : taskIndex + 1;
    _elapsedSeconds = _playingTasks[taskIndex].duration * 60;
    _currentProgress = 1.0;
    _isPlaying = false;
    _isPlayerScreenVisible = true;
  });
  
  // タスク完了ダイアログを表示
  Future.delayed(const Duration(milliseconds: 500), () {
    if (mounted && taskIndex < _playingTasks.length) {
      _showTaskCompletionDialogInApp(
        _playingTasks[taskIndex],
        _currentIdealSelf,
        _playingTasks[taskIndex].duration * 60,
      );
    }
  });
}

// バックグラウンドタスク完了通知タップ処理（通常モード用）
Future<void> _handleBackgroundTaskCompletedNotificationTap(Map<String, String> payloadData) async {
  try {
    print('🔧 バックグラウンドタスク完了通知処理開始');
    
    // 通知からの復帰フラグを設定
    _isNotificationReturning = true;
    
    final taskId = payloadData['taskId'];
    final taskTitle = payloadData['taskTitle'];
    final albumName = payloadData['albumName'];
    final albumType = payloadData['albumType'];
    final albumId = payloadData['albumId'];
    final elapsedSeconds = int.tryParse(payloadData['elapsedSeconds'] ?? '0') ?? 0;
    
    if (taskId == null || taskTitle == null) {
      print('❌ タスク情報が不足しているため処理をスキップ');
      return;
    }
    
    // 該当タスクのインデックスを見つける
    int taskIndex = -1;
    for (int i = 0; i < _playingTasks.length; i++) {
      if (_playingTasks[i].id == taskId) {
        taskIndex = i;
        break;
      }
    }
    
    if (taskIndex >= 0) {
      // 🔧 修正: 正しいページインデックスを計算
      final pageIndex = _isPlayingSingleAlbum ? taskIndex : taskIndex + 1;
      
      // 状態を適切に設定
      setState(() {
        _currentTaskIndex = taskIndex;
        _forcePlayerPageIndex = pageIndex; // 🔧 重要: ページインデックスを設定
        _elapsedSeconds = elapsedSeconds;
        _currentProgress = 1.0;
        _isPlaying = false;
        _isAutoPlayEnabled = false;
        _isPlayerScreenVisible = true;
      });
      
      print('🔧 通常モード: 該当タスクの完了状態に設定');
      print('🔍 設定値: taskIndex=$_currentTaskIndex, pageIndex=$_forcePlayerPageIndex');
      
      // PlayerScreenに状態を通知（forcePageChangeを含む）
      _onPlayerStateChanged(
        currentTaskIndex: _currentTaskIndex,
        isPlaying: false,
        progress: 1.0,
        elapsedSeconds: elapsedSeconds,
        isAutoPlayEnabled: false,
        forcePageChange: _forcePlayerPageIndex, // 🔧 重要: ページ変更を強制
      );
    }
    
    // 🔧 修正: PlayerScreenの更新完了を待ってからダイアログ表示
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _showPlayerWithCompletionDialog(
          taskId: taskId,
          taskTitle: taskTitle,
          albumName: albumName ?? '',
          albumType: albumType ?? 'life_dream',
          albumId: albumId,
          elapsedSeconds: elapsedSeconds,
        );
      }
    });
    
    print('✅ バックグラウンドタスク完了処理完了');
    
  } catch (e) {
    print('❌ バックグラウンドタスク完了処理エラー: $e');
  }
}

// バックグラウンドでのアルバム完了処理
void _handleBackgroundAlbumCompletion() {
  setState(() {
    _isPlaying = false;
    _isAutoPlayEnabled = false;
  });
  
  // バックグラウンドアルバム完了通知を送信
  Future.delayed(const Duration(milliseconds: 500), () {
    _notificationService.showNotification(
      id: 8000,
      title: 'アルバム完了！',
      body: '「${_isPlayingSingleAlbum && _playingSingleAlbum != null ? _playingSingleAlbum!.albumName : _currentIdealSelf}」のすべてのタスクが完了しました。アプリを開いて結果を確認してください。',
      payload: 'type=background_album_completed',
    );
  });
  
  print('✅ バックグラウンドアルバム完了処理完了');
}

  void _showPlayerWithCompletionDialog({
    required String taskId,
    required String taskTitle,
    required String albumName,
    required String albumType,
    String? albumId,
    required int elapsedSeconds,
  }) {
    setState(() {
      _isPlayerScreenVisible = true;
    });
    
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        TaskItem? targetTask;
        for (final task in _currentTasks) {
          if (task.id == taskId) {
            targetTask = task;
            break;
          }
        }
        
        if (targetTask != null) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => CompletionDialog(
              task: targetTask!,
              albumName: albumName,
              elapsedSeconds: elapsedSeconds,
              onYes: () async {
                Navigator.of(context).pop();
                await _taskCompletionService.recordTaskCompletionFromNotification(
                  taskId: taskId,
                  taskTitle: taskTitle,
                  albumName: albumName,
                  albumType: albumType,
                  albumId: albumId,
                  elapsedSeconds: elapsedSeconds,
                  wasSuccessful: true,
                );
                
                setState(() {
                  _todayTaskCompletions[taskId] = (_todayTaskCompletions[taskId] ?? 0) + 1;
                });
                
                await _loadUserData();
              },
              onNo: () async {
                Navigator.of(context).pop();
                await _taskCompletionService.recordTaskCompletionFromNotification(
                  taskId: taskId,
                  taskTitle: taskTitle,
                  albumName: albumName,
                  albumType: albumType,
                  albumId: albumId,
                  elapsedSeconds: elapsedSeconds,
                  wasSuccessful: false,
                );
              },
              onCancel: () {
                Navigator.of(context).pop();
              },
            ),
          );
        }
      }
    });
  }

  void _stopProgressTimer() {
  _progressTimer?.cancel();
  _progressTimer = null;
  
  // Live Activity終了処理（フラグのみリセット）
  _isActivityActive = false;
}

  void _resetProgress() {
    setState(() {
      _elapsedSeconds = 0;
      _currentProgress = 0.0;
    });
  }

  void _nextTask() {
    if (_playingTasks.isNotEmpty) {
      setState(() {
        _currentTaskIndex = (_currentTaskIndex + 1) % _playingTasks.length;
        _startNewTask();
        _resetProgress();
      });
    }
  }

  void _previousTask() {
    if (_playingTasks.isNotEmpty) {
      setState(() {
        _currentTaskIndex = _currentTaskIndex > 0 
            ? _currentTaskIndex - 1 
            : _playingTasks.length - 1;
        _startNewTask();
        _resetProgress();
      });
    }
  }


  @override
Widget build(BuildContext context) {
  if (_isCheckingFirstLaunch) {
    return _buildInitialLoadingScreen();
  }

  if (_shouldShowOnboarding) {
    return OnboardingWrapper(
      onCompleted: _onOnboardingCompleted,
    );
  }

  // 🔧 修正：Scaffoldの背景色を明示的に黒に設定
  return Scaffold(
    backgroundColor: Colors.black, // 🔧 追加
    body: Column(
      children: [
        Expanded(
          child: _buildCurrentScreen(),
        ),
        _buildBottomSection(),
      ],
    ),
  );
}

  Widget _buildArtistScreen() {
  return FutureBuilder<List<SingleAlbum>>(
    future: _dataService.loadSingleAlbums(),
    builder: (context, snapshot) {
      final singleAlbums = snapshot.data ?? [];
      
      print('🎤 アーティスト画面に渡すシングルアルバム数: ${singleAlbums.length}');
      for (final album in singleAlbums) {
        print('  - ${album.albumName}: ${album.tasks.length}タスク');
      }
      
      return ArtistScreen(
        artistName: _currentArtistName,
        profileImageBytes: _dataService.getSavedIdealImageBytes(),
        lifeDreamAlbumCoverImage: _imageBytes,
        tasks: _currentTasks,
        singleAlbums: singleAlbums,
        onClose: _hideArtistScreen,
        onPlayTask: (taskIndex) {
          _hideArtistScreen();
          Future.delayed(const Duration(milliseconds: 100), () {
            _showFullPlayerWithTask(taskIndex);
          });
        },
        onNavigateToAlbumDetail: (album) {
          _hideArtistScreen();
          Future.delayed(const Duration(milliseconds: 100), () {
            _showSingleAlbumDetail(album);
          });
        },
        onPlaySingleAlbumTask: (album, taskIndex) {
          _hideArtistScreen();
          Future.delayed(const Duration(milliseconds: 100), () {
            _showSingleAlbumPlayer(album, taskIndex: taskIndex);
          });
        },
        // 🆕 追加：ライフドリームアルバム詳細に遷移
        onNavigateToLifeDreamAlbumDetail: () {
          _hideArtistScreen();
          Future.delayed(const Duration(milliseconds: 100), () {
            _showAlbumDetail();
          });
        },
      );
    },
  );
}

  Widget _buildInitialLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Container(
          width: 140,
          height: 140,
          decoration: const BoxDecoration(
            color: Color(0xFF1DB954),
            shape: BoxShape.circle,
          ),
          child: Transform.rotate(
            angle: -1.5708,
            child: const Icon(
              Icons.play_arrow,
              size: 90,
              color: Colors.black,
            ),
          ),
        ),
      ),
    );
  }
}
