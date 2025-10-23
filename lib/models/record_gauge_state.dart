// models/record_gauge_state.dart
import 'package:flutter/foundation.dart';

/// Record Gauge（レコード・ゲージ）の状態を管理するモデル
/// 
/// ドリームアルバムの4タスク完了状態をレコード盤として視覚化するための状態管理
@immutable
class RecordGaugeState {
  /// 4トラックの完了状態（インデックス0〜3がトラック1〜4に対応）
  final List<bool> completedTracks;
  
  /// 全タスク完了フラグ（4タスクすべて完了でtrue）
  final bool isFullyCompleted;
  
  /// 対象日付
  final DateTime date;
  
  /// 完了したトラック数（0〜4）
  final int completedCount;

  const RecordGaugeState({
    required this.completedTracks,
    required this.isFullyCompleted,
    required this.date,
    required this.completedCount,
  });

  /// 初期状態（未完了）を作成
  factory RecordGaugeState.initial() {
    final today = DateTime.now();
    return RecordGaugeState(
      completedTracks: [false, false, false, false],
      isFullyCompleted: false,
      date: DateTime(today.year, today.month, today.day),
      completedCount: 0,
    );
  }

  /// 完了インデックスリストから状態を作成
  factory RecordGaugeState.fromCompletedIndices({
    required List<int> completedIndices,
    DateTime? date,
  }) {
    final tracks = [false, false, false, false];
    
    // 完了したインデックスをtrueに設定
    for (final index in completedIndices) {
      if (index >= 0 && index < 4) {
        tracks[index] = true;
      }
    }
    
    final completedCount = tracks.where((completed) => completed).length;
    final today = date ?? DateTime.now();
    
    return RecordGaugeState(
      completedTracks: tracks,
      isFullyCompleted: completedCount >= 4,
      date: DateTime(today.year, today.month, today.day),
      completedCount: completedCount,
    );
  }

  /// JSONからデシリアライズ
  factory RecordGaugeState.fromJson(Map<String, dynamic> json) {
    return RecordGaugeState(
      completedTracks: (json['completedTracks'] as List<dynamic>)
          .map((e) => e as bool)
          .toList(),
      isFullyCompleted: json['isFullyCompleted'] as bool,
      date: DateTime.parse(json['date'] as String),
      completedCount: json['completedCount'] as int,
    );
  }

  /// JSONへシリアライズ
  Map<String, dynamic> toJson() {
    return {
      'completedTracks': completedTracks,
      'isFullyCompleted': isFullyCompleted,
      'date': date.toIso8601String(),
      'completedCount': completedCount,
    };
  }

  /// コピーを作成
  RecordGaugeState copyWith({
    List<bool>? completedTracks,
    bool? isFullyCompleted,
    DateTime? date,
    int? completedCount,
  }) {
    return RecordGaugeState(
      completedTracks: completedTracks ?? this.completedTracks,
      isFullyCompleted: isFullyCompleted ?? this.isFullyCompleted,
      date: date ?? this.date,
      completedCount: completedCount ?? this.completedCount,
    );
  }

  /// 今日の日付かどうかを判定
  bool isToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return date.isAtSameMomentAs(today);
  }

  /// 特定のトラックが完了しているかを取得
  bool isTrackCompleted(int trackIndex) {
    if (trackIndex < 0 || trackIndex >= 4) return false;
    return completedTracks[trackIndex];
  }

  @override
  String toString() {
    return 'RecordGaugeState(date: ${date.toString().split(' ')[0]}, '
        'completed: $completedCount/4, fully: $isFullyCompleted)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is RecordGaugeState &&
        listEquals(other.completedTracks, completedTracks) &&
        other.isFullyCompleted == isFullyCompleted &&
        other.date == date &&
        other.completedCount == completedCount;
  }

  @override
  int get hashCode {
    return Object.hash(
      Object.hashAll(completedTracks),
      isFullyCompleted,
      date,
      completedCount,
    );
  }
}