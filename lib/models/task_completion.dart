// models/task_completion.dart
class TaskCompletion {
  final String id;
  final String taskId;
  final String taskTitle;
  final DateTime startedAt;
  final DateTime completedAt;
  final bool wasSuccessful;        // ユーザーの達成申告
  final int elapsedSeconds;
  final String albumType;          // 'life_dream' or 'single'
  final String? albumId;           // シングルアルバムの場合のID
  final String? albumName;         // アルバム名

  TaskCompletion({
    required this.id,
    required this.taskId,
    required this.taskTitle,
    required this.startedAt,
    required this.completedAt,
    required this.wasSuccessful,
    required this.elapsedSeconds,
    required this.albumType,
    this.albumId,
    this.albumName,
  });

  // JSON変換用
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'taskId': taskId,
      'taskTitle': taskTitle,
      'startedAt': startedAt.toIso8601String(),
      'completedAt': completedAt.toIso8601String(),
      'wasSuccessful': wasSuccessful,
      'elapsedSeconds': elapsedSeconds,
      'albumType': albumType,
      'albumId': albumId,
      'albumName': albumName,
    };
  }

  // JSONから復元
  factory TaskCompletion.fromJson(Map<String, dynamic> json) {
    return TaskCompletion(
      id: json['id'],
      taskId: json['taskId'],
      taskTitle: json['taskTitle'],
      startedAt: DateTime.parse(json['startedAt']),
      completedAt: DateTime.parse(json['completedAt']),
      wasSuccessful: json['wasSuccessful'],
      elapsedSeconds: json['elapsedSeconds'],
      albumType: json['albumType'],
      albumId: json['albumId'],
      albumName: json['albumName'],
    );
  }

  // copyWith メソッド
  TaskCompletion copyWith({
    String? id,
    String? taskId,
    String? taskTitle,
    DateTime? startedAt,
    DateTime? completedAt,
    bool? wasSuccessful,
    int? elapsedSeconds,
    String? albumType,
    String? albumId,
    String? albumName,
  }) {
    return TaskCompletion(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      taskTitle: taskTitle ?? this.taskTitle,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      wasSuccessful: wasSuccessful ?? this.wasSuccessful,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      albumType: albumType ?? this.albumType,
      albumId: albumId ?? this.albumId,
      albumName: albumName ?? this.albumName,
    );
  }

  @override
  String toString() {
    return 'TaskCompletion(id: $id, taskTitle: $taskTitle, wasSuccessful: $wasSuccessful, albumType: $albumType)';
  }
}