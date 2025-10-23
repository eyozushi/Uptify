// models/onboarding_data.dart - オンボーディングで収集するデータ構造
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'task_item.dart';

class OnboardingData {
  String? dreamTitle;           // 理想の自分・大きな夢
  String? artistName;           // アーティスト名（ユーザー名）
  String? aboutDream;           // 夢についての詳細説明
  Uint8List? albumCoverBytes;   // アルバムカバー画像バイト配列
  String? albumCoverPath;       // アルバムカバー画像パス
  List<TaskItem> tasks;         // 4つの代表タスク
  String? inspirationalMessage; // ユーザーが設定する励ましメッセージ
  
  // 進捗管理用
  int currentStep;              // 現在のステップ（0-4）
  bool isCompleted;             // オンボーディング完了フラグ
  DateTime? startedAt;          // 開始日時
  DateTime? completedAt;        // 完了日時

  OnboardingData({
    this.dreamTitle,
    this.artistName,
    this.aboutDream,
    this.albumCoverBytes,
    this.albumCoverPath,
    List<TaskItem>? tasks,
    this.inspirationalMessage,
    this.currentStep = 0,
    this.isCompleted = false,
    this.startedAt,
    this.completedAt,
  }) : tasks = tasks ?? _getDefaultTasks();

  // デフォルトタスクを生成
  static List<TaskItem> _getDefaultTasks() {
    return [
      TaskItem(
        title: '',
        description: '',
        color: const Color(0xFF1DB954), // Spotify Green
        duration: 5,
      ),
      TaskItem(
        title: '',
        description: '',
        color: const Color(0xFF8B5CF6), // Purple
        duration: 5,
      ),
      TaskItem(
        title: '',
        description: '',
        color: const Color(0xFFEF4444), // Red
        duration: 5,
      ),
      TaskItem(
        title: '',
        description: '',
        color: const Color(0xFF06B6D4), // Cyan
        duration: 5,
      ),
    ];
  }

  // オンボーディング各ステップの完了チェック
  bool isStepCompleted(OnboardingStep step) {
    switch (step) {
      case OnboardingStep.welcome:
        return true; // ウェルカム画面は表示されれば完了
      case OnboardingStep.dreamInput:
        return dreamTitle != null && 
               dreamTitle!.trim().isNotEmpty &&
               artistName != null && 
               artistName!.trim().isNotEmpty;
      case OnboardingStep.albumCover:
        return albumCoverBytes != null || albumCoverPath != null;
      case OnboardingStep.tasksSetup:
        return tasks.where((task) => task.title.trim().isNotEmpty).length >= 2;
      case OnboardingStep.completion:
        return isCompleted;
    }
  }

  // 次のステップに進めるかチェック
  bool canProceedToNextStep() {
    final currentStepEnum = OnboardingStep.values[currentStep];
    return isStepCompleted(currentStepEnum);
  }

  // 全体の進捗率を取得（0.0 - 1.0）
  double getProgress() {
    int completedSteps = 0;
    for (final step in OnboardingStep.values) {
      if (isStepCompleted(step)) {
        completedSteps++;
      }
    }
    return completedSteps / OnboardingStep.values.length;
  }

  // データの妥当性チェック
  bool isValidForCompletion() {
    return dreamTitle != null &&
           dreamTitle!.trim().isNotEmpty &&
           artistName != null &&
           artistName!.trim().isNotEmpty &&
           tasks.where((task) => task.title.trim().isNotEmpty).length >= 2;
  }

  // メインアプリで使用するデータ形式に変換
  Map<String, dynamic> toMainAppData() {
    return {
      'idealSelf': dreamTitle ?? '理想の自分',
      'artistName': artistName ?? 'あなた',
      'todayLyrics': inspirationalMessage ?? _getDefaultLyrics(),
      'aboutArtist': aboutDream ?? _getDefaultAboutArtist(),
      'albumImagePath': albumCoverPath ?? '',
      'imageBytes': albumCoverBytes,
      'tasks': tasks.map((task) => task.toJson()).toList(),
      'onboardingCompletedAt': completedAt?.toIso8601String(),
    };
  }

  // JSONシリアライゼーション
  Map<String, dynamic> toJson() {
    return {
      'dreamTitle': dreamTitle,
      'artistName': artistName,
      'aboutDream': aboutDream,
      'albumCoverPath': albumCoverPath,
      'tasks': tasks.map((task) => task.toJson()).toList(),
      'inspirationalMessage': inspirationalMessage,
      'currentStep': currentStep,
      'isCompleted': isCompleted,
      'startedAt': startedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      // 画像バイトデータは別途処理
    };
  }

  // JSONからオブジェクト作成
  factory OnboardingData.fromJson(Map<String, dynamic> json) {
    return OnboardingData(
      dreamTitle: json['dreamTitle'],
      artistName: json['artistName'],
      aboutDream: json['aboutDream'],
      albumCoverPath: json['albumCoverPath'],
      tasks: (json['tasks'] as List<dynamic>?)
          ?.map((taskJson) => TaskItem.fromJson(taskJson))
          .toList() ?? _getDefaultTasks(),
      inspirationalMessage: json['inspirationalMessage'],
      currentStep: json['currentStep'] ?? 0,
      isCompleted: json['isCompleted'] ?? false,
      startedAt: json['startedAt'] != null 
          ? DateTime.parse(json['startedAt']) 
          : null,
      completedAt: json['completedAt'] != null 
          ? DateTime.parse(json['completedAt']) 
          : null,
    );
  }

  // コピーメソッド
  OnboardingData copyWith({
    String? dreamTitle,
    String? artistName,
    String? aboutDream,
    Uint8List? albumCoverBytes,
    String? albumCoverPath,
    List<TaskItem>? tasks,
    String? inspirationalMessage,
    int? currentStep,
    bool? isCompleted,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return OnboardingData(
      dreamTitle: dreamTitle ?? this.dreamTitle,
      artistName: artistName ?? this.artistName,
      aboutDream: aboutDream ?? this.aboutDream,
      albumCoverBytes: albumCoverBytes ?? this.albumCoverBytes,
      albumCoverPath: albumCoverPath ?? this.albumCoverPath,
      tasks: tasks ?? this.tasks,
      inspirationalMessage: inspirationalMessage ?? this.inspirationalMessage,
      currentStep: currentStep ?? this.currentStep,
      isCompleted: isCompleted ?? this.isCompleted,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  // デフォルトの歌詞メッセージ
  String _getDefaultLyrics() {
    return '今日という日を大切に生きよう\n'
           '一歩ずつ理想の自分に近づいていく\n'
           '昨日の自分を超えていこう\n'
           '今この瞬間を輝かせよう';
  }

  // デフォルトのアーティスト紹介文
  String _getDefaultAboutArtist() {
    return 'あなたの人生という音楽の主人公。'
           '毎日新しい楽曲を作り続ける唯一無二のアーティスト。'
           '時には激しく、時には優しく、常に成長を続けている。'
           '今日もまた新しいメロディーを奏でている。';
  }

  @override
  String toString() {
    return 'OnboardingData('
           'dreamTitle: $dreamTitle, '
           'artistName: $artistName, '
           'currentStep: $currentStep, '
           'isCompleted: $isCompleted, '
           'progress: ${(getProgress() * 100).toStringAsFixed(1)}%'
           ')';
  }
}

// オンボーディングのステップを列挙
enum OnboardingStep {
  welcome,      // ウェルカム画面
  dreamInput,   // 理想の自分入力
  albumCover,   // アルバムカバー設定
  tasksSetup,   // タスク設定
  completion,   // 完了画面
}

// オンボーディングステップの日本語名
extension OnboardingStepExtension on OnboardingStep {
  String get title {
    switch (this) {
      case OnboardingStep.welcome:
        return 'ようこそ';
      case OnboardingStep.dreamInput:
        return '理想の自分';
      case OnboardingStep.albumCover:
        return 'アルバムカバー';
      case OnboardingStep.tasksSetup:
        return 'タスク設定';
      case OnboardingStep.completion:
        return '完了';
    }
  }

  String get description {
    switch (this) {
      case OnboardingStep.welcome:
        return 'Uptifyの世界へようこそ';
      case OnboardingStep.dreamInput:
        return 'あなたの夢を教えてください';
      case OnboardingStep.albumCover:
        return '理想を象徴する一枚を';
      case OnboardingStep.tasksSetup:
        return '夢を叶える代表曲を';
      case OnboardingStep.completion:
        return 'あなたのアルバムが完成';
    }
  }

  int get stepNumber => index;
  int get totalSteps => OnboardingStep.values.length;
}