// widgets/activity_widget.dart - WidgetKit用データ構造
import 'dart:typed_data';
import 'dart:convert'; 
import '../models/live_activity_data.dart';

class ActivityWidgetData {
  final String taskTitle;
  final String albumName;
  final String artistName;
  final String currentTime;
  final String totalTime;
  final double progress;
  final bool isPlaying;
  final bool isAutoPlay;
  final String albumCoverBase64;
  final String taskColorHex;
  
  const ActivityWidgetData({
    required this.taskTitle,
    required this.albumName,
    required this.artistName,
    required this.currentTime,
    required this.totalTime,
    required this.progress,
    required this.isPlaying,
    required this.isAutoPlay,
    required this.albumCoverBase64,
    required this.taskColorHex,
  });

  factory ActivityWidgetData.fromLiveActivityData(LiveActivityData data) {
  final minutes = data.elapsedSeconds ~/ 60;
  final seconds = data.elapsedSeconds % 60;
  final currentTime = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  
  final totalMinutes = data.totalDurationSeconds ~/ 60;
  final totalSeconds = data.totalDurationSeconds % 60;
  final totalTime = '${totalMinutes.toString().padLeft(2, '0')}:${totalSeconds.toString().padLeft(2, '0')}';
  
  // 🔧 修正: Base64エンコード処理をここに移動
  String albumCoverBase64 = '';
  if (data.albumCoverImage != null) {
    try {
      albumCoverBase64 = base64Encode(data.albumCoverImage!);
    } catch (e) {
      print('❌ アルバムカバー画像エンコードエラー: $e');
      albumCoverBase64 = '';
    }
  }
  
  return ActivityWidgetData(
    taskTitle: data.taskTitle,
    albumName: data.albumName,
    artistName: data.artistName,
    currentTime: currentTime,
    totalTime: totalTime,
    progress: data.progress,
    isPlaying: data.isPlaying,
    isAutoPlay: data.isAutoPlay,
    albumCoverBase64: albumCoverBase64, // 🔧 修正: 実際のBase64データを設定
    taskColorHex: data.taskColor,
  );
}

  Map<String, dynamic> toWidgetData() {
    return {
      'taskTitle': taskTitle,
      'albumName': albumName,
      'artistName': artistName,
      'currentTime': currentTime,
      'totalTime': totalTime,
      'progress': progress,
      'isPlaying': isPlaying,
      'isAutoPlay': isAutoPlay,
      'albumCoverBase64': albumCoverBase64,
      'taskColorHex': taskColorHex,
    };
  }
}