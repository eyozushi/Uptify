// widgets/audience_grid.dart - 改善された入場アニメーション版
import 'package:flutter/material.dart';
import 'dart:math' as math;

class AudienceGrid extends StatefulWidget {
  final int audienceCount;
  final double width;
  final double height;
  final double stageHeight;
  
  const AudienceGrid({
    super.key,
    required this.audienceCount,
    required this.width,
    required this.height,
    required this.stageHeight,
  });

  @override
  State<AudienceGrid> createState() => _AudienceGridState();
}

class _AudienceGridState extends State<AudienceGrid>
    with TickerProviderStateMixin {
  
  late AnimationController _entranceController;
  late Animation<double> _entranceAnimation;
  
  int _previousAudienceCount = 0;
  List<_EnteringFan> _enteringFans = [];
  List<Offset> _occupiedPositions = [];
  
  @override
  void initState() {
    super.initState();
    
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );
    
    _entranceAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeInOut,
    );
    
    _previousAudienceCount = widget.audienceCount;
    
    _entranceController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _enteringFans.clear();
        });
      }
    });
  }
  
  @override
  void didUpdateWidget(AudienceGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.audienceCount > _previousAudienceCount) {
      _startEntranceAnimation(widget.audienceCount - _previousAudienceCount);
    }
    _previousAudienceCount = widget.audienceCount;
  }
  
  void _startEntranceAnimation(int newFanCount) {
    final random = math.Random();
    _enteringFans.clear();
    
    // 既存の観客の位置を計算
    _occupiedPositions = _calculateExistingPositions();
    
    // 新規ファンの目標位置を計算
    final newPositions = _calculateNewFanPositions(newFanCount);
    
    for (int i = 0; i < newFanCount && i < newPositions.length; i++) {
      _enteringFans.add(_EnteringFan(
        startDelay: i * 150.0,
        targetPosition: newPositions[i],
        color: _getRandomColor(random),
        size: 14.0 + random.nextDouble() * 4.0,
        speed: 0.7 + random.nextDouble() * 0.3,
        id: _previousAudienceCount + i,
      ));
    }
    
    _entranceController.reset();
    _entranceController.forward();
  }
  
  List<Offset> _calculateExistingPositions() {
    List<Offset> positions = [];
    final grassTop = widget.stageHeight;
    final audienceAreaHeight = widget.height - grassTop;
    final stageCenter = widget.width * 0.5;
    
    final maxRows = _calculateOptimalRows(_previousAudienceCount, widget.width, audienceAreaHeight);
    final rowHeight = audienceAreaHeight / maxRows;
    
    int remainingAudience = _previousAudienceCount;
    final random = math.Random(42);
    
    for (int row = 0; row < maxRows && remainingAudience > 0; row++) {
      final rowY = grassTop + (row * rowHeight);
      final audienceInThisRow = _calculateAudienceForRow(row, maxRows, remainingAudience, stageCenter, widget.width);
      
      final spreadFactor = (row + 1) * 0.15;
      final rowWidth = widget.width * (0.3 + spreadFactor).clamp(0.3, 0.9);
      final startX = stageCenter - (rowWidth / 2);
      final spacing = rowWidth / math.max(1, audienceInThisRow - 1);
      
      for (int i = 0; i < audienceInThisRow; i++) {
        final x = startX + (i * spacing);
        final yOffset = (random.nextDouble() - 0.5) * (rowHeight * 0.4);
        final y = rowY + (rowHeight / 2) + yOffset;
        final xOffset = (random.nextDouble() - 0.5) * 12;
        
        positions.add(Offset(x + xOffset, y));
      }
      
      remainingAudience -= audienceInThisRow;
    }
    
    return positions;
  }
  
  List<Offset> _calculateNewFanPositions(int newFanCount) {
    List<Offset> newPositions = [];
    final grassTop = widget.stageHeight;
    final audienceAreaHeight = widget.height - grassTop;
    final stageCenter = widget.width * 0.5;
    
    final totalAudience = _previousAudienceCount + newFanCount;
    final maxRows = _calculateOptimalRows(totalAudience, widget.width, audienceAreaHeight);
    final rowHeight = audienceAreaHeight / maxRows;
    
    int processedExisting = 0;
    final random = math.Random(100);
    
    for (int row = 0; row < maxRows && newPositions.length < newFanCount; row++) {
      final rowY = grassTop + (row * rowHeight);
      final totalInThisRow = _calculateAudienceForRow(row, maxRows, totalAudience - processedExisting, stageCenter, widget.width);
      final existingInThisRow = math.min(totalInThisRow, _occupiedPositions.length - processedExisting);
      final newInThisRow = totalInThisRow - existingInThisRow;
      
      if (newInThisRow > 0) {
        final spreadFactor = (row + 1) * 0.15;
        final rowWidth = widget.width * (0.3 + spreadFactor).clamp(0.3, 0.9);
        final startX = stageCenter - (rowWidth / 2);
        final spacing = rowWidth / math.max(1, totalInThisRow - 1);
        
        // 新規ファンの位置を既存の隙間に配置
        for (int i = existingInThisRow; i < totalInThisRow && newPositions.length < newFanCount; i++) {
          final x = startX + (i * spacing);
          final yOffset = (random.nextDouble() - 0.5) * (rowHeight * 0.4);
          final y = rowY + (rowHeight / 2) + yOffset;
          final xOffset = (random.nextDouble() - 0.5) * 12;
          
          newPositions.add(Offset(x + xOffset, y));
        }
      }
      
      processedExisting += existingInThisRow;
    }
    
    return newPositions;
  }
  
  Color _getRandomColor(math.Random random) {
    return _AudiencePainter._audienceColors[random.nextInt(_AudiencePainter._audienceColors.length)];
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _entranceAnimation,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.width, widget.height),
          painter: _AudiencePainter(
            staticAudienceCount: _previousAudienceCount,
            stageHeight: widget.stageHeight,
            enteringFans: _enteringFans,
            animationProgress: _entranceAnimation.value,
            canvasSize: Size(widget.width, widget.height),
          ),
        );
      },
    );
  }
  
  int _calculateOptimalRows(int audienceCount, double width, double height) {
    if (audienceCount <= 50) return 8;
    if (audienceCount <= 200) return 15;
    if (audienceCount <= 500) return 25;
    if (audienceCount <= 1000) return 35;
    return 50;
  }
  
  int _calculateAudienceForRow(int row, int maxRows, int remaining, double stageCenter, double totalWidth) {
    final frontRowBonus = maxRows - row;
    final maxInRow = 20 + (frontRowBonus * 2);
    
    if (row < maxRows * 0.4) {
      return math.min(remaining, maxInRow);
    } else {
      final remainingRows = maxRows - row;
      final averagePerRow = (remaining / remainingRows).ceil();
      return math.min(remaining, math.min(averagePerRow, maxInRow));
    }
  }
  
  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }
}

class _EnteringFan {
  final double startDelay;
  final Offset targetPosition;
  final Color color;
  final double size;
  final double speed;
  final int id;
  
  _EnteringFan({
    required this.startDelay,
    required this.targetPosition,
    required this.color,
    required this.size,
    required this.speed,
    required this.id,
  });
}

class _AudiencePainter extends CustomPainter {
  final int staticAudienceCount;
  final double stageHeight;
  final List<_EnteringFan> enteringFans;
  final double animationProgress;
  final Size canvasSize;
  
  static const List<Color> _audienceColors = [
    // 淡い色（パステル系）
    Color(0xFFFFB3BA), // 淡いピンク
    Color(0xFFFFDFBA), // 淡いオレンジ
    Color(0xFFFFFFBA), // 淡い黄色
    Color(0xFFBAFFC9), // 淡い緑
    Color(0xFFBAE1FF), // 淡い青
    Color(0xFFE1BAFF), // 淡い紫
    Color(0xFFFFC9DE), // 淡いローズ
    Color(0xFFC9E1FF), // 淡い水色
    
    // 中間色
    Color(0xFF87CEEB), // スカイブルー
    Color(0xFFDDA0DD), // プラム
    Color(0xFF98FB98), // ライトグリーン
    Color(0xFFF0E68C), // カーキ
    Color(0xFFFFB6C1), // ライトピンク
    Color(0xFFD3D3D3), // ライトグレー
    Color(0xFFFFA07A), // ライトサーモン
    Color(0xFF20B2AA), // ライトシーグリーン
    
    // 明るい色
    Color(0xFF00CED1), // ターコイズ
    Color(0xFFFF69B4), // ホットピンク
    Color(0xFF32CD32), // ライムグリーン
    Color(0xFFFFD700), // ゴールド
    Color(0xFF40E0D0), // ターコイズ
    Color(0xFFFF6347), // トマト
    Color(0xFF9370DB), // ミディアムパープル
    Color(0xFF00FA9A), // ミディアムスプリンググリーン
    
    // 濃い色
    Color(0xFF4169E1), // ロイヤルブルー
    Color(0xFF8B008B), // ダークマゼンタ
    Color(0xFF228B22), // フォレストグリーン
    Color(0xFFB22222), // ファイアブリック
    Color(0xFF4B0082), // インディゴ
    Color(0xFF800080), // パープル
    Color(0xFF008B8B), // ダークシアン
    Color(0xFFFF8C00), // ダークオレンジ
    
    // 白とグレー系
    Color(0xFFFFFFFF), // 白
    Color(0xFFF5F5F5), // ホワイトスモーク
    Color(0xFFDCDCDC), // ガインズボロ
    Color(0xFFC0C0C0), // シルバー
    Color(0xFFA9A9A9), // ダークグレー
    Color(0xFF696969), // ディムグレー
  ];
  
  _AudiencePainter({
    required this.staticAudienceCount,
    required this.stageHeight,
    required this.enteringFans,
    required this.animationProgress,
    required this.canvasSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 既存の観客を描画
    _drawStaticAudience(canvas, size);
    
    // 入場中のファンを描画
    _drawEnteringFans(canvas, size);
  }
  
  void _drawStaticAudience(Canvas canvas, Size size) {
    if (staticAudienceCount == 0) return;
    
    final grassTop = stageHeight;
    final audienceAreaHeight = size.height - grassTop;
    
    if (audienceAreaHeight <= 0) return;
    
    final stageCenter = size.width * 0.5;
    
    final baseRowHeight = 20.0;
    final maxPossibleRows = (audienceAreaHeight / baseRowHeight).floor().clamp(8, 60);
    final actualRows = _calculateOptimalRows(staticAudienceCount, size.width, audienceAreaHeight);
    final maxRows = math.min(maxPossibleRows, actualRows);
    final rowHeight = audienceAreaHeight / maxRows;
    
    int remainingAudience = staticAudienceCount;
    final random = math.Random(42);
    
    for (int row = 0; row < maxRows && remainingAudience > 0; row++) {
      final rowY = grassTop + (row * rowHeight);
      final depthFactor = (row + 1) / maxRows;
      final audienceSize = 14.0 + (depthFactor * 4.0); // 統一されたサイズ
      
      final audienceInThisRow = _calculateAudienceForRow(
        row, maxRows, remainingAudience, stageCenter, size.width
      );
      
      _drawAudienceRowCentered(
        canvas,
        audienceInThisRow,
        rowY,
        stageCenter,
        size.width,
        audienceSize,
        rowHeight,
        random,
        row,
      );
      
      remainingAudience -= audienceInThisRow;
    }
  }
  
  void _drawEnteringFans(Canvas canvas, Size size) {
    final totalTime = 3000.0;
    
    for (int i = 0; i < enteringFans.length; i++) {
      final fan = enteringFans[i];
      final fanProgress = ((animationProgress * totalTime - fan.startDelay) / (totalTime - fan.startDelay))
          .clamp(0.0, 1.0);
      
      if (fanProgress <= 0) continue;
      
      // 入場経路：画面下から目標位置へ
      final random = math.Random(fan.id);
      final startX = size.width * 0.2 + random.nextDouble() * size.width * 0.6;
      final startY = size.height + 30;
      
      // 曲線的な移動
      final curve = Curves.easeInOutCubic.transform(fanProgress * fan.speed);
      final currentX = startX + (fan.targetPosition.dx - startX) * curve;
      final currentY = startY + (fan.targetPosition.dy - startY) * curve;
      
      // 移動中は少し小さめ、到着時に目標サイズに
      final currentSize = fan.size * (0.8 + 0.2 * curve);
      
      _drawStickFigureAudience(canvas, currentX, currentY, currentSize, fan.color);
    }
  }
  
  int _calculateOptimalRows(int audienceCount, double width, double height) {
    if (audienceCount <= 50) return 8;
    if (audienceCount <= 200) return 15;
    if (audienceCount <= 500) return 25;
    if (audienceCount <= 1000) return 35;
    return 50;
  }
  
  int _calculateAudienceForRow(int row, int maxRows, int remaining, double stageCenter, double totalWidth) {
    final frontRowBonus = maxRows - row;
    final maxInRow = 20 + (frontRowBonus * 2);
    
    if (row < maxRows * 0.4) {
      return math.min(remaining, maxInRow);
    } else {
      final remainingRows = maxRows - row;
      final averagePerRow = (remaining / remainingRows).ceil();
      return math.min(remaining, math.min(averagePerRow, maxInRow));
    }
  }
  
  void _drawAudienceRowCentered(
    Canvas canvas,
    int count,
    double rowY,
    double stageCenter,
    double totalWidth,
    double audienceSize,
    double rowHeight,
    math.Random random,
    int rowIndex,
  ) {
    if (count == 0) return;
    
    final spreadFactor = (rowIndex + 1) * 0.15;
    final rowWidth = totalWidth * (0.3 + spreadFactor).clamp(0.3, 0.9);
    
    final startX = stageCenter - (rowWidth / 2);
    final spacing = rowWidth / math.max(1, count - 1);
    
    for (int i = 0; i < count; i++) {
      final x = startX + (i * spacing);
      
      final yOffset = (random.nextDouble() - 0.5) * (rowHeight * 0.4);
      final y = rowY + (rowHeight / 2) + yOffset;
      
      final xOffset = (random.nextDouble() - 0.5) * 12;
      final finalX = x + xOffset;
      
      final colorIndex = random.nextInt(_audienceColors.length);
      final color = _audienceColors[colorIndex];
      
      _drawStickFigureAudience(canvas, finalX, y, audienceSize, color);
    }
  }
  
  void _drawStickFigureAudience(Canvas canvas, double x, double y, double size, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2.0, size * 0.15)
      ..strokeCap = StrokeCap.round;

    final scale = size / 14;
    
    // 頭
    final headRadius = 2.2 * scale;
    canvas.drawCircle(
      Offset(x, y - 5 * scale),
      headRadius,
      paint,
    );
    
    // 体
    canvas.drawLine(
      Offset(x, y - 3 * scale),
      Offset(x, y + 4 * scale),
      paint,
    );
    
    // 左腕
    canvas.drawLine(
      Offset(x, y - 1 * scale),
      Offset(x - 2.5 * scale, y + 1.5 * scale),
      paint,
    );
    
    // 右腕
    canvas.drawLine(
      Offset(x, y - 1 * scale),
      Offset(x + 2.5 * scale, y + 1.5 * scale),
      paint,
    );
    
    // 左脚
    canvas.drawLine(
      Offset(x, y + 4 * scale),
      Offset(x - 2 * scale, y + 8 * scale),
      paint,
    );
    
    // 右脚
    canvas.drawLine(
      Offset(x, y + 4 * scale),
      Offset(x + 2 * scale, y + 8 * scale),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}