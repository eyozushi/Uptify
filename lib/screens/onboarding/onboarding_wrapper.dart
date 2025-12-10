// screens/onboarding/onboarding_wrapper.dart - 修正版（ArtistNameScreen画像対応）
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import '../../services/data_service.dart';
import 'welcome_screen.dart';
import 'artist_name_screen.dart';
import 'dream_input_screen.dart';
import 'image_selection_screen.dart';
import 'actions_setup_screen.dart';
import 'completion_screen.dart';

class OnboardingWrapper extends StatefulWidget {
  final VoidCallback onCompleted;

  const OnboardingWrapper({
    super.key,
    required this.onCompleted,
  });

  @override
  State<OnboardingWrapper> createState() => _OnboardingWrapperState();
}

class _OnboardingWrapperState extends State<OnboardingWrapper> {
  final DataService _dataService = DataService();
  final PageController _pageController = PageController();
  
  // オンボーディングデータ
  String? _artistName;
  String? _dreamTitle;
  Uint8List? _profileImageBytes; // 顔写真（プロフィール画像）
  Uint8List? _idealImageBytes;   // 理想像の写真
  List<String> _actions = [];
  
  int _currentStep = 0;
  final int _totalSteps = 6; // Welcome + Artist + Dream + Image + Actions + Completion
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeOnboarding();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _initializeOnboarding() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 500));
      
      setState(() {
        _isLoading = false;
      });
      
      print('✓ オンボーディング初期化完了');
    } catch (e) {
      setState(() {
        _errorMessage = 'オンボーディングの初期化に失敗しました: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _nextStep() async {
  if (_currentStep < _totalSteps - 1) {
    setState(() {
      _currentStep++;
    });
    
    await _pageController.nextPage( // 🔄 animateToPage → nextPage に戻す
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
    );
    
    print('次のステップに進みました: Step ${_currentStep + 1}');
  }
}

Future<void> _previousStep() async {
  if (_currentStep > 0) {
    setState(() {
      _currentStep--;
    });
    
    await _pageController.previousPage( // 🔄 animateToPage → previousPage に戻す
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
    );
    
    print('前のステップに戻りました: Step ${_currentStep + 1}');
  }
}
  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Step 0: ウェルカム画面のコールバック
  Future<void> _onWelcomeGetStarted() async {
    HapticFeedback.lightImpact();
    await _nextStep();
  }

  Future<void> _onWelcomeSkip() async {
    final confirmed = await _showSkipConfirmationDialog();
    if (confirmed == true) {
      try {
        await _completeOnboardingWithDefaults();
      } catch (e) {
        _showError('スキップに失敗しました: $e');
      }
    }
  }

  // Step 1: アーティスト名入力のコールバック（顔写真も含む）
  Future<void> _onArtistNameNext(String artistName, Uint8List? profileImageBytes) async {
  // キーボードを閉じる
  FocusScope.of(context).unfocus();
  
  // キーボードが完全に閉じるまで待つ
  await Future.delayed(const Duration(milliseconds: 300));
  
  HapticFeedback.lightImpact();
  
  setState(() {
    _artistName = artistName;
    _profileImageBytes = profileImageBytes;
  });
  
  print('アーティスト名を設定: $artistName');
  print('顔写真を設定: ${profileImageBytes != null ? "${profileImageBytes.length} bytes" : "なし"}');
  await _nextStep();
}

  // Step 2: 夢・理想像入力のコールバック
  Future<void> _onDreamInputNext(String dreamTitle) async {
  // キーボードを閉じる
  FocusScope.of(context).unfocus();
  
  // キーボードが完全に閉じるまで待つ
  await Future.delayed(const Duration(milliseconds: 300));
  
  HapticFeedback.lightImpact();
  
  setState(() {
    _dreamTitle = dreamTitle;
  });
  
  print('理想の自分を設定: $dreamTitle');
  await _nextStep();
}

  // Step 3: 理想像画像選択のコールバック
  Future<void> _onImageSelectionNext(Uint8List? idealImageBytes) async {
    HapticFeedback.lightImpact();
    
    setState(() {
      _idealImageBytes = idealImageBytes;
    });
    
    print('理想像画像を設定: ${idealImageBytes != null ? "${idealImageBytes.length} bytes" : "なし"}');
    await _nextStep();
  }

  // Step 4: 行動設定のコールバック
  Future<void> _onActionsSetupNext(List<String> actions) async {
  // キーボードを閉じる
  FocusScope.of(context).unfocus();
  
  // キーボードが完全に閉じるまで待つ
  await Future.delayed(const Duration(milliseconds: 300));
  
  HapticFeedback.lightImpact();
  
  setState(() {
    _actions = actions;
  });
  
  print('行動を設定: ${actions.length}個');
  await _nextStep();
}

  // Step 5: 完了画面のコールバック
  Future<void> _onCompletionFinish() async {
    try {
      await _completeOnboarding();
    } catch (e) {
      _showError('完了処理中にエラーが発生しました: $e');
    }
  }

  // オンボーディング完了処理
  Future<void> _completeOnboarding() async {
    try {
      // アクションをTaskItemに変換
      final tasks = _actions.take(4).toList();
      while (tasks.length < 4) {
        tasks.add(''); // 空のタスクで埋める
      }
      
      final taskItems = _dataService.getDefaultTasks();
      for (int i = 0; i < tasks.length && i < taskItems.length; i++) {
        if (tasks[i].isNotEmpty) {
          taskItems[i] = taskItems[i].copyWith(title: tasks[i]);
        }
      }
      
      // 画像データを保存
      if (_profileImageBytes != null) {
        await _dataService.saveIdealImageBytes(_profileImageBytes!);
        print('✓ 顔写真データを保存しました: ${_profileImageBytes!.length} bytes');
      }
      
      if (_idealImageBytes != null) {
        await _dataService.saveImageBytes(_idealImageBytes!);
        print('✓ 理想像画像データを保存しました: ${_idealImageBytes!.length} bytes');
      }
      
      // ユーザーデータを保存
      final data = {
        'idealSelf': _dreamTitle ?? 'Your Ideal Self',
        'artistName': _artistName ?? 'You',
        'todayLyrics': 'Live today to the fullest\nStep by step toward your ideal self\nSurpass who you were yesterday\nMake this moment shine',
        'aboutArtist': '${_artistName ?? "あなた"}, the protagonist of life\'s music. A unique artist creating new songs every day. Sometimes intense, sometimes gentle, always growing. Creating new melodies again today.',
        'albumImagePath': '',
        'tasks': taskItems.map((task) => task.toJson()).toList(),
        'onboardingCompleted': true,
        'onboardingCompletedAt': DateTime.now().toIso8601String(),
      };
      
      await _dataService.saveUserData(data);
      
      print('✓ オンボーディング完了: ${_dreamTitle} by ${_artistName}');
      widget.onCompleted();
    } catch (e) {
      print('❌ オンボーディング完了エラー: $e');
      rethrow;
    }
  }

  // デフォルトデータでオンボーディング完了
  Future<void> _completeOnboardingWithDefaults() async {
    try {
      final data = {
        'idealSelf': 'My ideal self growing every day',
        'artistName': 'You',
        'todayLyrics': 'Live today to the fullest\nStep by step toward your ideal self\nSurpass who you were yesterday\nMake this moment shine',
        'aboutArtist': 'あなた, the protagonist of life\'s music. A unique artist creating new songs every day. Sometimes intense, sometimes gentle, always growing. Creating new melodies again today.',
        'albumImagePath': '',
        'tasks': _dataService.getDefaultTasks().map((task) => task.toJson()).toList(),
        'onboardingCompleted': true,
        'onboardingCompletedAt': DateTime.now().toIso8601String(),
      };
      
      await _dataService.saveUserData(data);
      
      print('✓ オンボーディングスキップ完了');
      widget.onCompleted();
    } catch (e) {
      print('❌ オンボーディングスキップエラー: $e');
      rethrow;
    }
  }

  Future<bool?> _showSkipConfirmationDialog() async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Skip Onboarding',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Hiragino Sans',
          ),
        ),
        content: const Text(
          'Skip setup and start with default settings?\n\nYou can change settings anytime later.',
          style: TextStyle(
            color: Colors.white70,
            fontFamily: 'Hiragino Sans',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'キャンセル',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Skip',
              style: TextStyle(color: Color(0xFF1DB954)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingScreen();
    }

    if (_errorMessage != null) {
      return _buildErrorScreen();
    }

    return Scaffold(
      body: PageView(
        controller: _pageController,
        reverse: true, // 下から上へのアニメーション
        scrollDirection: Axis.vertical,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // Step 0: ウェルカム画面
          WelcomeScreen(
            onGetStarted: _onWelcomeGetStarted,
            onSkip: _onWelcomeSkip,
          ),
          
          // Step 1: アーティスト名入力画面（顔写真も含む）
          ArtistNameScreen(
            initialArtistName: _artistName,
            initialImageBytes: _profileImageBytes,
            onNext: _onArtistNameNext,
            onBack: _previousStep,
          ),
          
          // Step 2: 理想の自分入力画面（理想像のみ）
          DreamInputScreen(
            initialDreamTitle: _dreamTitle,
            onNext: _onDreamInputNext,
            onBack: _previousStep,
          ),
          
          // Step 3: 理想像画像選択画面
          ImageSelectionScreen(
            initialImageBytes: _idealImageBytes,
            onNext: _onImageSelectionNext,
            onBack: _previousStep,
          ),
          
          // Step 4: 行動設定画面
          ActionsSetupScreen(
            initialActions: _actions.isEmpty ? null : _actions,
            onNext: _onActionsSetupNext,
            onBack: _previousStep,
          ),
          
          // Step 5: 完了画面（理想像画像データを直接渡す）
          CompletionScreen(
            dreamTitle: _dreamTitle ?? 'Your Ideal Self',
            artistName: _artistName ?? 'You',
            imageBytes: _idealImageBytes, // 理想像画像データを渡す
            onComplete: _onCompletionFinish,
            onBack: _previousStep,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingScreen() {
  return const Scaffold(
    backgroundColor: Colors.black,
    body: SizedBox.shrink(),
  );
}

  Widget _buildErrorScreen() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF2D1B69),
              Color(0xFF1A1A2E),
              Color(0xFF000000),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 64,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'An error occurred',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Hiragino Sans',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 16,
                      fontFamily: 'Hiragino Sans',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _initializeOnboarding,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1DB954),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Retry',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Hiragino Sans',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}