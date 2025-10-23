// models/playback_report.dart
import '../models/task_completion.dart';

/// レポートの種類
enum ReportType {
  daily,    // デイリー
  weekly,   // ウィークリー
  monthly,  // マンスリー
  annual,   // アニュアル
}

/// Playbackレポートの統一データモデル
class PlaybackReport {
  /// レポートの種類
  final ReportType type;
  
  /// 対象日時
  final DateTime targetDate;
  
  /// レポートデータ（柔軟な構造）
  final Map<String, dynamic> data;
  
  const PlaybackReport({
    required this.type,
    required this.targetDate,
    required this.data,
  });
  
  /// デイリーレポートを作成
  factory PlaybackReport.daily({
    required DateTime date,
    required List<TaskCompletion> taskHistory,
    required int totalTasks,
  }) {
    return PlaybackReport(
      type: ReportType.daily,
      targetDate: date,
      data: {
        'taskHistory': taskHistory,
        'totalTasks': totalTasks,
      },
    );
  }
  
  /// ウィークリーレポートを作成
  factory PlaybackReport.weekly({
    required DateTime weekStart,
    required Map<int, int> dailyCounts, // 曜日(0-6) -> タスク数
    required int totalTasks,
    required List<Map<String, dynamic>> topTasks,
  }) {
    return PlaybackReport(
      type: ReportType.weekly,
      targetDate: weekStart,
      data: {
        'dailyCounts': dailyCounts,
        'totalTasks': totalTasks,
        'topTasks': topTasks,
      },
    );
  }
  
  /// マンスリーレポートを作成
  factory PlaybackReport.monthly({
    required int year,
    required int month,
    required List<int> dailyTrend, // 日別タスク数の配列
    required int totalTasks,
    required List<Map<String, dynamic>> topAlbums,
  }) {
    return PlaybackReport(
      type: ReportType.monthly,
      targetDate: DateTime(year, month, 1),
      data: {
        'dailyTrend': dailyTrend,
        'totalTasks': totalTasks,
        'topAlbums': topAlbums,
      },
    );
  }
  
  /// アニュアルレポートを作成
  factory PlaybackReport.annual({
    required int year,
    required int totalTasks,
    required int totalMinutes,
    required List<Map<String, dynamic>> topAlbums,
    required List<Map<String, dynamic>> topTasks,
    required int maxStreakDays,
    required String peakMonth,
  }) {
    return PlaybackReport(
      type: ReportType.annual,
      targetDate: DateTime(year, 1, 1),
      data: {
        'totalTasks': totalTasks,
        'totalMinutes': totalMinutes,
        'topAlbums': topAlbums,
        'topTasks': topTasks,
        'maxStreakDays': maxStreakDays,
        'peakMonth': peakMonth,
      },
    );
  }
  
  @override
  String toString() {
    return 'PlaybackReport(type: $type, date: $targetDate, data: $data)';
  }
}