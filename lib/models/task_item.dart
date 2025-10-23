// models/task_item.dart - 拡張版
import 'package:flutter/material.dart';

class TaskItem {
  final String title;
  final String description;
  final Color color;
  final int duration; // 分単位
  
  // 🔔 新機能: 完了履歴関連フィールド
  final List<DateTime> completionHistory;  // 完了履歴
  final int totalCompletions;              // 総完了回数
  final DateTime? lastCompletedAt;         // 最後の完了日時
  final String id;                         // タスクの一意識別子
  final String? lyricNote;  // 🆕 Lyric Notesのメモ内容

  // 🆕 アシストボタン機能: URL格納用フィールド
  final String? assistUrl;  // ← この行を追加

  TaskItem({
    required this.title,
    required this.description,
    required this.color,
    this.duration = 3, // デフォルト3分
    this.completionHistory = const [],
    this.totalCompletions = 0,
    this.lastCompletedAt,
    String? id,
    this.assistUrl,
    this.lyricNote, 
  }) : id = id ?? 'task_${DateTime.now().millisecondsSinceEpoch}_${title.hashCode}';

  // JSON変換用のメソッド
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'color': color.value,
      'duration': duration,
      'completionHistory': completionHistory.map((date) => date.toIso8601String()).toList(),
      'totalCompletions': totalCompletions,
      'lastCompletedAt': lastCompletedAt?.toIso8601String(),
      'id': id,
      'assistUrl': assistUrl,
      'lyricNote': lyricNote,
    };
  }

  // JSONからTaskItemを作成するメソッド
  factory TaskItem.fromJson(Map<String, dynamic> json) {
    return TaskItem(
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      color: Color(json['color'] ?? 0xFF1DB954),
      duration: json['duration'] ?? 3,
      completionHistory: json['completionHistory'] != null
          ? (json['completionHistory'] as List)
              .map((dateString) => DateTime.parse(dateString))
              .toList()
          : [],
      totalCompletions: json['totalCompletions'] ?? 0,
      lastCompletedAt: json['lastCompletedAt'] != null
          ? DateTime.parse(json['lastCompletedAt'])
          : null,
      id: json['id'] ?? 'task_${DateTime.now().millisecondsSinceEpoch}',
      assistUrl: json['assistUrl'],
      lyricNote: json['lyricNote'],
    );
  }

  // copyWithメソッド（必須）
  TaskItem copyWith({
    String? title,
    String? description,
    Color? color,
    int? duration,
    List<DateTime>? completionHistory,
    int? totalCompletions,
    DateTime? lastCompletedAt,
    String? id,
    String? assistUrl,
    String? lyricNote,
  }) {
    return TaskItem(
      title: title ?? this.title,
      description: description ?? this.description,
      color: color ?? this.color,
      duration: duration ?? this.duration,
      completionHistory: completionHistory ?? this.completionHistory,
      totalCompletions: totalCompletions ?? this.totalCompletions,
      lastCompletedAt: lastCompletedAt ?? this.lastCompletedAt,
      id: id ?? this.id,
      assistUrl: assistUrl ?? this.assistUrl,
      lyricNote: lyricNote ?? this.lyricNote,
    );
  }

  // 🔔 新機能: 完了記録を追加するメソッド
  TaskItem addCompletion(DateTime completionTime) {
    final newHistory = List<DateTime>.from(completionHistory)..add(completionTime);
    return copyWith(
      completionHistory: newHistory,
      totalCompletions: totalCompletions + 1,
      lastCompletedAt: completionTime,
    );
  }

  // 🔔 新機能: 今日の完了回数を取得
  int getTodayCompletions() {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    
    return completionHistory.where((date) => 
      date.isAfter(todayStart) && date.isBefore(todayEnd)
    ).length;
  }

  // 🔔 新機能: 連続完了日数を取得
  int getStreakDays() {
    if (completionHistory.isEmpty) return 0;
    
    final sortedHistory = List<DateTime>.from(completionHistory)
      ..sort((a, b) => b.compareTo(a)); // 新しい順にソート
    
    int streak = 0;
    DateTime currentDate = DateTime.now();
    
    for (final completion in sortedHistory) {
      final completionDate = DateTime(completion.year, completion.month, completion.day);
      final checkDate = DateTime(currentDate.year, currentDate.month, currentDate.day);
      
      if (completionDate.isAtSameMomentAs(checkDate)) {
        streak++;
        currentDate = currentDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    
    return streak;
  }

  @override
  String toString() {
    return 'TaskItem(id: $id, title: $title, completions: $totalCompletions)';
  }
}