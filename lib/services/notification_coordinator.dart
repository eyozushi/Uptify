// services/notification_coordinator.dart - 通知システム統括管理
import 'dart:async';
import 'habit_breaker_service.dart';

class NotificationCoordinator {
  static final NotificationCoordinator _instance = NotificationCoordinator._internal();
  factory NotificationCoordinator() => _instance;
  NotificationCoordinator._internal();

  final HabitBreakerService _habitBreakerService = HabitBreakerService();
  
  bool _isTaskRunning = false;
  bool _isSleepMode = false;

  /// タスク開始時：定期通知を一時停止
  Future<void> pauseForTask() async {
    if (_isTaskRunning) return;
    
    _isTaskRunning = true;
    _habitBreakerService.pauseNotifications();
    print('🔧 NotificationCoordinator: タスク開始 - 定期通知一時停止');
  }

  /// タスク完了時：定期通知を再開
  Future<void> resumeAfterTask() async {
    if (!_isTaskRunning) return;
    
    _isTaskRunning = false;
    _habitBreakerService.resumeNotifications();
    print('🔧 NotificationCoordinator: タスク完了 - 定期通知再開');
  }

  /// 睡眠モード開始
  Future<void> enterSleepMode() async {
    _isSleepMode = true;
    await _habitBreakerService.stopHabitBreaker();
    print('🌙 NotificationCoordinator: 睡眠モード開始');
  }

  /// 睡眠モード終了
  Future<void> exitSleepMode() async {
    _isSleepMode = false;
    await _habitBreakerService.startHabitBreaker();
    print('☀️ NotificationCoordinator: 睡眠モード終了');
  }

  /// 定期通知を開始
  Future<void> startHabitBreaker() async {
    await _habitBreakerService.startHabitBreaker();
  }

  /// すべての通知を停止
  Future<void> stopAll() async {
    await _habitBreakerService.stopHabitBreaker();
    _isTaskRunning = false;
    _isSleepMode = false;
  }

  bool get isTaskRunning => _isTaskRunning;
  bool get isSleepMode => _isSleepMode;
}