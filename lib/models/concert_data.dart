// models/concert_data.dart - コンサートデータモデル
class ConcertData {
  final int totalCompletedTasks;
  final int audienceCount;
  final double achievementRate;
  final DateTime lastUpdated;
  final Map<String, int> dailyCompletions; // 日別完了数（過去7日間など）
  
  const ConcertData({
    required this.totalCompletedTasks,
    required this.audienceCount,
    required this.achievementRate,
    required this.lastUpdated,
    this.dailyCompletions = const {},
  });
  
  // 空のデータ（初期状態）
  factory ConcertData.empty() {
    return ConcertData(
      totalCompletedTasks: 0,
      audienceCount: 0,
      achievementRate: 0.0,
      lastUpdated: DateTime.now(),
      dailyCompletions: {},
    );
  }
  
  // JSONからの復元
  factory ConcertData.fromJson(Map<String, dynamic> json) {
    return ConcertData(
      totalCompletedTasks: json['totalCompletedTasks'] ?? 0,
      audienceCount: json['audienceCount'] ?? 0,
      achievementRate: json['achievementRate']?.toDouble() ?? 0.0,
      lastUpdated: DateTime.parse(json['lastUpdated'] ?? DateTime.now().toIso8601String()),
      dailyCompletions: Map<String, int>.from(json['dailyCompletions'] ?? {}),
    );
  }
  
  // JSONへの変換
  Map<String, dynamic> toJson() {
    return {
      'totalCompletedTasks': totalCompletedTasks,
      'audienceCount': audienceCount,
      'achievementRate': achievementRate,
      'lastUpdated': lastUpdated.toIso8601String(),
      'dailyCompletions': dailyCompletions,
    };
  }
  
  // データ更新用のcopyWithメソッド
  ConcertData copyWith({
    int? totalCompletedTasks,
    int? audienceCount,
    double? achievementRate,
    DateTime? lastUpdated,
    Map<String, int>? dailyCompletions,
  }) {
    return ConcertData(
      totalCompletedTasks: totalCompletedTasks ?? this.totalCompletedTasks,
      audienceCount: audienceCount ?? this.audienceCount,
      achievementRate: achievementRate ?? this.achievementRate,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      dailyCompletions: dailyCompletions ?? this.dailyCompletions,
    );
  }
  
  @override
  String toString() {
    return 'ConcertData(totalCompletedTasks: $totalCompletedTasks, audienceCount: $audienceCount, achievementRate: ${(achievementRate * 100).toStringAsFixed(1)}%)';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConcertData &&
        other.totalCompletedTasks == totalCompletedTasks &&
        other.audienceCount == audienceCount &&
        other.achievementRate == achievementRate &&
        other.lastUpdated == lastUpdated;
  }
  
  @override
  int get hashCode {
    return totalCompletedTasks.hashCode ^
        audienceCount.hashCode ^
        achievementRate.hashCode ^
        lastUpdated.hashCode;
  }
}