// models/notification_config.dart - 改善版
class NotificationConfig {
  final bool isHabitBreakerEnabled;
  final int habitBreakerInterval;
  final List<String> habitBreakerMessages;

  const NotificationConfig({
    this.isHabitBreakerEnabled = false,
    this.habitBreakerInterval = 1,
    this.habitBreakerMessages = const [
      // 🎯 意識喚起系（5個）- 現在の行動への気づきを促す
      '今、何をしていますか？',
      'この5分間で何を達成しましたか？',
      'スマホを見る時間、タスクに使いませんか？',
      '今の行動は、本当に必要ですか？',
      '今この瞬間、何に集中していますか？',
      
      // 🚀 目標志向系（4個）- 具体的な目標達成を意識させる
      '理想の自分に近づいていますか？',
      '今日のタスク、進んでいますか？',
      'アルバムの次のトラックを再生しましょう',
      '夢に近づく行動を始めませんか？',
      
      // ⏰ 時間管理系（4個）- 時間の使い方を見直させる
      'この15分を、どう使いますか？',
      '限られた時間、大切に使いましょう',
      '今の時間の使い方、満足ですか？',
      '時間は戻らない。今を活かしましょう',
      
      // 🔄 習慣改善系（4個）- 悪い習慣からの離脱を促す
      'SNSをやめて、タスクを始めませんか？',
      'だらだらタイム、終了しませんか？',
      'スクロールより、成長を選びませんか？',
      '習慣を変える瞬間は、今です',
      
      // ✨ モチベーション系（3個）- 前向きな気持ちを促進
      '小さな一歩が、大きな変化を生みます',
      '行動した分だけ、未来が変わります',
      'あなたならできる。始めてみましょう',
    ],
  });

  // JSON変換用
  Map<String, dynamic> toJson() {
    return {
      'isHabitBreakerEnabled': isHabitBreakerEnabled,
      'habitBreakerInterval': habitBreakerInterval,
      'habitBreakerMessages': habitBreakerMessages,
    };
  }

  // JSONから復元
  factory NotificationConfig.fromJson(Map<String, dynamic> json) {
    return NotificationConfig(
      isHabitBreakerEnabled: json['isHabitBreakerEnabled'] ?? false,
      habitBreakerInterval: json['habitBreakerInterval'] ?? 1,
      habitBreakerMessages: json['habitBreakerMessages'] != null
          ? List<String>.from(json['habitBreakerMessages'])
          : const [
              // デフォルトメッセージも新しいリストに更新
              '今、何をしていますか？',
              'この5分間で何を達成しましたか？',
              'スマホを見る時間、タスクに使いませんか？',
              '今の行動は、本当に必要ですか？',
              '今この瞬間、何に集中していますか？',
              '理想の自分に近づいていますか？',
              '今日のタスク、進んでいますか？',
              'アルバムの次のトラックを再生しましょう',
              '夢に近づく行動を始めませんか？',
              'この15分を、どう使いますか？',
              '限られた時間、大切に使いましょう',
              '今の時間の使い方、満足ですか？',
              '時間は戻らない。今を活かしましょう',
              'SNSをやめて、タスクを始めませんか？',
              'だらだらタイム、終了しませんか？',
              'スクロールより、成長を選びませんか？',
              '習慣を変える瞬間は、今です',
              '小さな一歩が、大きな変化を生みます',
              '行動した分だけ、未来が変わります',
              'あなたならできる。始めてみましょう',
            ],
    );
  }

  // copyWith メソッド（修正版）
  NotificationConfig copyWith({
    bool? isHabitBreakerEnabled,
    int? habitBreakerInterval,
    List<String>? habitBreakerMessages,
  }) {
    // 🆕 追加: 間隔のバリデーション（15/30/60以外は最も近い値に丸める）
    int validatedInterval = habitBreakerInterval ?? this.habitBreakerInterval;
    if (habitBreakerInterval != null) {
      if (habitBreakerInterval <= 15) {
        validatedInterval = 15;
      } else if (habitBreakerInterval <= 30) {
        validatedInterval = 30;
      } else {
        validatedInterval = 60;
      }
    }
    
    return NotificationConfig(
      isHabitBreakerEnabled: isHabitBreakerEnabled ?? this.isHabitBreakerEnabled,
      habitBreakerInterval: validatedInterval,  // 🔧 修正: バリデーション済みの値を使用
      habitBreakerMessages: habitBreakerMessages ?? this.habitBreakerMessages,
    );
  }
}