// screens/onboarding/welcome_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

class WelcomeScreen extends StatefulWidget {
  final VoidCallback onGetStarted;
  final VoidCallback? onSkip;

  const WelcomeScreen({
    super.key,
    required this.onGetStarted,
    this.onSkip,
  });

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _backgroundController;
  late AnimationController _contentController;
  late AnimationController _playButtonController;
  late Animation<double> _fadeInAnimation;
  late Animation<double> _slideUpAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    
    // 背景アニメーション（継続的に回転）
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
    
    // コンテンツアニメーション - パッと表示
    _contentController = AnimationController(
      duration: const Duration(milliseconds: 150), // 500ms → 150ms に短縮
      vsync: this,
    );
    
    // 再生ボタンの回転アニメーション
    _playButtonController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    // フェードインアニメーション - 素早く表示
    _fadeInAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _contentController,
      curve: Curves.easeOut,
    ));
    
    // スケールアニメーションを削除し、通常サイズ固定
    _slideUpAnimation = Tween<double>(
      begin: 1.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _contentController,
      curve: Curves.elasticOut,
    ));
    
    // 回転アニメーション（再生ボタン→上向き矢印）
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: -math.pi / 2, // 90度反時計回り（元に戻す）
    ).animate(CurvedAnimation(
      parent: _playButtonController,
      curve: Curves.easeInOut,
    ));
    
    // アニメーション開始
    _contentController.forward();
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _contentController.dispose();
    _playButtonController.dispose();
    super.dispose();
  }

  void _onPlayButtonTapped() async {
    HapticFeedback.lightImpact();
    
    // 回転アニメーション実行
    await _playButtonController.forward();
    
    // 少し間をおいてから次の画面へ
    await Future.delayed(const Duration(milliseconds: 300));
    
    widget.onGetStarted();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // アニメーション背景
          _buildAnimatedBackground(),
          
          // メインコンテンツ（SafeAreaを削除）
          _buildMainContent(),
        ],
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return Container(
      color: Colors.black,
    );
  }

  Widget _buildSkipButton() {
    // スキップボタンを削除
    return const SizedBox.shrink();
  }

  Widget _buildMainContent() {
    return Stack(
      children: [
        // 再生ボタン（位置固定、独立）
        Center(
          child: AnimatedBuilder(
            animation: _fadeInAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeInAnimation.value,
                child: _buildPlayButton(),
              );
            },
          ),
        ),
        
        // 文字表示（再生ボタンの下に配置）
        Center(
          child: AnimatedBuilder(
            animation: _fadeInAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeInAnimation.value * 0.8,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 250), // 再生ボタンとの間隔を広げる
                    
                    const Text(
                      'Tap',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w300,
                        color: Colors.white70,
                        fontFamily: 'Hiragino Sans',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: 30),
                    
                    const Text(
                      'Just like playing music',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w300,
                        color: Colors.white,
                        fontFamily: 'Hiragino Sans',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: 6),
                    
                    const Text(
                      'Play Your Tasks',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w300,
                        color: Colors.white,
                        fontFamily: 'Hiragino Sans',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPlayButton() {
    return GestureDetector(
      onTap: _onPlayButtonTapped,
      child: AnimatedBuilder(
        animation: _rotationAnimation,
        builder: (context, child) {
          return Transform.rotate(
            angle: _rotationAnimation.value,
            child: Container(
              width: 140,
              height: 140,
              decoration: const BoxDecoration(
                color: Color(0xFF1DB954),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow,
                size: 80,
                color: Colors.white,
              ),
            ),
          );
        },
      ),
    );
  }
}

// 丸みを帯びた再生ボタンを描画するカスタムペインター
class _RoundedPlayButtonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // 三角形の基本パラメータ
    final width = size.width * 0.55;
    final height = size.height * 0.65;
    final centerX = size.width / 2 + 3; // 視覚的中心調整のため少し右に
    final centerY = size.height / 2;
    
    // 三角形の頂点
    final leftTop = Offset(centerX - width/2, centerY - height/2);
    final leftBottom = Offset(centerX - width/2, centerY + height/2);
    final right = Offset(centerX + width/2, centerY);
    
    // 丸みを帯びた三角形のパス
    final path = Path();
    
    // 左上から開始
    path.moveTo(leftTop.dx + 4, leftTop.dy + 4);
    
    // 左上から右の頂点への線（上側）
    path.quadraticBezierTo(
      leftTop.dx, leftTop.dy,
      right.dx - 6, right.dy - 4
    );
    
    // 右の先端部分（丸い先端）
    path.quadraticBezierTo(
      right.dx + 4, right.dy,  // 制御点を右にずらして丸みを作る
      right.dx - 6, right.dy + 4
    );
    
    // 右の頂点から左下への線（下側）
    path.quadraticBezierTo(
      leftBottom.dx, leftBottom.dy,
      leftBottom.dx + 4, leftBottom.dy - 4
    );
    
    // 左の縦線（丸い左側）
    path.quadraticBezierTo(
      leftTop.dx - 3, centerY,
      leftTop.dx + 4, leftTop.dy + 4
    );
    
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// 浮遊するパーティクルを描画するカスタムペインター
class _FloatingParticlesPainter extends CustomPainter {
  final double animationValue;

  _FloatingParticlesPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    // 複数のパーティクルを描画
    for (int i = 0; i < 20; i++) {
      final x = size.width * ((i * 0.618 + animationValue * 0.1) % 1.0);
      final y = size.height * ((i * 0.382 + animationValue * 0.05) % 1.0);
      final radius = (math.sin(animationValue * 2 * math.pi + i) + 1) * 2 + 1;
      
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_FloatingParticlesPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}