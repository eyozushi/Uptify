// widgets/performer_widget.dart - ギター棒人間
import 'package:flutter/material.dart';

class PerformerWidget extends StatelessWidget {
  final double size;
  final Color color;
  
  const PerformerWidget({
    super.key,
    this.size = 40.0,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _PerformerPainter(color: color),
    );
  }
}

class _PerformerPainter extends CustomPainter {
  final Color color;
  
  _PerformerPainter({required this.color});

  @override
void paint(Canvas canvas, Size size) {
  final paint = Paint()
    ..color = color
    ..style = PaintingStyle.fill  // 変更: stroke → fill（塗りつぶし）
    ..strokeWidth = 3.0  // 変更: 2.0 → 3.0（太く）
    ..strokeCap = StrokeCap.round;

  final center = Offset(size.width / 2, size.height / 2);
  final scale = size.width / 40;
  
  // 頭（塗りつぶし）
  final headRadius = 6 * scale;
  canvas.drawCircle(
    Offset(center.dx, center.dy - 12 * scale),
    headRadius,
    paint,  // 塗りつぶしで描画
  );
  
  // 体（太い線）
  final bodyPaint = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.0  // 変更: 2.0 → 3.0
    ..strokeCap = StrokeCap.round;
  
  canvas.drawLine(
    Offset(center.dx, center.dy - 8 * scale),
    Offset(center.dx, center.dy + 8 * scale),
    bodyPaint,
  );
  
  // 左腕（ギター側）
  canvas.drawLine(
    Offset(center.dx, center.dy - 4 * scale),
    Offset(center.dx - 8 * scale, center.dy),
    bodyPaint,
  );
  canvas.drawLine(
    Offset(center.dx - 8 * scale, center.dy),
    Offset(center.dx - 6 * scale, center.dy + 4 * scale),
    bodyPaint,
  );
  
  // 右腕（ストローク側）
  canvas.drawLine(
    Offset(center.dx, center.dy - 4 * scale),
    Offset(center.dx + 6 * scale, center.dy - 2 * scale),
    bodyPaint,
  );
  canvas.drawLine(
    Offset(center.dx + 6 * scale, center.dy - 2 * scale),
    Offset(center.dx + 10 * scale, center.dy + 2 * scale),
    bodyPaint,
  );
  
  // 左脚
  canvas.drawLine(
    Offset(center.dx, center.dy + 8 * scale),
    Offset(center.dx - 4 * scale, center.dy + 16 * scale),
    bodyPaint,
  );
  canvas.drawLine(
    Offset(center.dx - 4 * scale, center.dy + 16 * scale),
    Offset(center.dx - 2 * scale, center.dy + 20 * scale),
    bodyPaint,
  );
  
  // 右脚
  canvas.drawLine(
    Offset(center.dx, center.dy + 8 * scale),
    Offset(center.dx + 4 * scale, center.dy + 16 * scale),
    bodyPaint,
  );
  canvas.drawLine(
    Offset(center.dx + 4 * scale, center.dy + 16 * scale),
    Offset(center.dx + 2 * scale, center.dy + 20 * scale),
    bodyPaint,
  );
  
  
}

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}