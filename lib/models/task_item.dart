// models/task_item.dart - typo修正版
import 'package:flutter/material.dart';
import 'lyric_note_item.dart'; 

class TaskItem {
  final String title;
  final String description;
  final Color color;
  final int duration;
  
  final List<DateTime> completionHistory;
  final int totalCompletions;
  final DateTime? lastCompletedAt;
  final String id;
  final List<LyricNoteItem>? lyricNotes;
  final String? assistUrl;

  TaskItem({
    required this.title,
    required this.description,
    required this.color,
    this.duration = 3,
    this.completionHistory = const [],
    this.totalCompletions = 0,
    this.lastCompletedAt,
    String? id,
    this.assistUrl,
    this.lyricNotes,
  }) : id = id ?? 'task_${DateTime.now().millisecondsSinceEpoch}_${title.hashCode}';

  // 🔧 修正：typoを修正
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
      'lyricNotes': lyricNotes?.map((note) => note.toJson()).toList(),  // 🔧 修正：lyricNote → lyricNotes
    };
  }

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
      lyricNotes: json['lyricNotes'] != null
          ? (json['lyricNotes'] as List)
              .map((noteJson) => LyricNoteItem.fromJson(noteJson))
              .toList()
          : _migrateLegacyLyricNote(json['lyricNote']),
    );
  }

  static List<LyricNoteItem>? _migrateLegacyLyricNote(dynamic legacyNote) {
    if (legacyNote == null || legacyNote.toString().isEmpty) {
      return null;
    }
    
    return [
      LyricNoteItem(
        text: legacyNote.toString(),
        level: 1,
        createdAt: DateTime.now(),
      ),
    ];
  }

  TaskItem copyWith({
    String? id,
    String? title,
    String? description,
    Color? color,
    int? duration,
    List<DateTime>? completionHistory,
    int? totalCompletions,
    DateTime? lastCompletedAt,
    List<LyricNoteItem>? lyricNotes,
    bool clearLyricNotes = false,
    String? assistUrl,
    bool clearAssistUrl = false,
  }) {
    return TaskItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      color: color ?? this.color,
      duration: duration ?? this.duration,
      completionHistory: completionHistory ?? this.completionHistory,
      totalCompletions: totalCompletions ?? this.totalCompletions,
      lastCompletedAt: lastCompletedAt ?? this.lastCompletedAt,
      lyricNotes: clearLyricNotes ? null : (lyricNotes ?? this.lyricNotes),
      assistUrl: clearAssistUrl ? null : (assistUrl ?? this.assistUrl),
    );
  }

  TaskItem addCompletion(DateTime completionTime) {
    final newHistory = List<DateTime>.from(completionHistory)..add(completionTime);
    return copyWith(
      completionHistory: newHistory,
      totalCompletions: totalCompletions + 1,
      lastCompletedAt: completionTime,
    );
  }

  int getTodayCompletions() {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    
    return completionHistory.where((date) => 
      date.isAfter(todayStart) && date.isBefore(todayEnd)
    ).length;
  }

  int getStreakDays() {
    if (completionHistory.isEmpty) return 0;
    
    final sortedHistory = List<DateTime>.from(completionHistory)
      ..sort((a, b) => b.compareTo(a));
    
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