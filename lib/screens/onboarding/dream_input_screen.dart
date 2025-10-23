// screens/onboarding/dream_input_screen.dart - 理想の自分のみを聞く版
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

class DreamInputScreen extends StatefulWidget {
  final String? initialDreamTitle;
  final Function(String dreamTitle) onNext;
  final VoidCallback? onBack;

  const DreamInputScreen({
    super.key,
    this.initialDreamTitle,
    required this.onNext,
    this.onBack,
  });

  @override
  State<DreamInputScreen> createState() => _DreamInputScreenState();
}

class _DreamInputScreenState extends State<DreamInputScreen>
    with TickerProviderStateMixin {
  late TextEditingController _dreamController;
  
  late AnimationController _animationController;
  late AnimationController _backgroundController;
  late Animation<double> _fadeInAnimation;
  late Animation<double> _slideUpAnimation;
  
  bool _isFormValid = false;
  
  // 励ましメッセージのリスト
  final List<String> _inspirationalMessages = [
    'あなたの心の中にある夢を\n音楽にして表現してみませんか？',
    'どんな未来の自分に\n出会いたいですか？',
    'あなたの人生という楽曲は\nどんな物語を奏でたいですか？',
    '理想の自分という\nメロディーを聞かせてください',
  ];
  
  int _currentMessageIndex = 0;

  @override
  void initState() {
    super.initState();
    
    // コントローラーの初期化
    _dreamController = TextEditingController(text: widget.initialDreamTitle ?? '');
    
    // アニメーションの初期化
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
    
    // 初期バリデーション
    _validateForm();
    
    // リスナー設定
    _dreamController.addListener(_validateForm);
    
    // アニメーション開始
    _animationController.forward();
    
    // メッセージローテーション開始
    _startMessageRotation();
  }

  @override
  void dispose() {
    _dreamController.dispose();
    _animationController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  void _validateForm() {
    setState(() {
      _isFormValid = _dreamController.text.trim().isNotEmpty;
    });
  }

  void _startMessageRotation() {
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _currentMessageIndex = (_currentMessageIndex + 1) % _inspirationalMessages.length;
        });
        _startMessageRotation();
      }
    });
  }

  void _onNextPressed() {
    if (_isFormValid) {
      HapticFeedback.lightImpact();
      widget.onNext(_dreamController.text.trim());
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
              'あなたの夢・理想像を入力してください',
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
            'Step 2 of 4',
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
        final iconPosition = screenHeight * 0.25; // 画面の25%の位置
        
        return Stack(
          children: [
            // アイコン（画面の上から25%の位置に固定）
            Positioned(
              top: iconPosition - 40, // アイコンの中心が25%の位置になるよう調整
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
                    Icons.star,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            
            // 質問文（画面の50%の位置）
            Positioned(
              top: screenHeight * 0.5 - 30, // 質問文が50%の位置になるよう調整
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'あなたの夢は？',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Hiragino Sans',
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 8),
                  
                  const Text(
                    '理想像は？',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Hiragino Sans',
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            // 入力フィールド（画面の75%の位置）
            Positioned(
              top: screenHeight * 0.75 - 30, // 入力フィールドが75%の位置になるよう調整
              left: 32,
              right: 32,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildInputField(),
                  
                  const SizedBox(height: 16),
                  
                  // 補足テキスト
                  Text(
                    'これがアルバムのタイトルになるよ',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.4),
                      fontFamily: 'Hiragino Sans',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInputField() {
    return Container(
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
        controller: _dreamController,
        maxLines: 2,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: Colors.white,
          fontFamily: 'Hiragino Sans',
          height: 1.4,
        ),
        decoration: InputDecoration(
          hintText: 'あなたの理想像',
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 16,
            fontFamily: 'Hiragino Sans',
            height: 1.4,
          ),
          filled: true,
          fillColor: Colors.white.withOpacity(0.15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: Color(0xFF1DB954),
              width: 3,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 20,
          ),
        ),
        onSubmitted: (value) {
          if (_isFormValid) {
            _onNextPressed();
          }
        },
      ),
    );
  }

  Widget _buildNextButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _isFormValid ? _onNextPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _isFormValid 
                ? const Color(0xFF1DB954) 
                : Colors.white.withOpacity(0.1),
            foregroundColor: Colors.white,
            elevation: _isFormValid ? 8 : 0,
            shadowColor: const Color(0xFF1DB954).withOpacity(0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          child: const Text(
            '次へ',
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