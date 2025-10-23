// models/achievement_record.dart
class AchievementRecord {
  final DateTime date;
  final Map<String, int> taskCompletions;    // タスクID別完了回数
  final Map<String, int> taskSuccesses;      // タスクID別成功回数
  final int totalTasksCompleted;
  final int totalTasksAttempted;
  final double achievementRate;
  final List<String> completedTaskIds;       // その日完了したタスクID一覧

  AchievementRecord({
    required this.date,
    required this.taskCompletions,
    required this.taskSuccesses,
    required this.totalTasksCompleted,
    required this.totalTasksAttempted,
    required this.achievementRate,
    required this.completedTaskIds,
  });

  // JSON変換用
  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'taskCompletions': taskCompletions,
      'taskSuccesses': taskSuccesses,
      'totalTasksCompleted': totalTasksCompleted,
      'totalTasksAttempted': totalTasksAttempted,
      'achievementRate': achievementRate,
      'completedTaskIds': completedTaskIds,
    };
  }

  // JSONから復元
  factory AchievementRecord.fromJson(Map<String, dynamic> json) {
    return AchievementRecord(
      date: DateTime.parse(json['date']),
      taskCompletions: Map<String, int>.from(json['taskCompletions']),
      taskSuccesses: Map<String, int>.from(json['taskSuccesses']),
      totalTasksCompleted: json['totalTasksCompleted'],
      totalTasksAttempted: json['totalTasksAttempted'],
      achievementRate: json['achievementRate'].toDouble(),
      completedTaskIds: List<String>.from(json['completedTaskIds']),
    );
  }

  // 日付キーを生成（YYYY-MM-DD形式）
  String get dateKey {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // copyWith メソッド
  AchievementRecord copyWith({
    DateTime? date,
    Map<String, int>? taskCompletions,
    Map<String, int>? taskSuccesses,
    int? totalTasksCompleted,
    int? totalTasksAttempted,
    double? achievementRate,
    List<String>? completedTaskIds,
  }) {
    return AchievementRecord(
      date: date ?? this.date,
      taskCompletions: taskCompletions ?? this.taskCompletions,
      taskSuccesses: taskSuccesses ?? this.taskSuccesses,
      totalTasksCompleted: totalTasksCompleted ?? this.totalTasksCompleted,
      totalTasksAttempted: totalTasksAttempted ?? this.totalTasksAttempted,
      achievementRate: achievementRate ?? this.achievementRate,
      completedTaskIds: completedTaskIds ?? this.completedTaskIds,
    );
  }

  @override
  String toString() {
    return 'AchievementRecord(date: $dateKey, completed: $totalTasksCompleted, rate: ${(achievementRate * 100).toStringAsFixed(1)}%)';
  }
}