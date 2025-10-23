// services/live_activities_service.dart
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import '../widgets/activity_widget.dart';
import '../models/live_activity_data.dart';
import '../models/activity_state.dart';
import '../models/task_item.dart';

class LiveActivitiesService {
  static final LiveActivitiesService _instance = LiveActivitiesService._internal();
  factory LiveActivitiesService() => _instance;
  LiveActivitiesService._internal();

  ActivitySession? _currentSession;
  StreamController<LiveActivityData>? _activityController;

  // 🔧 追加: デバッグログ制御フラグ
  static const bool _enableDebugLogs = false;
  static const bool _enableLiveActivities = false;

  // MethodChannel追加
  static const MethodChannel _channel = MethodChannel('live_activities');

  // 🆕 WidgetKit連携用の追加変数
  ActivityWidgetData? _lastWidgetData;
  Timer? _widgetUpdateTimer;
  static const String _activityIdentifier = 'TaskPlayerActivity';

  // Activity開始
  Future<bool> startActivity({
  required List<TaskItem> tasks,
  required int currentTaskIndex,
  required String albumName,
  required String artistName,
  required bool isAutoPlay,
  required bool isPlayingSingleAlbum,
}) async {
  if (!_enableLiveActivities) {
    if (_enableDebugLogs) print('Live Activities無効化中');
    return false;
  }
  
  try {
    final sessionId = 'activity_${DateTime.now().millisecondsSinceEpoch}';
    
    _currentSession = ActivitySession(
      id: sessionId,
      startTime: DateTime.now(),
      state: ActivityState.starting,
      currentTaskIndex: currentTaskIndex,
      totalTasks: tasks.length,
      isAutoPlay: isAutoPlay,
    );

    _activityController = StreamController<LiveActivityData>.broadcast();
    
    _startWidgetUpdateTimer();
    await _startLiveActivityWidget();
    
    if (_enableDebugLogs) print('Live Activity開始: $sessionId');
    return true;
  } catch (e) {
    if (_enableDebugLogs) print('Live Activity開始エラー: $e');
    return false;
  }
}

  // Activity更新
  Future<void> updateActivity(LiveActivityData data) async {
  if (!_enableLiveActivities || _currentSession == null || _activityController == null) return;
  
  try {
    _activityController!.add(data);
    
    final widgetData = ActivityWidgetData.fromLiveActivityData(data);
    await _updateWidgetData(widgetData);
    
    // ログ出力を条件付きに
    if (_enableDebugLogs) {
      print('Live Activity更新: ${data.taskTitle} - ${(data.progress * 100).toInt()}%');
    }
  } catch (e) {
    if (_enableDebugLogs) print('Live Activity更新エラー: $e');
  }
}



// 🆕 WidgetKit更新タイマー開始
void _startWidgetUpdateTimer() {
  _widgetUpdateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
    if (_lastWidgetData != null) {
      _updateWidgetTimestamp();
    }
  });
}

// 🆕 WidgetKit更新タイマー停止
void _stopWidgetUpdateTimer() {
  _widgetUpdateTimer?.cancel();
  _widgetUpdateTimer = null;
}

Future<void> _startLiveActivityWidget() async {
  if (!_enableLiveActivities) return;
  
  try {
    if (_enableDebugLogs) {
      print('Live Activity Widget開始準備完了（ネイティブ実装待機中）');
    }
  } catch (e) {
    if (_enableDebugLogs) print('Live Activity開始エラー: $e');
  }
}

// 🆕 Widget データ更新
Future<void> _updateWidgetData(ActivityWidgetData widgetData) async {
  if (!_enableLiveActivities) return;
  
  try {
    _lastWidgetData = widgetData;
    
    // MethodChannelの呼び出しを完全に無効化
    if (_enableDebugLogs) {
      print('Widget更新準備: ${widgetData.taskTitle} - ${widgetData.currentTime}/${widgetData.totalTime}');
    }
  } catch (e) {
    if (_enableDebugLogs) print('Widget更新エラー: $e');
  }
}

// 🆕 Widget タイムスタンプ更新（1秒ごとの時間更新）
void _updateWidgetTimestamp() {
  if (!_enableLiveActivities || _lastWidgetData == null) return;
  
  try {
    // ログ出力を完全に停止
    if (_enableDebugLogs) {
      print('Widget時間更新通知送信');
    }
  } catch (e) {
    if (_enableDebugLogs) print('Widget時間更新エラー: $e');
  }
}

// 🆕 Live Activity Widget終了
Future<void> endActivity() async {
  if (!_enableLiveActivities) return;
  
  try {
    _stopWidgetUpdateTimer();
    // await _endLiveActivityWidget(); // この行を削除
    
    await _activityController?.close();
    _activityController = null;
    _currentSession = null;
    _lastWidgetData = null;
    
    if (_enableDebugLogs) print('Live Activity終了');
  } catch (e) {
    if (_enableDebugLogs) print('Live Activity終了エラー: $e');
  }
}



  // 現在のセッション情報
  ActivitySession? get currentSession => _currentSession;
  bool get isActive => _currentSession != null;
}