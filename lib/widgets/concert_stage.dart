// widgets/concert_stage.dart - CustomPainter内動画描画版
import 'package:flutter/material.dart';
import 'dart:typed_data'; 

class ConcertStage extends StatefulWidget {
  final double width;
  final double height;
  final String? imageAssetPath;
  final Uint8List? userImageBytes;  // 新規追加: ユーザーの顔写真
  
  const ConcertStage({
    super.key,
    required this.width,
    required this.height,
    this.imageAssetPath,
    this.userImageBytes,  // 新規追加
  });

  @override
  State<ConcertStage> createState() => _ConcertStageState();
}


class _ConcertStageState extends State<ConcertStage> with TickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
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
        // 画像を直接配置（絶対座標）
        if (widget.imageAssetPath != null)
          _buildDirectImageWidget(),
        // ユーザーの顔写真を円形で表示
        if (widget.userImageBytes != null)
          _buildCircularUserImage(),
      ],
    ),
  );
}

  Widget _buildDirectImageWidget() {
  final totalHeight = widget.height;
  final totalWidth = widget.width;
  
  final screenTop = totalHeight * 0.05;
  final screenHeight = totalHeight * 0.25;
  final screenWidth = totalWidth * 0.8;
  final screenTopWidth = screenWidth * 1.1;
  final screenBottomWidth = screenWidth * 1.0;
  
  final screenCenterX = totalWidth / 2;
  final screenLeft = screenCenterX - (screenTopWidth / 2);
  
  return Positioned(
    top: screenTop,
    left: screenLeft,
    child: _buildTrapezoidImage(screenTopWidth, screenHeight, screenBottomWidth),
  );
}

  Widget _buildTrapezoidImage(double topWidth, double height, double bottomWidth) {
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
        color: Colors.black,  // 追加: 背景を黒に
        child: Image.asset(
          widget.imageAssetPath!,
          width: topWidth,
          height: height,
          fit: BoxFit.contain,  // 変更: cover → contain（画像全体を表示、アスペクト比維持）
          alignment: Alignment.center,  // 追加: 中央配置
        ),
      ),
    ),
  );
}

Widget _buildCircularUserImage() {
  final totalHeight = widget.height;
  final totalWidth = widget.width;
  
  final screenTop = totalHeight * 0.05;
  final screenHeight = totalHeight * 0.25;
  
  // 円のサイズと位置
  final circleSize = screenHeight * 0.3;
  final circleTop = screenTop + (screenHeight / 2) - (circleSize / 2) - (screenHeight * 0.3);  // 修正: 上に移動
  final circleLeft = (totalWidth / 2) - (circleSize / 2) - (totalWidth * 0.035);  // 修正: 左に移動
  
  return Positioned(
    top: circleTop,
    left: circleLeft,
    child: Container(
      width: circleSize,
      height: circleSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        image: DecorationImage(
          image: MemoryImage(widget.userImageBytes!),
          fit: BoxFit.cover,
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
    
    

    // ステージ本体
    final stagePaint = Paint()
      ..color = Colors.grey[700]!
      ..style = PaintingStyle.fill;
      


    final stageTopWidth = screenBottomWidth;
    final stageBottomWidth = size.width * 0.95;
    
    final stagePath = Path();
    stagePath.moveTo((size.width - stageTopWidth) / 2, stageTop);
    stagePath.lineTo((size.width + stageTopWidth) / 2, stageTop);
    stagePath.lineTo((size.width + stageBottomWidth) / 2, stageTop + stageHeight);
    stagePath.lineTo((size.width - stageBottomWidth) / 2, stageTop + stageHeight);
    stagePath.close();
    
    canvas.drawPath(stagePath, stagePaint);

    
    // ステージの台座
    final basePaint = Paint()
      ..color = Colors.grey[800]!
      ..style = PaintingStyle.fill;
      

    final baseTopWidth = stageBottomWidth;
    final baseBottomWidth = size.width * 0.9;
    
    final basePath = Path();
    basePath.moveTo((size.width - baseTopWidth) / 2, baseTop);
    basePath.lineTo((size.width + baseTopWidth) / 2, baseTop);
    basePath.lineTo((size.width + baseBottomWidth) / 2, baseTop + baseHeight);
    basePath.lineTo((size.width - baseBottomWidth) / 2, baseTop + baseHeight);
    basePath.close();
    
    canvas.drawPath(basePath, basePaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}