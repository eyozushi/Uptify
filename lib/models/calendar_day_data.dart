// models/calendar_day_data.dart
import 'package:flutter/material.dart';

/// カレンダーの1日分のデータ
class CalendarDayData {
  /// 日付
  final DateTime date;
  
  /// その日に完了したタスクの数
  final int completedTaskCount;
  
  /// 4タスク全完了かどうか
  final bool isFullCompletion;
  
  /// 完了したタスクのIDリスト
  final List<String> completedTaskIds;
  
  /// その日の成功タスク数
  final int successfulTaskCount;
  
  const CalendarDayData({
    required this.date,
    required this.completedTaskCount,
    required this.isFullCompletion,
    required this.completedTaskIds,
    required this.successfulTaskCount,
  });
  
  /// 空のデータを作成
  factory CalendarDayData.empty(DateTime date) {
    return CalendarDayData(
      date: date,
      completedTaskCount: 0,
      isFullCompletion: false,
      completedTaskIds: [],
      successfulTaskCount: 0,
    );
  }
  
  /// JSON変換
  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'completedTaskCount': completedTaskCount,
      'isFullCompletion': isFullCompletion,
      'completedTaskIds': completedTaskIds,
      'successfulTaskCount': successfulTaskCount,
    };
  }
  
  /// JSONから復元
  factory CalendarDayData.fromJson(Map<String, dynamic> json) {
    return CalendarDayData(
      date: DateTime.parse(json['date']),
      completedTaskCount: json['completedTaskCount'] ?? 0,
      isFullCompletion: json['isFullCompletion'] ?? false,
      completedTaskIds: List<String>.from(json['completedTaskIds'] ?? []),
      successfulTaskCount: json['successfulTaskCount'] ?? 0,
    );
  }
  
  /// copyWith
  CalendarDayData copyWith({
    DateTime? date,
    int? completedTaskCount,
    bool? isFullCompletion,
    List<String>? completedTaskIds,
    int? successfulTaskCount,
  }) {
    return CalendarDayData(
      date: date ?? this.date,
      completedTaskCount: completedTaskCount ?? this.completedTaskCount,
      isFullCompletion: isFullCompletion ?? this.isFullCompletion,
      completedTaskIds: completedTaskIds ?? this.completedTaskIds,
      successfulTaskCount: successfulTaskCount ?? this.successfulTaskCount,
    );
  }
  
  @override
  String toString() {
    return 'CalendarDayData(date: $date, completed: $completedTaskCount, full: $isFullCompletion)';
  }
}