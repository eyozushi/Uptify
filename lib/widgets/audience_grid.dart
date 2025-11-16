// widgets/audience_grid.dart - 改善された入場アニメーション版
import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../services/charts_service.dart';  // 新規追加

class AudienceGrid extends StatefulWidget {
  final int audienceCount;
  final double width;
  final double height;
  final double stageHeight;
  final int enteringFansCount;  // 新規追加: 入場中のファン数
  
  const AudienceGrid({
    super.key,
    required this.audienceCount,
    required this.width,
    required this.height,
    required this.stageHeight,
    this.enteringFansCount = 0,  // 新規追加
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
  List<_StaticFan> _confirmedPositions = [];  // 新規追加: 確定した全観客の位置
  final ChartsService _chartsService = ChartsService();  // 新規追加
  bool _isPositionsLoaded = false;  // 新規追加
  
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
  
  // アニメーション完了時に位置を確定
  _entranceController.addStatusListener((status) {
    if (status == AnimationStatus.completed) {
      _confirmFanPositions();
      setState(() {
        _enteringFans.clear();
      });
    }
  });
  
  // 🔧 修正: 保存された位置を読み込む
  _loadSavedPositions();
}

// 🔧 新規追加: 保存された観客位置を読み込む
Future<void> _loadSavedPositions() async {
  try {
    final savedPositions = await _chartsService.loadAudiencePositions();
    
    if (savedPositions.isNotEmpty && savedPositions.length == widget.audienceCount) {
      // 保存されたデータから復元
      final List<_StaticFan> restoredFans = savedPositions.map((pos) {
        return _StaticFan(
          position: Offset(pos['x'] as double, pos['y'] as double),
          color: Color(pos['color'] as int),
          size: pos['size'] as double,
        );
      }).toList();
      
      setState(() {
        _confirmedPositions = restoredFans;
        _isPositionsLoaded = true;
      });
      
      print('✅ 保存された位置を復元: ${restoredFans.length}人');
    } else {
      // 保存データがない、または人数が一致しない場合は初期化
      _initializeStaticPositions();
    }
  } catch (e) {
    print('❌ 位置読み込みエラー: $e');
    _initializeStaticPositions();
  }
}
  
  @override
void didUpdateWidget(AudienceGrid oldWidget) {
  super.didUpdateWidget(oldWidget);
  
  // 🔧 修正: enteringFansCountの変化を検知してアニメーション開始
  if (widget.enteringFansCount > 0 && oldWidget.enteringFansCount == 0) {
    _startEntranceAnimation(widget.enteringFansCount);
  }
  
  // 🔧 修正: アニメーション完了後に_previousAudienceCountを更新
  if (widget.audienceCount > _previousAudienceCount && widget.enteringFansCount == 0) {
    setState(() {
      _previousAudienceCount = widget.audienceCount;
    });
  }
}
  
  void _startEntranceAnimation(int newFanCount) {
  final random = math.Random();
  _enteringFans.clear();
  
  // 🔧 修正: 既存の観客の位置を計算（_previousAudienceCountで固定）
  _occupiedPositions = _calculateExistingPositions();
  
  // 🔧 修正: 新規ファンの目標位置を計算（既存配置を崩さない）
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

// アニメーション完了時にファンの位置を確定
void _confirmFanPositions() {
  // 入場してきたファンをそのまま追加（再配置しない）
  for (final fan in _enteringFans) {
    _confirmedPositions.add(_StaticFan(
      position: fan.targetPosition,
      color: fan.color,
      size: fan.size,
    ));
  }
  
  print('✅ 位置確定: ${_confirmedPositions.length}人');
  
  // 🔧 新規追加: 位置をデータベースに保存
  _savePositions();
}

// 🔧 新規追加: 観客位置を保存
Future<void> _savePositions() async {
  try {
    final positions = _confirmedPositions.map((fan) {
      return {
        'x': fan.position.dx,
        'y': fan.position.dy,
        'color': fan.color.value,
        'size': fan.size,
      };
    }).toList();
    
    await _chartsService.saveAudiencePositions(positions);
  } catch (e) {
    print('❌ 位置保存エラー: $e');
  }
}
// 🔧 新規追加: 初回表示時に静的な観客位置を初期化
void _initializeStaticPositions() {
  if (_confirmedPositions.isNotEmpty || widget.audienceCount == 0 || _isPositionsLoaded) return; 

  
  final grassTop = widget.stageHeight;
  final audienceAreaHeight = widget.height - grassTop;
  
  if (audienceAreaHeight <= 0) return;
  
  final stageCenter = widget.width * 0.5;
  
  // 🔧 修正: 行の高さを小さくして詰める
  final baseRowHeight = 12.0;  // 変更: 20.0 → 12.0
  final maxPossibleRows = (audienceAreaHeight / baseRowHeight).floor().clamp(8, 60);
  final actualRows = _calculateOptimalRows(widget.audienceCount, widget.width, audienceAreaHeight);
  final maxRows = math.min(maxPossibleRows, actualRows);
  final rowHeight = audienceAreaHeight / maxRows;
  
  int remainingAudience = widget.audienceCount;
  final random = math.Random(42);
  
  List<_StaticFan> initialFans = [];
  
  for (int row = 0; row < maxRows && remainingAudience > 0; row++) {
    // 🔧 修正: 1列目をステージに近づける（grassTopから開始）
    final rowY = grassTop + (row * rowHeight) + 5;  // 変更: +5で少し下げるだけ
    final depthFactor = (row + 1) / maxRows;
    final audienceSize = 14.0 + (depthFactor * 4.0);
    
    final audienceInThisRow = _calculateAudienceForRow(
      row, maxRows, remainingAudience, stageCenter, widget.width
    );
    
    final spreadFactor = (row + 1) * 0.15;
    final rowWidth = widget.width * (0.3 + spreadFactor).clamp(0.3, 0.9);
    
    final startX = stageCenter - (rowWidth / 2);
    final spacing = rowWidth / math.max(1, audienceInThisRow - 1);
    
    for (int i = 0; i < audienceInThisRow; i++) {
  final x = startX + (i * spacing);
  
  // 🔧 修正: Y方向のランダムオフセットを大きく（前後のばらつき）
  final yOffset = (random.nextDouble() - 0.5) * (rowHeight * 0.8);  // 変更: 0.2 → 0.8
  final y = rowY + yOffset;
  
  final xOffset = (random.nextDouble() - 0.5) * 12;
  final finalX = x + xOffset;
  
  final colorIndex = random.nextInt(_AudiencePainter._audienceColors.length);
  final color = _AudiencePainter._audienceColors[colorIndex];
  
  initialFans.add(_StaticFan(
    position: Offset(finalX, y),
    color: color,
    size: audienceSize,
  ));
}
    
    remainingAudience -= audienceInThisRow;
  }
  
  setState(() {
    _confirmedPositions = initialFans;
  });
  
  print('✅ 初期位置確定: ${_confirmedPositions.length}人');
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
  
  // 🔧 修正: 固定行数を使用
  final maxRows = 40;
  final baseRowHeight = 12.0;
  final rowHeight = baseRowHeight;
  
  final random = math.Random(DateTime.now().millisecondsSinceEpoch);
  
  // 🔧 修正: 既存の観客数を数えて、次の空きスロットから配置
  int positionsAdded = 0;
  int currentTotalAudience = _previousAudienceCount;
  
  for (int row = 0; row < maxRows && positionsAdded < newFanCount; row++) {
    final rowY = grassTop + (row * rowHeight) + 5;
    final depthFactor = (row + 1) / maxRows;
    final audienceSize = 14.0 + (depthFactor * 4.0);
    
    // 🔧 修正: この行の最大人数を計算
    final frontRowBonus = maxRows - row;
    final maxInRow = 30 + (frontRowBonus * 3);
    
    // 🔧 修正: この行に既に何人いるかを計算
    int existingInThisRow = 0;
    if (currentTotalAudience > 0) {
      // 前の行までに何人いるか計算
      int peopleBefore = 0;
      for (int r = 0; r < row; r++) {
        final bonus = maxRows - r;
        final maxInPrevRow = 30 + (bonus * 3);
        peopleBefore += math.min(maxInPrevRow, math.max(0, currentTotalAudience - peopleBefore));
      }
      existingInThisRow = math.max(0, math.min(maxInRow, currentTotalAudience - peopleBefore));
    }
    
    // 🔧 修正: この行に追加できる人数
    final availableSlots = maxInRow - existingInThisRow;
    final newInThisRow = math.min(availableSlots, newFanCount - positionsAdded);
    
    if (newInThisRow > 0) {
      final spreadFactor = (row + 1) * 0.15;
      final rowWidth = widget.width * (0.3 + spreadFactor).clamp(0.3, 0.9);
      final startX = stageCenter - (rowWidth / 2);
      
      // 🔧 修正: 既存の人の後ろから配置
      final totalInRow = existingInThisRow + newInThisRow;
      final spacing = rowWidth / math.max(1, totalInRow - 1);
      
      for (int i = existingInThisRow; i < totalInRow; i++) {
  final x = startX + (i * spacing);
  final yOffset = (random.nextDouble() - 0.5) * (rowHeight * 0.8);  // 変更: 0.2 → 0.8
  final y = rowY + yOffset;
  final xOffset = (random.nextDouble() - 0.5) * 12;
  
  newPositions.add(Offset(x + xOffset, y));
  positionsAdded++;
  
  if (positionsAdded >= newFanCount) break;
}
    }
    
    currentTotalAudience += newInThisRow;
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
          confirmedPositions: _confirmedPositions,  // 新規追加
        ),
      );
    },
  );
}
  
  int _calculateOptimalRows(int audienceCount, double width, double height) {
  // 🔧 修正: 人数に関わらず常に同じ行数を使用（配置が変わらない）
  return 40;  // 固定値
}
  
  int _calculateAudienceForRow(int row, int maxRows, int remaining, double stageCenter, double totalWidth) {
  final frontRowBonus = maxRows - row;
  final maxInRow = 30 + (frontRowBonus * 3);  // 変更: 20 + (frontRowBonus * 2) → 30 + (frontRowBonus * 3)
  
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

class _StaticFan {
  final Offset position;
  final Color color;
  final double size;
  
  _StaticFan({
    required this.position,
    required this.color,
    required this.size,
  });
}

class _AudiencePainter extends CustomPainter {
  final int staticAudienceCount;
  final double stageHeight;
  final List<_EnteringFan> enteringFans;
  final double animationProgress;
  final Size canvasSize;
  final List<_StaticFan> confirmedPositions;  // 新規追加
  
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
    required this.confirmedPositions,  // 新規追加
  });

  @override
void paint(Canvas canvas, Size size) {
  // 🔧 修正: アニメーション完了後は全員を静的表示
  if (enteringFans.isEmpty || animationProgress >= 1.0) {
    _drawStaticAudience(canvas, size);
  } else {
    // アニメーション中: 既存観客 + 入場中のファン
    _drawStaticAudience(canvas, size);
    _drawEnteringFans(canvas, size);
  }
}
  
  void _drawStaticAudience(Canvas canvas, Size size) {
  // 🔧 修正: confirmedPositions を this.confirmedPositions に変更
  if (confirmedPositions.isNotEmpty) {
    // 確定した位置をそのまま使用
    for (final fan in confirmedPositions) {
      _drawStickFigureAudience(
        canvas,
        fan.position.dx,
        fan.position.dy,
        fan.size,
        fan.color,
      );
    }
    return;
  }
  
  // 🔧 初回表示時のみ従来の計算を実行
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
  
  // 🔧 修正: 初回表示時に確定位置を生成するが、
  // _AudiencePainterはStatelessなので、ここでは描画のみ行う
  List<_StaticFan> initialFans = [];
  
  for (int row = 0; row < maxRows && remainingAudience > 0; row++) {
    final rowY = grassTop + (row * rowHeight);
    final depthFactor = (row + 1) / maxRows;
    final audienceSize = 14.0 + (depthFactor * 4.0);
    
    final audienceInThisRow = _calculateAudienceForRow(
      row, maxRows, remainingAudience, stageCenter, size.width
    );
    
    final fans = _generateAudienceRowCentered(
      audienceInThisRow,
      rowY,
      stageCenter,
      size.width,
      audienceSize,
      rowHeight,
      random,
      row,
    );
    
    initialFans.addAll(fans);
    remainingAudience -= audienceInThisRow;
  }
  
  // 描画
  for (final fan in initialFans) {
    _drawStickFigureAudience(
      canvas,
      fan.position.dx,
      fan.position.dy,
      fan.size,
      fan.color,
    );
  }
}

// 🔧 新規追加: 行の観客を生成（描画ではなく位置データを返す）
List<_StaticFan> _generateAudienceRowCentered(
  int count,
  double rowY,
  double stageCenter,
  double totalWidth,
  double audienceSize,
  double rowHeight,
  math.Random random,
  int rowIndex,
) {
  List<_StaticFan> fans = [];
  
  if (count == 0) return fans;
  
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
    
    final colorIndex = random.nextInt(_AudiencePainter._audienceColors.length);
    final color = _AudiencePainter._audienceColors[colorIndex];
    
    fans.add(_StaticFan(
      position: Offset(finalX, y),
      color: color,
      size: audienceSize,
    ));
  }
  
  return fans;
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