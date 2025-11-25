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
  required List<int> dailyTrend,
  List<double>? weeklyAverage,
  List<String>? weekLabels,
  required int totalTasks,
  required List<Map<String, dynamic>> topAlbums,
  List<Map<String, dynamic>>? topTasks, // 🆕 追加
}) {
  return PlaybackReport(
    type: ReportType.monthly,
    targetDate: DateTime(year, month, 1),
    data: {
      'dailyTrend': dailyTrend,
      'weeklyAverage': weeklyAverage ?? <double>[],
      'weekLabels': weekLabels ?? <String>[],
      'totalTasks': totalTasks,
      'topAlbums': topAlbums,
      'topTasks': topTasks ?? <Map<String, dynamic>>[], // 🆕 追加
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
  
  // ========== Getter メソッド ==========
  
  /// デイリーレポート用のタスク履歴を取得
  List<TaskCompletion> get taskHistory {
    return (data['taskHistory'] as List<TaskCompletion>?) ?? [];
  }
  
  /// ウィークリーレポート用の日別カウントを取得
  Map<int, int> get dailyCounts {
    return (data['dailyCounts'] as Map<int, int>?) ?? {};
  }
  
  /// マンスリーレポート用の日別トレンドを取得
  List<int> get dailyTrend {
    return (data['dailyTrend'] as List<int>?) ?? [];
  }
  
  /// マンスリーレポート用の週別平均を取得
  List<double> get weeklyAverage {
    return (data['weeklyAverage'] as List<double>?) ?? [];
  }
  
  /// マンスリーレポート用の週ラベルを取得
  List<String> get weekLabels {
    return (data['weekLabels'] as List<String>?) ?? [];
  }
  
  /// 総タスク数を取得
  int get totalTasks {
    return (data['totalTasks'] as int?) ?? 0;
  }
  
  /// トップタスクを取得
  List<Map<String, dynamic>> get topTasks {
    return (data['topTasks'] as List<Map<String, dynamic>>?) ?? [];
  }
  
  /// トップアルバムを取得
  List<Map<String, dynamic>> get topAlbums {
    return (data['topAlbums'] as List<Map<String, dynamic>>?) ?? [];
  }
  
  /// 総再生時間（分）を取得
  int get totalMinutes {
    return (data['totalMinutes'] as int?) ?? 0;
  }
  
  /// 最長連続達成日数を取得
  int get maxStreakDays {
    return (data['maxStreakDays'] as int?) ?? 0;
  }
  
  /// ピーク月を取得
  String get peakMonth {
    return (data['peakMonth'] as String?) ?? '';
  }
  
  @override
  String toString() {
    return 'PlaybackReport(type: $type, date: $targetDate, data: $data)';
  }
}