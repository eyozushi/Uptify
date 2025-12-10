// screens/onboarding/actions_setup_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

class ActionsSetupScreen extends StatefulWidget {
  final List<String>? initialActions;
  final Function(List<String> actions) onNext;
  final VoidCallback? onBack;

  const ActionsSetupScreen({
    super.key,
    this.initialActions,
    required this.onNext,
    this.onBack,
  });

  @override
  State<ActionsSetupScreen> createState() => _ActionsSetupScreenState();
}

class _ActionsSetupScreenState extends State<ActionsSetupScreen>
    with TickerProviderStateMixin {
  late List<TextEditingController> _controllers;
  late AnimationController _animationController;
  late AnimationController _backgroundController;
  late Animation<double> _fadeInAnimation;
  late Animation<double> _slideUpAnimation;
  
  int _completedActions = 0;
  int _selectedTaskIndex = 0; // 現在選択されているタスクのインデックス
  
  final List<String> _placeholders = [
    'e.g., Read for 10 minutes',
    'e.g., Work out',
    'e.g., Learn a new skill',
    'e.g., Read a news',
  ];
  
  final List<Color> _actionColors = [
    const Color(0xFF1DB954),
    const Color(0xFF8B5CF6),
    const Color(0xFFEF4444),
    const Color(0xFF06B6D4),
  ];

  @override
  void initState() {
    super.initState();
    
    // コントローラー初期化
    _controllers = List.generate(4, (index) {
      final initialText = widget.initialActions != null && 
                         index < widget.initialActions!.length 
                         ? widget.initialActions![index] 
                         : '';
      return TextEditingController(text: initialText);
    });
    
    // アニメーション初期化
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    )..repeat();
    
    _fadeInAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));
    
    _slideUpAnimation = Tween<double>(
      begin: 30.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
    ));
    
    // 各コントローラーにリスナー追加
    for (var controller in _controllers) {
      controller.addListener(_updateCompletedCount);
    }
    
    // 初期完了数計算
    _updateCompletedCount();
    
    // アニメーション開始
    _animationController.forward();
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    _animationController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  void _updateCompletedCount() {
    final completed = _controllers
        .where((controller) => controller.text.trim().isNotEmpty)
        .length;
    
    if (completed != _completedActions) {
      setState(() {
        _completedActions = completed;
      });
    }
  }

  void _onNextPressed() {
  final actions = _controllers
      .map((controller) => controller.text.trim())
      .where((text) => text.isNotEmpty)
      .toList();
  
  if (actions.length >= 1) {
    HapticFeedback.lightImpact();
    widget.onNext(actions);
  } else {
    _showValidationMessage();
  }
}

  void _showValidationMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white),
            SizedBox(width: 12),
            Text(
              'Please enter at least one action',
              style: TextStyle(fontFamily: 'Hiragino Sans'),
            ),
          ],
        ),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ヘッダー
            _buildHeader(),
            
            // メインコンテンツ
            Expanded(
              child: _buildMainContent(),
            ),
            
            // 次へボタン
            _buildNextButton(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (widget.onBack != null)
            IconButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                widget.onBack!();
              },
              icon: const Icon(
                Icons.keyboard_arrow_down,
                color: Colors.white,
                size: 28,
              ),
            ),
          const Spacer(),
          Text(
            'Step 4 of 4',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
              fontFamily: 'Hiragino Sans',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenHeight = constraints.maxHeight;
        
        return Stack(
          children: [
            // アイコン（画面の上から25%の位置に固定）
            Positioned(
              top: screenHeight * 0.25 - 40,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1DB954),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.list_alt,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            
            // 質問文（画面の50%の位置）
            Positioned(
              top: screenHeight * 0.5 - 20,
              left: 0,
              right: 0,
              child: const Text(
                'What will you do to reach your ideal?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'Hiragino Sans',
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            // 番号選択と入力フィールド（画面の75%の位置）
Positioned(
  top: screenHeight * 0.77 - 60, // 🔄 0.75 → 0.60 に変更（上に移動）
  left: 32,
  right: 32,
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      // 番号選択ボタン
      _buildNumberSelector(),
      
      const SizedBox(height: 1), // 🔄 20 → 12 に変更（間隔を詰める）
      
      // 入力フィールド
      _buildCurrentTaskField(),
    ],
  ),
),
          ],
        );
      },
    );
  }

  Widget _buildNumberSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final isSelected = _selectedTaskIndex == index;
        final isCompleted = _controllers[index].text.trim().isNotEmpty;
        
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedTaskIndex = index;
            });
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            width: 30,
            height: 30,
            decoration: BoxDecoration(
  color: isSelected 
      ? const Color(0xFF1DB954) // 🔄 _actionColors[index] → 緑色
      : (isCompleted 
          ? const Color(0xFF1DB954).withOpacity(0.3) // 🔄 緑色
          : Colors.white.withOpacity(0.2)),
  shape: BoxShape.circle,
  border: null, // 🔄 isSelected の border を削除
),
            child: Center(
              child: isCompleted && !isSelected
                  ? const Icon(
                      Icons.check,
                      size: 20,
                      color: Colors.white,
                    )
                  : Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildCurrentTaskField() {
    final isCompleted = _controllers[_selectedTaskIndex].text.trim().isNotEmpty;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ラベル
        Row(
          children: [
            Text(
  'Action ${_selectedTaskIndex + 1}',
  style: const TextStyle( // 🔄 TextStyle を const に
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Color(0xFF1DB954), // 🔄 _actionColors[index] → 緑色
    fontFamily: 'Hiragino Sans',
  ),
),
            if (_selectedTaskIndex >= 1) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Optional',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        
        const SizedBox(height: 12),
        
        // 入力フィールド
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: TextField(
            controller: _controllers[_selectedTaskIndex],
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
              fontFamily: 'Hiragino Sans',
            ),
            decoration: InputDecoration(
              hintText: _placeholders[_selectedTaskIndex],
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontFamily: 'Hiragino Sans',
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.15),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNextButton() {
    final isValid = _completedActions >= 1;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: isValid ? _onNextPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: isValid 
                ? const Color(0xFF1DB954) 
                : Colors.white.withOpacity(0.1),
            foregroundColor: Colors.white,
            elevation: isValid ? 8 : 0,
            shadowColor: const Color(0xFF1DB954).withOpacity(0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          child: const Text(
            'Release Your Album',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              fontFamily: 'Hiragino Sans',
            ),
          ),
        ),
      ),
    );
  }
}