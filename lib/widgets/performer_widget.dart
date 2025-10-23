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
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final scale = size.width / 40; // 基準サイズ40に対するスケール
    
    // 頭
    final headRadius = 4 * scale;
    canvas.drawCircle(
      Offset(center.dx, center.dy - 12 * scale),
      headRadius,
      paint,
    );
    
    // 体
    canvas.drawLine(
      Offset(center.dx, center.dy - 8 * scale), // 首
      Offset(center.dx, center.dy + 8 * scale), // 腰
      paint,
    );
    
    // 左腕（ギター側）
    canvas.drawLine(
      Offset(center.dx, center.dy - 4 * scale), // 肩
      Offset(center.dx - 8 * scale, center.dy), // 肘
      paint,
    );
    canvas.drawLine(
      Offset(center.dx - 8 * scale, center.dy), // 肘
      Offset(center.dx - 6 * scale, center.dy + 4 * scale), // 手（ギターネック）
      paint,
    );
    
    // 右腕（ストローク側）
    canvas.drawLine(
      Offset(center.dx, center.dy - 4 * scale), // 肩
      Offset(center.dx + 6 * scale, center.dy - 2 * scale), // 肘
      paint,
    );
    canvas.drawLine(
      Offset(center.dx + 6 * scale, center.dy - 2 * scale), // 肘
      Offset(center.dx + 10 * scale, center.dy + 2 * scale), // 手（ストローク）
      paint,
    );
    
    // 左脚
    canvas.drawLine(
      Offset(center.dx, center.dy + 8 * scale), // 腰
      Offset(center.dx - 4 * scale, center.dy + 16 * scale), // 膝
      paint,
    );
    canvas.drawLine(
      Offset(center.dx - 4 * scale, center.dy + 16 * scale), // 膝
      Offset(center.dx - 2 * scale, center.dy + 20 * scale), // 足
      paint,
    );
    
    // 右脚
    canvas.drawLine(
      Offset(center.dx, center.dy + 8 * scale), // 腰
      Offset(center.dx + 4 * scale, center.dy + 16 * scale), // 膝
      paint,
    );
    canvas.drawLine(
      Offset(center.dx + 4 * scale, center.dy + 16 * scale), // 膝
      Offset(center.dx + 2 * scale, center.dy + 20 * scale), // 足
      paint,
    );
    
    // ギター本体
    final guitarPaint = Paint()
      ..color = Colors.brown[600]!
      ..style = PaintingStyle.fill;
      
    final guitarBody = Rect.fromLTWH(
      center.dx + 8 * scale,
      center.dy - 2 * scale,
      6 * scale,
      8 * scale,
    );
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(guitarBody, Radius.circular(2 * scale)),
      guitarPaint,
    );
    
    // ギターネック
    final neckPaint = Paint()
      ..color = Colors.brown[800]!
      ..style = PaintingStyle.fill;
      
    canvas.drawRect(
      Rect.fromLTWH(
        center.dx - 6 * scale,
        center.dy + 2 * scale,
        14 * scale,
        2 * scale,
      ),
      neckPaint,
    );
    
    // ギター弦（簡略化）
    final stringPaint = Paint()
      ..color = Colors.grey[300]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
      
    for (int i = 0; i < 3; i++) {
      final y = center.dy + 2.5 * scale + (i * 0.5 * scale);
      canvas.drawLine(
        Offset(center.dx - 6 * scale, y),
        Offset(center.dx + 14 * scale, y),
        stringPaint,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}