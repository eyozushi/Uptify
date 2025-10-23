// models/live_activity_data.dart
import 'dart:typed_data';

class LiveActivityData {
  final String taskTitle;
  final String albumName;
  final String artistName;
  final int totalDurationSeconds;
  final int elapsedSeconds;
  final double progress;
  final bool isPlaying;
  final bool isAutoPlay;
  final Uint8List? albumCoverImage;
  final String taskColor; // Color.value.toString()
  
  const LiveActivityData({
    required this.taskTitle,
    required this.albumName,
    required this.artistName,
    required this.totalDurationSeconds,
    required this.elapsedSeconds,
    required this.progress,
    required this.isPlaying,
    required this.isAutoPlay,
    this.albumCoverImage,
    required this.taskColor,
  });

  Map<String, dynamic> toMap() {
    return {
      'taskTitle': taskTitle,
      'albumName': albumName,
      'artistName': artistName,
      'totalDurationSeconds': totalDurationSeconds,
      'elapsedSeconds': elapsedSeconds,
      'progress': progress,
      'isPlaying': isPlaying,
      'isAutoPlay': isAutoPlay,
      'taskColor': taskColor,
    };
  }
}