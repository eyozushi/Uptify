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
import 'package:palette_generator/palette_generator.dart';
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
import 'services/notification_coordinator.dart';
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
  String _currentIdealSelf = "Ideal Self";
  String _currentArtistName = "You";
  List<TaskItem> _currentTasks = [];
  String _currentAlbumImagePath = "";
  int _currentTaskIndex = 0;
  bool _isPlaying = false;
  double _currentProgress = 0.0;
  Timer? _progressTimer;
  int _elapsedSeconds = 0;
  


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

  // 🆕 追加：アルバム背景色
Color _currentAlbumColor = const Color(0xFF2D1B69); // デフォルト色
  
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

  // ✅ 追加
final NotificationCoordinator _notificationCoordinator = NotificationCoordinator();


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

  // 【既存メソッドの修正】initState() の該当部分
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

  // 既存メソッドの修正
void _onAppPaused() {
  print('🔧 アプリがバックグラウンドに移行開始');
  
  if (_isPlaying && _playingTasks.isNotEmpty) {
    _pauseStartTime = DateTime.now();
    
    
    // ✅ 追加
    _notificationCoordinator.pauseForTask();

    // ✅ 簡素化：通常モードのみ
    if (_currentTaskIndex >= 0) {
      print('🔔 通常モード: バックグラウンド通知をスケジュール');
      _scheduleBackgroundTaskCompletion();
    }
    
    print('🔧 アプリがバックグラウンドに移行完了');
  }
}

// 既存メソッドの修正（大幅簡素化）
void _onAppResumed() {
  if (_isNotificationReturning) {
    _isNotificationReturning = false;
    return;
  }

  
  // ✅ 簡素化：通常モードのみ
  if (_isPlaying && _playingTasks.isNotEmpty && _pauseStartTime != null) {
    final pauseDuration = DateTime.now().difference(_pauseStartTime!);
    _totalPausedSeconds += pauseDuration.inSeconds;
    
    if (_taskStartTime != null) {
      final totalElapsed = DateTime.now().difference(_taskStartTime!).inSeconds - _totalPausedSeconds;
      _updateCurrentTaskState(totalElapsed);
    }
    
    _pauseStartTime = null;
    
    // ✅ 追加
    _notificationCoordinator.resumeAfterTask();
    
    _cancelBackgroundTaskCompletion();
  }
}

// 既存メソッドの修正
void _updateCurrentTaskState(int elapsedInCurrentTask) {
  if (_currentTaskIndex < 0 || _currentTaskIndex >= _playingTasks.length) return;
  
  final currentTask = _playingTasks[_currentTaskIndex];
  final maxElapsed = currentTask.duration * 60;
  
  setState(() {
    _elapsedSeconds = elapsedInCurrentTask.clamp(0, maxElapsed - 1);
    _currentProgress = _elapsedSeconds / maxElapsed;
    _isPlaying = true;
    
    _taskStartTime = DateTime.now();
    _pauseStartTime = null;
    _totalPausedSeconds = 0;
  });
  
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) {
      _onPlayerStateChanged(
        currentTaskIndex: _currentTaskIndex,
        isPlaying: true,
        progress: _currentProgress,
        elapsedSeconds: _elapsedSeconds,
      );
      
      _startProgressTimer();
      
      print('バックグラウンド復帰: タスク${_currentTaskIndex + 1}継続 (${_elapsedSeconds}秒経過)');
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
      title: 'Task Complete',
      body: 'Time is up for "${currentTask.title}"',
      delay: Duration(seconds: remainingSeconds),
      payload: payload,
      withActions: true,
    );
    
    print('✅ 通常モード通知スケジュール成功: ID=$notificationId, ${remainingSeconds}秒後');
  } catch (e) {
    print('❌ 通常モード通知スケジュールエラー: $e');
  }
}

// 既存メソッドの修正（簡素化）
Future<void> _scheduleBackgroundTaskCompletion() async {
  print('🔧 バックグラウンド通知スケジュール開始');
  
  if (_currentTaskIndex == -1) {
    print('🔧 理想像ページのためスキップ');
    return;
  }
  
  
  // ✅ 簡素化：通常モードのみ
  await _scheduleNormalTaskCompletion();
}




// 既存メソッドの修正（簡素化）
Future<void> _cancelBackgroundTaskCompletion() async {
  
  // ✅ 簡素化：通常モードのみ
  await _notificationService.cancelNotification(
    AutoPlayNotificationSystem.normalTaskId(_currentTaskIndex)
  );
  print('✅ 通常モード通知をキャンセル');
}

// 通常モード用の通知（既存のものを簡略化）
Future<void> _scheduleNormalTaskNotification() async {
  if (_currentTaskIndex < 0 || _currentTaskIndex >= _playingTasks.length) return;
  
  final currentTask = _playingTasks[_currentTaskIndex];
  final remainingSeconds = (currentTask.duration * 60) - _elapsedSeconds;
  
  await _notificationService.scheduleDelayedNotification(
    id: 50000 + _currentTaskIndex,
    title: 'Task Complete',
    body: 'Time is up for "${currentTask.title}"',
    delay: Duration(seconds: remainingSeconds),
    payload: 'notification_type=NORMAL&taskIndex=$_currentTaskIndex',
    withActions: true,
  );
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
    
    // 🆕 追加: 古いReality Remaster写真をクリーンアップ
    await _dataService.cleanupOldRealityRemasterPhotos();
    
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
    
    // 🆕 追加: エラー時もクリーンアップを試行
    try {
      await _dataService.cleanupOldRealityRemasterPhotos();
    } catch (cleanupError) {
      print('❌ クリーンアップエラー: $cleanupError');
    }
    
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
    
    // 🔧 修正: 既存のカウントをバックアップ
    final existingCounts = Map<String, int>.from(_todayTaskCompletions);
    
    setState(() {
      _currentIdealSelf = data['idealSelf'] ?? 'Ideal Self';
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
    
    // 🔧 修正: ライフドリームアルバムのカウントのみ再読み込み
    final lifeDreamCompletions = <String, int>{};
    for (final task in _currentTasks) {
      final count = await _taskCompletionService.getTodayTaskSuccesses(task.id);
      lifeDreamCompletions[task.id] = count;
    }
    
    // 🔧 重要: 既存のカウント（シングルアルバム含む）を保持してマージ
    setState(() {
      _todayTaskCompletions = {
        ...existingCounts, // 既存のカウントを保持
        ...lifeDreamCompletions, // ライフドリームアルバムのカウントで上書き
      };
    });
    
    print('✅ _loadUserData完了: カウント保持 → $_todayTaskCompletions');
    
  } catch (e) {
    print('❌ ユーザーデータ読み込みエラー: $e');
    setState(() {
      _currentTasks = _dataService.getDefaultTasks();
    });
  }
}

// 【新規追加】_loadUserData() メソッドの直後に配置
/// 🆕 アルバムカバーから色を抽出
Future<void> _extractAlbumColor() async {
  try {
    ImageProvider? imageProvider;
    
    // シングルアルバム再生中の場合
    if (_isPlayingSingleAlbum && _playingSingleAlbum != null && _playingSingleAlbum!.albumCoverImage != null) {
      imageProvider = MemoryImage(_playingSingleAlbum!.albumCoverImage!);
    } 
    // ライフドリームアルバム再生中の場合
    else if (_imageBytes != null) {
      imageProvider = MemoryImage(_imageBytes!);
    } 
    else if (_currentAlbumImagePath.isNotEmpty && File(_currentAlbumImagePath).existsSync()) {
      imageProvider = FileImage(File(_currentAlbumImagePath));
    }
    
    if (imageProvider != null) {
      final PaletteGenerator paletteGenerator = await PaletteGenerator.fromImageProvider(
        imageProvider,
        size: const Size(200, 200),
        maximumColorCount: 16,
      );
      
      if (mounted) {
        Color selectedColor = const Color(0xFF2D1B69); // フォールバック
        
        // PlayerScreenと同じロジックで色を選択
        final List<PaletteColor> allColors = [
          if (paletteGenerator.vibrantColor != null) paletteGenerator.vibrantColor!,
          if (paletteGenerator.lightVibrantColor != null) paletteGenerator.lightVibrantColor!,
          if (paletteGenerator.darkVibrantColor != null) paletteGenerator.darkVibrantColor!,
          if (paletteGenerator.mutedColor != null) paletteGenerator.mutedColor!,
          if (paletteGenerator.lightMutedColor != null) paletteGenerator.lightMutedColor!,
          if (paletteGenerator.darkMutedColor != null) paletteGenerator.darkMutedColor!,
          if (paletteGenerator.dominantColor != null) paletteGenerator.dominantColor!,
        ];
        
        if (allColors.isNotEmpty) {
          // 最初の鮮やかな色を選択（簡略版）
          selectedColor = allColors.first.color;
        }
        
        setState(() {
          _currentAlbumColor = selectedColor;
        });
        
        print('🎨 簡易プレイヤー背景色抽出完了: $selectedColor');
      }
    }
  } catch (e) {
    print('❌ 簡易プレイヤー色抽出エラー: $e');
  }
}

  // 既存メソッドの修正
void _onPlayerStateChanged({
  int? currentTaskIndex,
  bool? isPlaying,
  double? progress,
  int? elapsedSeconds,
  int? forcePageChange, 
  Color? albumColor,
}) {
  print('🔧 MainWrapper: PlayerScreenから状態変更受信');
  
  bool shouldUpdate = false;
  
  if (currentTaskIndex != null && _currentTaskIndex != currentTaskIndex) {
    _currentTaskIndex = currentTaskIndex;
    shouldUpdate = true;
    print('🔧 タスクインデックス更新: $_currentTaskIndex');
  }
  
  if (isPlaying != null && _isPlaying != isPlaying) {
    if (!_isPlaying && isPlaying) {
      _isPlaying = true;
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
  
  // ❌ 削除：自動再生状態管理（約10行削除）
  
  if (shouldUpdate) {
    setState(() {});
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



  // 【既存メソッドの修正】
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
  
  _playerDragController.value = 0.0;
  
  // 🆕 追加：色を抽出
  _extractAlbumColor();
}

  // 【既存メソッドの修正】
void _showFullPlayerWithTask(int taskIndex) {
  _stopProgressTimer();
  
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
    
    // 🆕 追加：色を抽出
    _extractAlbumColor();
  });
}

  // 【既存メソッドの修正】（該当部分のみ）
void _showSingleAlbumPlayer(SingleAlbum album, {int taskIndex = 0}) async {
  _stopProgressTimer();
  
  print('🎵 シングルアルバムプレイヤー開始: ${album.albumName}, タスクインデックス: $taskIndex');
  
  final latestAlbum = await _dataService.getSingleAlbum(album.id);
  final albumToPlay = latestAlbum ?? album;
  
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
  
  // 🆕 追加：色を抽出
  _extractAlbumColor();
  
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


  // 【既存メソッドの修正】
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
  
  if (_currentSingleAlbum != null) {
    setState(() {
      _isAlbumDetailVisible = true;
    });
    print('🔙 アルバム詳細画面に戻ります: ${_currentSingleAlbum!.albumName}');
  }
}

/// 🆕 新規追加：アルバム画像から色を事前抽出
Future<Color> _extractColorFromAlbum({
  Uint8List? imageBytes,
  String? imagePath,
}) async {
  try {
    ImageProvider? imageProvider;
    
    if (imageBytes != null) {
      imageProvider = MemoryImage(imageBytes);
    } else if (imagePath != null && imagePath.isNotEmpty && File(imagePath).existsSync()) {
      imageProvider = FileImage(File(imagePath));
    }
    
    if (imageProvider == null) {
      return Colors.black;
    }
    
    final PaletteGenerator paletteGenerator = await PaletteGenerator.fromImageProvider(
      imageProvider,
      size: const Size(200, 200),
      maximumColorCount: 16,
    );
    
    double getSaturation(Color color) {
      final r = color.red / 255.0;
      final g = color.green / 255.0;
      final b = color.blue / 255.0;
      
      final max = [r, g, b].reduce((a, b) => a > b ? a : b);
      final min = [r, g, b].reduce((a, b) => a < b ? a : b);
      
      if (max == 0) return 0;
      return (max - min) / max;
    }
    
    double scoreColor(PaletteColor paletteColor) {
      final color = paletteColor.color;
      final population = paletteColor.population;
      final saturation = getSaturation(color);
      final luminance = color.computeLuminance();
      
      double score = 0;
      
      if (population < 100) {
        score -= 500;
      } else if (population < 500) {
        score -= 100;
      } else if (population > 2000) {
        score += 150;
      } else {
        score += 50;
      }
      
      if (saturation > 0.4) {
        score += 300;
      } else if (saturation > 0.25) {
        score += 150;
      } else if (saturation < 0.15) {
        score -= 400;
      }
      
      if (luminance < 0.1) {
        score -= 200;
      } else if (luminance > 0.85) {
        score -= 300;
      } else if (luminance >= 0.2 && luminance <= 0.6) {
        score += 100;
      }
      
      if (saturation > 0.3 && population > 1000) {
        score += 200;
      }
      
      final hue = HSLColor.fromColor(color).hue;
      if ((hue >= 0 && hue <= 30) ||
          (hue >= 180 && hue <= 240) ||
          (hue >= 270 && hue <= 330)) {
        score += 50;
      }
      
      return score;
    }
    
    final List<PaletteColor> allColors = [
      if (paletteGenerator.vibrantColor != null) paletteGenerator.vibrantColor!,
      if (paletteGenerator.lightVibrantColor != null) paletteGenerator.lightVibrantColor!,
      if (paletteGenerator.darkVibrantColor != null) paletteGenerator.darkVibrantColor!,
      if (paletteGenerator.mutedColor != null) paletteGenerator.mutedColor!,
      if (paletteGenerator.lightMutedColor != null) paletteGenerator.lightMutedColor!,
      if (paletteGenerator.darkMutedColor != null) paletteGenerator.darkMutedColor!,
      if (paletteGenerator.dominantColor != null) paletteGenerator.dominantColor!,
    ];
    
    if (allColors.isEmpty) {
      return Colors.black;
    }
    
    PaletteColor bestColor = allColors[0];
    double bestScore = scoreColor(bestColor);
    
    for (final paletteColor in allColors) {
      final score = scoreColor(paletteColor);
      if (score > bestScore) {
        bestScore = score;
        bestColor = paletteColor;
      }
    }
    
    return bestColor.color;
  } catch (e) {
    print('❌ 色抽出エラー: $e');
    return Colors.black;
  }
}

  void _showAlbumDetail() async { // async追加
  // 🆕 追加：色抽出完了まで待機（HomeScreenで実行済み）
  await Future.delayed(const Duration(milliseconds: 100));
  
  setState(() {
    _currentSingleAlbum = null;
    _isAlbumDetailVisible = true;
  });
}

  // 🔧 修正：遷移前に少し待機
void _showSingleAlbumDetail(SingleAlbum album) async { // async追加
  // 🆕 追加：色抽出完了まで待機（HomeScreenで実行済み）
  await Future.delayed(const Duration(milliseconds: 100));
  
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
                      '\"${updatedAlbum.albumName}\"を更新しました！',
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
              content: Text('Failed to update album'),
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
                  '\"${album.albumName}\"を削除しました',
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
                  'Failed to delete album',
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
                  '\"${album.albumName}\"をリリースしました！',
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
          content: Text('Failed to save album'),
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

// 既存メソッドの修正（タイマーコールバック内の条件分岐を簡素化）
void _startProgressTimer() {
  _stopProgressTimer();
  
  if (_playingTasks.isEmpty) {
    print('🔧 タイマー停止: playingTasksが空');
    return;
  }
  
  if (!_isActivityActive) {
    _isActivityActive = true;
  }
  
  _progressTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
    if (_playingTasks.isEmpty) {
      timer.cancel();
      return;
    }
    
    setState(() {
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
        
        if (_currentProgress >= 1.0) {
          print('タスク完了検知: ${currentTask.title}');
          
          final maxElapsed = totalSeconds;
          _elapsedSeconds = math.min(_elapsedSeconds, maxElapsed);
          _currentProgress = 1.0;
          
          // ❌ 削除：自動再生分岐（約15行削除）
          
          // ✅ 簡素化：通常モードのみ
          _isPlaying = false;
          print('通常モード: 完了通知を送信');
          _stopProgressTimer();
          _sendTaskPlayCompletedNotification(currentTask);
          
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
      final title = 'Task Switch';
      final body = '\"${completedTask.title}\"が完了しました。\n「${nextTask.title}」を再生します。';
      
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
      
      final title = 'Album Complete!';
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
  
  // 🔧 修正：_todayTaskCompletionsは保持する（上書きしない）
  print('🔧 MainWrapper: 進捗をリセットしました（現在のタスクに留まります）');
  print('🔧 保持されたカウント: $_todayTaskCompletions');
}

Future<void> _recordTaskCompletionInApp(
  TaskItem task,
  String albumName,
  int elapsedSeconds,
  bool wasSuccessful,
) async {
  try {
    if (wasSuccessful) {
      await _audioService.playAchievementSound();
    } else {
      await _audioService.playNotificationSound();
    }

    await _taskCompletionService.recordTaskCompletion(
      taskId: task.id,
      taskTitle: task.title,
      wasSuccessful: wasSuccessful,
      elapsedSeconds: elapsedSeconds,
      albumType: _isPlayingSingleAlbum ? 'single' : 'life_dream',
      albumName: albumName,
      albumId: _isPlayingSingleAlbum && _playingSingleAlbum != null 
          ? _playingSingleAlbum!.id 
          : null,
    );

    if (wasSuccessful) {
      setState(() {
        _todayTaskCompletions[task.id] = (_todayTaskCompletions[task.id] ?? 0) + 1;
      });
      
      // SharedPreferences更新
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

    await _loadUserData();

  } catch (e) {
    print('❌ タスク完了記録エラー: $e');
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ 記録の保存に失敗しました'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}

Widget _buildCurrentScreen() {
  final screenHeight = MediaQuery.of(context).size.height;
  
  return Stack(
    children: [
      // メインコンテンツ
      if (!_isSettingsVisible && !_isAlbumDetailVisible) _buildMainContent(),
      
      // アルバム詳細
      if (_isAlbumDetailVisible) _buildAlbumDetailScreen(),
      
      // 🔧 この位置に移動（PlayerScreenの下）
      if (_isArtistScreenVisible) _buildArtistScreen(),
      
      // 【既存メソッドの修正】該当部分を完全に置き換え
// PlayerScreen
if (_playingTasks.isNotEmpty && (_isDraggingPlayer || _playerDragController.value < 1.0 || _isPlayerScreenVisible))
  AnimatedBuilder(
    animation: _playerDragAnimation,
    builder: (context, child) {
      // 🔧 修正：簡易プレイヤーの実際の高さを正確に計算
      final miniPlayerHeight = 64.0; // Container height
      final miniPlayerVerticalMargin = 8.0; // margin: vertical 4 * 2
      final progressBarHeight = 3.0; // 進捗バー
      final pageSelectorHeight = 80.0; // ページセレクター
      
      // 🔧 修正：簡易プレイヤーセクション全体の高さ
      final miniPlayerSectionHeight = miniPlayerHeight + miniPlayerVerticalMargin + progressBarHeight;
      
      // 🔧 修正：下から「簡易プレイヤーセクション + ページセレクター」の位置に配置
      final bottomOffset = miniPlayerSectionHeight + pageSelectorHeight;
      final translateY = (screenHeight - bottomOffset) * _playerDragAnimation.value;
      
      // 🔧 修正：フェードイン効果
      final opacity = _playerDragAnimation.value <= 0.9 
          ? 1.0 
          : (1.0 - ((_playerDragAnimation.value - 0.9) / 0.1));
      
      return Positioned(
        top: 0,
        left: 0,
        right: 0,
        bottom: 0,
        child: Transform.translate(
          offset: Offset(0, translateY),
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onVerticalDragStart: (details) {
                if (!_isDraggingPlayer) {
                  setState(() {
                    _isDraggingPlayer = true;
                    _isPlayerScreenVisible = true;
                    _isAnimating = false;
                  });
                }
              },

              onVerticalDragUpdate: (details) {
                if (_isDraggingPlayer && !_isAnimating) {
                  final deltaOffset = details.delta.dy / screenHeight;
                  _playerDragController.value = (_playerDragController.value + deltaOffset).clamp(0.0, 1.0);
                }
              },
              
              onVerticalDragEnd: (details) {
                if (!_isDraggingPlayer) return;
                
                _isDraggingPlayer = false;
                
                final velocity = details.primaryVelocity ?? 0;
                final currentValue = _playerDragController.value;
                
                if (velocity > 500 || currentValue > 0.3) {
                  _closePlayerWithAnimation();
                } else {
                  _openPlayerWithAnimation();
                }
              },
              
              child: RepaintBoundary(
                child: Container(
                  height: screenHeight,
                  width: double.infinity,
                  color: Colors.transparent,
                  child: child!,
                ),
              ),
            ),
          ),
        ),
      );
    },
    child: _buildPlayerScreen(),
  ),
      
      // 設定画面（最前面）
      if (_isSettingsVisible) _buildSettingsScreen(),
      
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
            bottom: 0, 
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
  // 🔧 修正：シングルアルバムの場合は最初のタスク（index=0）から再生開始
  if (_isPlayingSingleAlbum && _playingSingleAlbum != null && _playingSingleAlbum!.id == album.id) {
    print('🎵 同じアルバム - 現在の再生状態を保持');
    setState(() {
      _isPlayerScreenVisible = true;
    });
  } else {
    print('🎵 違うアルバム - 新しい再生開始（最初のタスクから）');
    _showSingleAlbumPlayer(album, taskIndex: 0); // 🔧 修正：明示的にindex=0を指定
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
  // 🔧 修正：色を事前抽出して渡す
  return FutureBuilder<Color>(
    future: _extractColorFromAlbum(
      imageBytes: _imageBytes,
      imagePath: _currentAlbumImagePath,
    ),
    builder: (context, colorSnapshot) {
      return AlbumDetailScreen(
        albumImagePath: _currentAlbumImagePath,
        idealSelf: _currentIdealSelf,
        artistName: _currentArtistName,
        tasks: _currentTasks,
        imageBytes: _imageBytes,
        albumId: null,
        isSingleAlbum: false,
        preExtractedColor: colorSnapshot.data, // 🆕 追加
        onPlayPressed: () {
          setState(() {
            _isPlayerScreenVisible = true;
          });
          _showFullPlayer();
        },
        onPlayTaskPressed: (taskIndex) {
          print('🎵 ライフドリームアルバム タスク$taskIndex をタップ（理想像考慮で${taskIndex + 1}に変換）');
          
          setState(() {
            _isPlayerScreenVisible = true;
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
    },
  );
}
}

// 【既存メソッドの修正】
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
      initialProgress: _currentProgress,
      forcePageIndex: _forcePlayerPageIndex,
      todayTaskCompletions: _todayTaskCompletions,
      onDataChanged: _onDataUpdated,
      onStateChanged: _onPlayerStateChanged,
      onClose: _hideFullPlayer,
      onTaskCompleted: _onTaskCompletedFromPlayer,
      onCompletionCountsChanged: _onCompletionCountsChanged,
      onNavigateToSettings: () {
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
      // 🆕 追加：色を受け取るコールバック
      onAlbumColorChanged: (color) {
        setState(() {
          _currentAlbumColor = color;
        });
        print('🎨 MainWrapper: 色を受信 → $color');
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

// 既存メソッドの修正（末尾のみ変更）
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
    
    await _loadUserData();
    await _notifyHomeScreenToRefresh();
    
  } catch (e) {
    print('❌ アルバム完了記録エラー: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Failed to save record'),
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



// 既存メソッドの修正
void _resetPlayerAfterCompletion() {
  print('🔄 報告完了後のプレイヤーリセット開始');
  
  setState(() {
    _isPlaying = false;
    _currentProgress = 0.0;
    _elapsedSeconds = 0;
    _currentTaskIndex = _isPlayingSingleAlbum ? 0 : -1;
    
    _taskStartTime = null;
    _pauseStartTime = null;
    _totalPausedSeconds = 0;
    
    _forcePlayerPageIndex = _isPlayingSingleAlbum ? 0 : 0;
  });
  
  _stopProgressTimer();
  
  _onPlayerStateChanged(
    currentTaskIndex: _isPlayingSingleAlbum ? 0 : -1,
    isPlaying: false,
    progress: 0.0,
    elapsedSeconds: 0,
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

  // 【既存メソッドの修正】
Widget _buildBottomSection() {
  final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
  if (keyboardVisible) {
    return const SizedBox.shrink();
  }
  
  return AnimatedBuilder(
    animation: _playerDragController,
    builder: (context, child) {
      // 完全に開いたら非表示
      if (_playerDragController.value < 0.1) {
        return const SizedBox.shrink();
      }
      
      // 0.8〜0.95の範囲でフェード
      double opacity;
      if (_playerDragController.value >= 0.95) {
        opacity = 1.0;
      } else if (_playerDragController.value <= 0.8) {
        opacity = 0.0;
      } else {
        opacity = (_playerDragController.value - 0.8) / 0.15;
      }
      
      // 🔧 修正：Opacityのみ、SizedBoxでラップして透明時に高さ0
      return SizedBox(
        height: opacity > 0.0 ? null : 0,
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: child!,
        ),
      );
    },
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_playingTasks.isNotEmpty) _buildMiniPlayerWithDrag(),
        if (_playingTasks.isNotEmpty) _buildFullWidthProgressBar(),
        _buildPageSelector(),
      ],
    ),
  );
}

// main_wrapper.dart の _buildMiniPlayerWithDrag メソッド

// 【既存メソッドの修正】
Widget _buildMiniPlayerWithDrag() {
  final screenHeight = MediaQuery.of(context).size.height;
  
  return RepaintBoundary(
    child: GestureDetector(
      onVerticalDragStart: (details) {
        print('🎵 簡易プレイヤー: ドラッグ開始');
        
        // 🔧 修正：即座にPlayerScreenを表示状態にする
        if (!_isPlayerScreenVisible) {
          setState(() {
            _isPlayerScreenVisible = true;
          });
        }
        
        if (_isAnimating) {
          _isAnimating = false; // 🔧 修正：setStateを削除
        }
        
        setState(() {
          _isDraggingPlayer = true;
        });
      },
      onVerticalDragUpdate: (details) {
        if (_isDraggingPlayer && !_isAnimating) {
          final deltaOffset = details.delta.dy / screenHeight;
          
          // 🔧 修正：setStateなしで直接値を更新
          _playerDragController.value = (_playerDragController.value + deltaOffset).clamp(0.0, 1.0);
        }
      },
      onVerticalDragEnd: (details) {
        if (!_isDraggingPlayer) return;
        
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
        
        setState(() {
          _isPlayerScreenVisible = true;
        });
        
        _openPlayerWithAnimation();
      },
      child: Container(
        height: 64,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Color.lerp(_currentAlbumColor, Colors.black, 0.75)!,
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
                    _playingTasks.isNotEmpty && _currentTaskIndex >= 0 && _currentTaskIndex < _playingTasks.length
                        ? (_playingTasks[_currentTaskIndex].title.isEmpty
                            ? 'タスク${_currentTaskIndex + 1}'
                            : _playingTasks[_currentTaskIndex].title)
                        : _playingTasks.isNotEmpty && _currentTaskIndex == -1
                            ? (_isPlayingSingleAlbum && _playingSingleAlbum != null 
                                ? _playingSingleAlbum!.albumName 
                                : _currentIdealSelf)
                            : 'Task',
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
                          'Ideal Self',
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
  
  final remainingDistance = _playerDragController.value;
  final duration = (400 * remainingDistance).toInt().clamp(250, 400);
  
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
      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
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
            if (_isArtistScreenVisible) {
              setState(() {
                _isArtistScreenVisible = false;
              });
            }
            
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

// 既存メソッドの修正（簡素化）
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
  
  // ✅ 簡素化：通常モードのみ
  if (mode == 'NORMAL') {
    await _handleNormalModeNotification(params);
  }
}

// ✅ そのまま保持（変更なし、約1850行目付近）
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

  return Scaffold(
    backgroundColor: Colors.black,
    resizeToAvoidBottomInset: false,
    body: Column(
      children: [
        Expanded(
          child: _buildCurrentScreen(),
        ),
        // 🔧 修正：Transform.translateを削除
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
      child: Image.asset(
        'assets/app_icon.png',
        width: 140,
        height: 140,
        fit: BoxFit.cover,
      ),
    ),
  );
}
}
