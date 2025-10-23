// widgets/concert_stage.dart - CustomPainter内動画描画版
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class ConcertStage extends StatefulWidget {
  final double width;
  final double height;
  final String? videoAssetPath;
  
  const ConcertStage({
    super.key,
    required this.width,
    required this.height,
    this.videoAssetPath,
  });

  @override
  State<ConcertStage> createState() => _ConcertStageState();
}

class _ConcertStageState extends State<ConcertStage> with TickerProviderStateMixin {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    )..repeat();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    if (widget.videoAssetPath != null) {
      try {
        print('🎬 動画初期化開始: ${widget.videoAssetPath}');
        _videoController = VideoPlayerController.asset(widget.videoAssetPath!);
        await _videoController!.initialize();
        print('🎬 動画初期化完了');
        await _videoController!.setLooping(true);
        await _videoController!.play();
        print('🎬 動画再生開始');
        
        if (mounted) {
          setState(() {
            _isVideoInitialized = true;
          });
          print('🎬 動画表示状態更新完了');
        }
      } catch (e) {
        print('❌ 動画の初期化に失敗: $e');
      }
    } else {
      print('⚠️ 動画パスが指定されていません');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          // 背景（ステージ + スクリーン枠）
          CustomPaint(
            size: Size(widget.width, widget.height),
            painter: _StagePainter(),
          ),
          // 動画を直接配置（絶対座標）
          if (_isVideoInitialized && _videoController != null)
            _buildDirectVideoWidget(),
        ],
      ),
    );
  }

  Widget _buildDirectVideoWidget() {
    // スクリーンの絶対座標を先に計算
    final totalHeight = widget.height;
    final totalWidth = widget.width;
    
    final screenTop = totalHeight * 0.05;
    final screenHeight = totalHeight * 0.25;
    final screenWidth = totalWidth * 0.8;
    final screenTopWidth = screenWidth * 1.1;
    final screenBottomWidth = screenWidth * 1.0;
    
    // スクリーンの中央位置
    final screenCenterX = totalWidth / 2;
    final screenLeft = screenCenterX - (screenTopWidth / 2);
    
    print('🎬 修正後配置: top=$screenTop, left=$screenLeft');
    print('🎬 スクリーンサイズ: ${screenTopWidth}x$screenHeight');
    
    return Positioned(
      top: screenTop,
      left: screenLeft,
      child: _buildTrapezoidVideo(screenTopWidth, screenHeight, screenBottomWidth),
    );
  }

  Widget _buildTrapezoidVideo(double topWidth, double height, double bottomWidth) {
    return SizedBox(
      width: topWidth,
      height: height,
      child: ClipPath(
        clipper: TrapezoidClipper(
          topWidth: topWidth,
          bottomWidth: bottomWidth,
        ),
        child: Container(
          width: topWidth,
          height: height,
          child: _videoController!.value.isInitialized
            ? AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio,
                child: VideoPlayer(_videoController!),
              )
            : Container(
                color: Colors.purple,
                child: const Center(
                  child: Text(
                    '動画準備中...',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
        ),
      ),
    );
  }
}

// シンプルな台形クリッパー
class TrapezoidClipper extends CustomClipper<Path> {
  final double topWidth;
  final double bottomWidth;

  TrapezoidClipper({
    required this.topWidth,
    required this.bottomWidth,
  });

  @override
  Path getClip(Size size) {
    final path = Path();
    final widthDiff = topWidth - bottomWidth;
    final sideOffset = widthDiff / 2;
    
    path.moveTo(0, 0); // 左上
    path.lineTo(size.width, 0); // 右上
    path.lineTo(size.width - sideOffset, size.height); // 右下
    path.lineTo(sideOffset, size.height); // 左下
    path.close();
    
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class _StagePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final screenTop = size.height * 0.05;
    final screenHeight = size.height * 0.25;
    final stageTop = screenTop + screenHeight;
    final stageHeight = size.height * 0.04;
    final baseTop = stageTop + stageHeight;
    final baseHeight = size.height * 0.03;
    final baseBottom = baseTop + baseHeight;
    
    // 青空の背景
    final skyThreshold = screenTop + (screenHeight * 2 / 3);
    final skyPaint = Paint()
      ..color = const Color(0xFF87CEEB)
      ..style = PaintingStyle.fill;
    
    final skyRect = Rect.fromLTWH(0, 0, size.width, skyThreshold);
    canvas.drawRect(skyRect, skyPaint);
    
    // 芝生背景のグラデーション
    final grassGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFF0F4A14),
        const Color(0xFF1B5E20),
        const Color(0xFF2E7D32),
      ],
      stops: const [0.0, 0.6, 1.0],
    );
    
    final grassRect = Rect.fromLTWH(0, skyThreshold, size.width, baseBottom - skyThreshold);
    final grassPaint = Paint()
      ..shader = grassGradient.createShader(grassRect);
    
    canvas.drawRect(grassRect, grassPaint);
    
    // 一番下の台形より下の部分のグラデーション
    final bottomGrassGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFF2E7D32),
        const Color(0xFF4CAF50),
      ],
      stops: const [0.0, 1.0],
    );
    
    final bottomGrassRect = Rect.fromLTWH(0, baseBottom, size.width, size.height - baseBottom);
    final bottomGrassPaint = Paint()
      ..shader = bottomGrassGradient.createShader(bottomGrassRect);
    
    canvas.drawRect(bottomGrassRect, bottomGrassPaint);
    
    // スクリーンの枠のみ描画（中身は動画で埋める）
    final screenWidth = size.width * 0.8;
    final screenTopWidth = screenWidth * 1.1;
    final screenBottomWidth = screenWidth * 1.0;
    
    final screenPath = Path();
    screenPath.moveTo((size.width - screenTopWidth) / 2, screenTop);
    screenPath.lineTo((size.width + screenTopWidth) / 2, screenTop);
    screenPath.lineTo((size.width + screenBottomWidth) / 2, screenTop + screenHeight);
    screenPath.lineTo((size.width - screenBottomWidth) / 2, screenTop + screenHeight);
    screenPath.close();
    
    // スクリーンの枠のみ
    final screenFramePaint = Paint()
      ..color = Colors.grey[600]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
      
    canvas.drawPath(screenPath, screenFramePaint);

    // ステージ本体
    final stagePaint = Paint()
      ..color = Colors.grey[700]!
      ..style = PaintingStyle.fill;
      
    final stageEdgePaint = Paint()
      ..color = Colors.grey[600]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final stageTopWidth = screenBottomWidth;
    final stageBottomWidth = size.width * 0.95;
    
    final stagePath = Path();
    stagePath.moveTo((size.width - stageTopWidth) / 2, stageTop);
    stagePath.lineTo((size.width + stageTopWidth) / 2, stageTop);
    stagePath.lineTo((size.width + stageBottomWidth) / 2, stageTop + stageHeight);
    stagePath.lineTo((size.width - stageBottomWidth) / 2, stageTop + stageHeight);
    stagePath.close();
    
    canvas.drawPath(stagePath, stagePaint);
    canvas.drawPath(stagePath, stageEdgePaint);
    
    // ステージの台座
    final basePaint = Paint()
      ..color = Colors.grey[800]!
      ..style = PaintingStyle.fill;
      
    final baseEdgePaint = Paint()
      ..color = Colors.grey[500]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final baseTopWidth = stageBottomWidth;
    final baseBottomWidth = size.width * 0.9;
    
    final basePath = Path();
    basePath.moveTo((size.width - baseTopWidth) / 2, baseTop);
    basePath.lineTo((size.width + baseTopWidth) / 2, baseTop);
    basePath.lineTo((size.width + baseBottomWidth) / 2, baseTop + baseHeight);
    basePath.lineTo((size.width - baseBottomWidth) / 2, baseTop + baseHeight);
    basePath.close();
    
    canvas.drawPath(basePath, basePaint);
    canvas.drawPath(basePath, baseEdgePaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}