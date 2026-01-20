// models/activity_state.dart
enum ActivityState {
  inactive,
  starting,
  active,
  paused,
  completed,
  error,
}

class ActivitySession {
  final String id;
  final DateTime startTime;
  final ActivityState state;
  final int currentTaskIndex;
  final int totalTasks;
  // ❌ 削除：final bool isAutoPlay;
  
  const ActivitySession({
    required this.id,
    required this.startTime,
    required this.state,
    required this.currentTaskIndex,
    required this.totalTasks,
    // ❌ 削除：required this.isAutoPlay,
  });
}