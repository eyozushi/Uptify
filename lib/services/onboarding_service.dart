// services/onboarding_service.dart - オンボーディングフロー管理サービス
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../models/onboarding_data.dart';
import '../models/task_item.dart';
import 'data_service.dart';

class OnboardingService extends ChangeNotifier {
  static const String _onboardingKey = 'onboarding_data';
  static const String _completionKey = 'onboarding_completed';
  
  final DataService _dataService = DataService();
  OnboardingData _data = OnboardingData();
  
  // ゲッター
  OnboardingData get data => _data;
  int get currentStep => _data.currentStep;
  bool get isCompleted => _data.isCompleted;
  double get progress => _data.getProgress();
  
  // 初期化（アプリ起動時に呼び出す）
  Future<void> initialize() async {
    await _loadOnboardingData();
  }

  // オンボーディングが必要かどうかをチェック
  Future<bool> shouldShowOnboarding() async {
    try {
      // DataServiceから完了フラグを確認
      final userData = await _dataService.loadUserData();
      final isCompleted = userData['onboardingCompleted'] ?? false;
      return !isCompleted;
    } catch (e) {
      print('オンボーディングチェックエラー: $e');
      return true; // エラーの場合は安全側でオンボーディング表示
    }
  }

  // オンボーディング開始
  Future<void> startOnboarding() async {
    _data = OnboardingData(
      startedAt: DateTime.now(),
      currentStep: 0,
    );
    await _saveOnboardingData();
    notifyListeners();
    
    print('オンボーディング開始: ${_data.toString()}');
  }

  // 次のステップに進む
  Future<bool> proceedToNextStep() async {
    if (!_data.canProceedToNextStep()) {
      print('次のステップに進む条件が満たされていません');
      return false;
    }

    if (_data.currentStep < OnboardingStep.values.length - 1) {
      _data = _data.copyWith(currentStep: _data.currentStep + 1);
      await _saveOnboardingData();
      notifyListeners();
      
      print('次のステップに進みました: Step ${_data.currentStep}');
      return true;
    }
    
    return false;
  }

  // 前のステップに戻る
  Future<void> goToPreviousStep() async {
    if (_data.currentStep > 0) {
      _data = _data.copyWith(currentStep: _data.currentStep - 1);
      await _saveOnboardingData();
      notifyListeners();
      
      print('前のステップに戻りました: Step ${_data.currentStep}');
    }
  }

  // 特定のステップにジャンプ
  Future<void> jumpToStep(int step) async {
    if (step >= 0 && step < OnboardingStep.values.length) {
      _data = _data.copyWith(currentStep: step);
      await _saveOnboardingData();
      notifyListeners();
      
      print('ステップ${step}にジャンプしました');
    }
  }

  // 理想の自分とアーティスト名を更新
  Future<void> updateDreamAndArtist({
    required String dreamTitle,
    required String artistName,
    String? aboutDream,
  }) async {
    _data = _data.copyWith(
      dreamTitle: dreamTitle,
      artistName: artistName,
      aboutDream: aboutDream,
    );
    await _saveOnboardingData();
    notifyListeners();
    
    print('理想とアーティスト名を更新: $dreamTitle by $artistName');
  }

  // アルバムカバー画像を更新
  Future<void> updateAlbumCover({
    Uint8List? imageBytes,
    String? imagePath,
  }) async {
    _data = _data.copyWith(
      albumCoverBytes: imageBytes,
      albumCoverPath: imagePath,
    );
    await _saveOnboardingData();
    notifyListeners();
    
    print('アルバムカバーを更新: ${imageBytes != null ? '画像データあり' : 'パスのみ'}');
  }

  // タスクを更新
  Future<void> updateTask(int index, TaskItem task) async {
    if (index >= 0 && index < _data.tasks.length) {
      final updatedTasks = List<TaskItem>.from(_data.tasks);
      updatedTasks[index] = task;
      
      _data = _data.copyWith(tasks: updatedTasks);
      await _saveOnboardingData();
      notifyListeners();
      
      print('タスク${index + 1}を更新: ${task.title}');
    }
  }

  // 全てのタスクを更新
  Future<void> updateAllTasks(List<TaskItem> tasks) async {
    if (tasks.length == 4) {
      _data = _data.copyWith(tasks: tasks);
      await _saveOnboardingData();
      notifyListeners();
      
      print('全タスクを更新: ${tasks.map((t) => t.title).join(', ')}');
    }
  }

  // 励ましメッセージを更新
  Future<void> updateInspirationalMessage(String message) async {
    _data = _data.copyWith(inspirationalMessage: message);
    await _saveOnboardingData();
    notifyListeners();
    
    print('励ましメッセージを更新: $message');
  }

  // オンボーディング完了
  Future<bool> completeOnboarding() async {
    if (!_data.isValidForCompletion()) {
      print('オンボーディング完了の条件が満たされていません');
      return false;
    }

    // 完了時刻を設定
    _data = _data.copyWith(
      isCompleted: true,
      completedAt: DateTime.now(),
    );

    try {
      // メインアプリのデータ形式に変換して保存
      final mainAppData = _data.toMainAppData();
      mainAppData['onboardingCompleted'] = true;
      
      await _dataService.saveUserData(mainAppData);
      await _saveOnboardingData();
      
      notifyListeners();
      
      print('オンボーディング完了: ${_data.toString()}');
      return true;
    } catch (e) {
      print('オンボーディング完了エラー: $e');
      return false;
    }
  }

  // オンボーディングをスキップ（デフォルトデータで完了）
  Future<void> skipOnboarding() async {
    _data = OnboardingData(
      dreamTitle: '毎日成長する理想の自分',
      artistName: 'あなた',
      aboutDream: 'あなたの人生という音楽の主人公。毎日新しい楽曲を作り続ける唯一無二のアーティスト。',
      inspirationalMessage: '今日という日を大切に生きよう\n一歩ずつ理想の自分に近づいていく',
      isCompleted: true,
      startedAt: DateTime.now(),
      completedAt: DateTime.now(),
      currentStep: OnboardingStep.values.length - 1,
    );

    // デフォルトタスクを設定
    _data = _data.copyWith(tasks: [
      TaskItem(title: '朝のルーティン', description: '健康的な一日の始まり', color: const Color(0xFF1DB954), duration: 3),
      TaskItem(title: '仕事・学習', description: '集中して取り組む時間', color: const Color(0xFF8B5CF6), duration: 5),
      TaskItem(title: '運動・健康', description: '体を動かして活力をつける', color: const Color(0xFFEF4444), duration: 3),
      TaskItem(title: 'リラックス', description: '心を落ち着かせる時間', color: const Color(0xFF06B6D4), duration: 1),
    ]);

    await completeOnboarding();
    
    print('オンボーディングをスキップしました');
  }

  // リセット（開発・テスト用）
  Future<void> resetOnboarding() async {
    _data = OnboardingData();
    await _clearOnboardingData();
    notifyListeners();
    
    print('オンボーディングをリセットしました');
  }

  // プライベートメソッド: オンボーディングデータを読み込み
  Future<void> _loadOnboardingData() async {
    try {
      // メモリ内ストレージから読み込み（DataServiceパターンに合わせる）
      // 実際の実装では、DataServiceを拡張してオンボーディングデータも管理
      print('オンボーディングデータを読み込み中...');
      
      // 今回はメモリ内に保存されたデータがないため、デフォルトを使用
      _data = OnboardingData();
    } catch (e) {
      print('オンボーディングデータ読み込みエラー: $e');
      _data = OnboardingData();
    }
  }

  // プライベートメソッド: オンボーディングデータを保存
  Future<void> _saveOnboardingData() async {
    try {
      // DataServiceのメモリストレージパターンに合わせて保存
      // 画像データも含めて保存
      print('オンボーディングデータを保存中...');
      // 実際の保存処理はDataServiceで実装
    } catch (e) {
      print('オンボーディングデータ保存エラー: $e');
    }
  }

  // プライベートメソッド: オンボーディングデータをクリア
  Future<void> _clearOnboardingData() async {
    try {
      print('オンボーディングデータをクリア中...');
      // 実際のクリア処理はDataServiceで実装
    } catch (e) {
      print('オンボーディングデータクリアエラー: $e');
    }
  }

  // 特定のステップが完了しているかチェック
  bool isStepCompleted(OnboardingStep step) {
    return _data.isStepCompleted(step);
  }

  // 現在のステップが完了しているかチェック
  bool isCurrentStepCompleted() {
    final currentStepEnum = OnboardingStep.values[_data.currentStep];
    return _data.isStepCompleted(currentStepEnum);
  }

  // デバッグ情報を取得
  Map<String, dynamic> getDebugInfo() {
    return {
      'currentStep': _data.currentStep,
      'progress': '${(progress * 100).toStringAsFixed(1)}%',
      'isCompleted': _data.isCompleted,
      'dreamTitle': _data.dreamTitle,
      'artistName': _data.artistName,
      'hasAlbumCover': _data.albumCoverBytes != null || _data.albumCoverPath != null,
      'completedTasks': _data.tasks.where((task) => task.title.trim().isNotEmpty).length,
      'canProceed': _data.canProceedToNextStep(),
      'isValid': _data.isValidForCompletion(),
    };
  }

  @override
  void dispose() {
    super.dispose();
  }
}