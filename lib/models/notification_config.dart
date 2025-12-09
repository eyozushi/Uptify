import 'package:flutter/material.dart';

// models/notification_config.dart - 改善版
class NotificationConfig {
  final bool isHabitBreakerEnabled;
  final int habitBreakerInterval;
  final List<String> habitBreakerMessages;

  // 睡眠スケジュール設定
final bool sleepScheduleEnabled;
final int bedtimeHour;        // 1-12
final int bedtimeMinute;      // 0, 15, 30, 45
final String bedtimePeriod;   // 'AM' or 'PM'
final int wakeUpHour;         // 1-12
final int wakeUpMinute;       // 0, 15, 30, 45
final String wakeUpPeriod;    // 'AM' or 'PM'

// 曜日別スケジュール（1=Sunday, 7=Saturday）
final Set<int> enabledDays;

// 特別メッセージ
final String bedtimeMessage;
final String wakeUpMessage;


  const NotificationConfig({
    this.isHabitBreakerEnabled = false,
    this.habitBreakerInterval = 15,
    this.habitBreakerMessages = const [
  // 🎯 意識喚起系（5個）- 現在の行動への気づきを促す
  'What are you doing right now?',
  'What did you accomplish in the last 5 minutes?',
  'Use phone time for tasks instead?',
  'Is this action really necessary?',
  'What are you focusing on right now?',
  
  // 🚀 目標志向系（4個）- 具体的な目標達成を意識させる
  'Are you moving toward your ideal self?',
  'Making progress on today\'s tasks?',
  'Let\'s play the next track',
  'Start actions toward your dreams?',
  
  // ⏰ 時間管理系（4個）- 時間の使い方を見直させる
  'How will you use these 15 minutes?',
  'Use your limited time wisely',
  'Satisfied with how you\'re using time?',
  'Time won\'t come back. Make the most of now',
  
  // 🔄 習慣改善系（4個）- 悪い習慣からの離脱を促す
  'Stop social media, start tasks?',
  'End the idle time?',
  'Choose growth over scrolling?',
  'Now is the moment to change habits',
  
  // ✨ モチベーション系（3個）- 前向きな気持ちを促進
  'Small steps create big changes',
  'Your future changes with each action',
  'You can do it. Let\'s start',
],

    this.sleepScheduleEnabled = true,
  this.bedtimeHour = 10,
  this.bedtimeMinute = 0,
  this.bedtimePeriod = 'PM',
  this.wakeUpHour = 6,
  this.wakeUpMinute = 0,
  this.wakeUpPeriod = 'AM',
  this.enabledDays = const {1, 2, 3, 4, 5, 6, 7},
  this.bedtimeMessage = 'Time to put your phone away and rest 🌙',
  this.wakeUpMessage = 'Good morning! Ready to conquer today? ☀️',
});


  // JSON変換用
  Map<String, dynamic> toJson() {
    return {
      'isHabitBreakerEnabled': isHabitBreakerEnabled,
      'habitBreakerInterval': habitBreakerInterval,
      'habitBreakerMessages': habitBreakerMessages,
      'sleepScheduleEnabled': sleepScheduleEnabled,
    'bedtimeHour': bedtimeHour,
    'bedtimeMinute': bedtimeMinute,
    'bedtimePeriod': bedtimePeriod,
    'wakeUpHour': wakeUpHour,
    'wakeUpMinute': wakeUpMinute,
    'wakeUpPeriod': wakeUpPeriod,
    'enabledDays': enabledDays.toList(),
    'bedtimeMessage': bedtimeMessage,
    'wakeUpMessage': wakeUpMessage,
    };
  }

  // JSONから復元
  factory NotificationConfig.fromJson(Map<String, dynamic> json) {
    return NotificationConfig(
      isHabitBreakerEnabled: json['isHabitBreakerEnabled'] ?? false,
      habitBreakerInterval: json['habitBreakerInterval'] ?? 1,
      habitBreakerMessages: json['habitBreakerMessages'] != null
    ? List<String>.from(json['habitBreakerMessages'])
    : const [
        'What are you doing right now?',
        'What did you accomplish in the last 5 minutes?',
        'Use phone time for tasks instead?',
        'Is this action really necessary?',
        'What are you focusing on right now?',
        'Are you moving toward your ideal self?',
        'Making progress on today\'s tasks?',
        'Let\'s play the next track',
        'Start actions toward your dreams?',
        'How will you use these 15 minutes?',
        'Use your limited time wisely',
        'Satisfied with how you\'re using time?',
        'Time won\'t come back. Make the most of now',
        'Stop social media, start tasks?',
        'End the idle time?',
        'Choose growth over scrolling?',
        'Now is the moment to change habits',
        'Small steps create big changes',
        'Your future changes with each action',
        'You can do it. Let\'s start',
      ],
            // 🆕 以下を追加
    sleepScheduleEnabled: json['sleepScheduleEnabled'] ?? true,
    bedtimeHour: json['bedtimeHour'] ?? 10,
    bedtimeMinute: json['bedtimeMinute'] ?? 0,
    bedtimePeriod: json['bedtimePeriod'] ?? 'PM',
    wakeUpHour: json['wakeUpHour'] ?? 6,
    wakeUpMinute: json['wakeUpMinute'] ?? 0,
    wakeUpPeriod: json['wakeUpPeriod'] ?? 'AM',
    enabledDays: json['enabledDays'] != null
        ? Set<int>.from(json['enabledDays'])
        : const {1, 2, 3, 4, 5, 6, 7},
    bedtimeMessage: json['bedtimeMessage'] ?? 'Time to put your phone away and rest 🌙',
    wakeUpMessage: json['wakeUpMessage'] ?? 'Good morning! Ready to conquer today? ☀️',
    );
  }

  // copyWith メソッド（修正版）
  NotificationConfig copyWith({
  bool? isHabitBreakerEnabled,
  int? habitBreakerInterval,
  List<String>? habitBreakerMessages,
  // 🆕 以下を追加
  bool? sleepScheduleEnabled,
  int? bedtimeHour,
  int? bedtimeMinute,
  String? bedtimePeriod,
  int? wakeUpHour,
  int? wakeUpMinute,
  String? wakeUpPeriod,
  Set<int>? enabledDays,
  String? bedtimeMessage,
  String? wakeUpMessage,
}) {
  // 既存の間隔バリデーション（15/30/60）
  int validatedInterval = habitBreakerInterval ?? this.habitBreakerInterval;
  if (habitBreakerInterval != null) {
    if (habitBreakerInterval <= 1) {
      validatedInterval = 1;
    } else if (habitBreakerInterval <= 15) {
      validatedInterval = 15;
    } else if (habitBreakerInterval <= 30) {
      validatedInterval = 30;
    } else {
      validatedInterval = 60;
    }
  }
  
  return NotificationConfig(
    isHabitBreakerEnabled: isHabitBreakerEnabled ?? this.isHabitBreakerEnabled,
    habitBreakerInterval: validatedInterval,
    habitBreakerMessages: habitBreakerMessages ?? this.habitBreakerMessages,
    // 🆕 以下を追加
    sleepScheduleEnabled: sleepScheduleEnabled ?? this.sleepScheduleEnabled,
    bedtimeHour: bedtimeHour ?? this.bedtimeHour,
    bedtimeMinute: bedtimeMinute ?? this.bedtimeMinute,
    bedtimePeriod: bedtimePeriod ?? this.bedtimePeriod,
    wakeUpHour: wakeUpHour ?? this.wakeUpHour,
    wakeUpMinute: wakeUpMinute ?? this.wakeUpMinute,
    wakeUpPeriod: wakeUpPeriod ?? this.wakeUpPeriod,
    enabledDays: enabledDays ?? this.enabledDays,
    bedtimeMessage: bedtimeMessage ?? this.bedtimeMessage,
    wakeUpMessage: wakeUpMessage ?? this.wakeUpMessage,
  );
}
  /// 24時間形式の就寝時刻を取得
int get bedtime24Hour {
  if (bedtimePeriod == 'AM') {
    return bedtimeHour == 12 ? 0 : bedtimeHour;
  } else {
    return bedtimeHour == 12 ? 12 : bedtimeHour + 12;
  }
}

/// 24時間形式の起床時刻を取得
int get wakeUp24Hour {
  if (wakeUpPeriod == 'AM') {
    return wakeUpHour == 12 ? 0 : wakeUpHour;
  } else {
    return wakeUpHour == 12 ? 12 : wakeUpHour + 12;
  }
}

/// 現在時刻が睡眠時間内かチェック
bool isSleepTime(DateTime now) {
  if (!sleepScheduleEnabled) return false;
  
  final currentMinutes = now.hour * 60 + now.minute;
  final bedtimeMinutes = bedtime24Hour * 60 + bedtimeMinute;
  final wakeUpMinutes = wakeUp24Hour * 60 + wakeUpMinute;
  
  if (bedtimeMinutes < wakeUpMinutes) {
    // 同日内（例: 6 AM ～ 10 PM）
    return currentMinutes >= bedtimeMinutes && currentMinutes < wakeUpMinutes;
  } else {
    // 日付跨ぎ（例: 10 PM ～ 6 AM）
    return currentMinutes >= bedtimeMinutes || currentMinutes < wakeUpMinutes;
  }
}

/// 指定曜日が有効かチェック（1=Sunday, 7=Saturday）
bool isDayEnabled(int weekday) {
  return enabledDays.contains(weekday);
}

/// 就寝時刻と起床時刻が同じかチェック（バリデーション用）
bool get isSameTime {
  return bedtime24Hour == wakeUp24Hour && bedtimeMinute == wakeUpMinute;
}

/// すべての曜日が無効かチェック
bool get allDaysDisabled {
  return enabledDays.isEmpty;
}

}

