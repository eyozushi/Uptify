// widgets/record_gauge_widget.dart
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:typed_data';
import '../models/record_gauge_state.dart';
import 'dart:ui' as ui;

/// Record Gauge（レコード・ゲージ）ウィジェット
/// 
/// ドリームアルバムの4タスク完了状態をレコード盤として視覚化
class RecordGaugeWidget extends StatelessWidget {
  final RecordGaugeState state;
  final Uint8List? albumCoverImage;
  final double size;

  const RecordGaugeWidget({
    super.key,
    required this.state,
    this.albumCoverImage,
    this.size = 280.0,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ヘッダー（枠外）
        _buildHeader(),
        const SizedBox(height: 16),
        // レコード盤コンテナ
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
decoration: BoxDecoration(
            color: const Color(0xFF808080),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _buildRecordWithTonearm(),
              const SizedBox(height: 16),
              _buildProgressText(),
            ],
          ),
        ),
      ],
    );
  }

  /// ヘッダー部分（枠外）
  Widget _buildHeader() {
    return const Text(
      'Record Gauge',
      style: TextStyle(
        color: Colors.white,
        fontSize: 22,
        fontWeight: FontWeight.w900,
        fontFamily: 'Hiragino Sans',
      ),
    );
  }

  /// レコード盤とトーンアーム
  Widget _buildRecordWithTonearm() {
    final tonearmLength = size * 0.75;
    final centerLabelRadius = 50.0; // 固定サイズ（直径100px）
    
    return Center(
      child: SizedBox(
        width: size + 60,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // レコード盤（中央）
            SizedBox(
              width: size,
              height: size,
              child: CustomPaint(
                painter: _RecordPainter(
                  state: state,
                  albumCoverImage: null, // 画像はウィジェットで描画
                ),
              ),
            ),
            // 中心のアルバムジャケット画像（常に表示）
            if (albumCoverImage != null)
              Container(
                width: centerLabelRadius * 2,
                height: centerLabelRadius * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: state.isFullyCompleted 
                        ? const Color(0xFF1DB954) 
                        : Colors.grey.withOpacity(0.6),
                    width: 6.0,
                  ),
                ),
                child: ClipOval(
                  child: ColorFiltered(
                    colorFilter: state.isFullyCompleted
                        ? const ColorFilter.mode(
                            Colors.transparent,
                            BlendMode.multiply,
                          )
                        : const ColorFilter.matrix(<double>[
                            0.2126, 0.7152, 0.0722, 0, 0,
                            0.2126, 0.7152, 0.0722, 0, 0,
                            0.2126, 0.7152, 0.0722, 0, 0,
                            0,      0,      0,      1, 0,
                          ]),
                    child: Image.memory(
                      albumCoverImage!,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            // トーンアーム（レコード盤の右側、縦向き、針が下）
            Positioned(
              left: (size + 60) / 2 + size / 2 + 10,
              top: 0,
              child: SizedBox(
                width: 30,
                height: tonearmLength,
                child: CustomPaint(
                  painter: TonearmPainter(
                    length: tonearmLength,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 進捗テキスト
  Widget _buildProgressText() {
    return Text(
      '${state.completedCount}/4 タスク完了',
      style: TextStyle(
        color: Colors.white.withOpacity(0.7),
        fontSize: 14,
        fontWeight: FontWeight.w500,
        fontFamily: 'Hiragino Sans',
      ),
    );
  }
}

/// トーンアーム（針）を描画するCustomPainter（縦向き）
class TonearmPainter extends CustomPainter {
  final double length;

  TonearmPainter({required this.length});

  @override
  void paint(Canvas canvas, Size size) {
    final armThickness = 8.0;
    final headshellWidth = 32.0;
    final headshellHeight = 24.0;
    
    // トーンアームの棒（縦向き、マットな金属）
    final armRect = Rect.fromLTWH(
      (size.width - armThickness) / 2,
      0,
      armThickness,
      length,
    );
    
    final armPaint = Paint()
      ..color = Colors.grey[600]!
      ..style = PaintingStyle.fill;
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(armRect, const Radius.circular(4)),
      armPaint,
    );
    
    // ヘッドシェル（針の台座部分、下部に配置）
    final headshellRect = Rect.fromLTWH(
      (size.width - headshellWidth) / 2,
      length - headshellHeight,
      headshellWidth,
      headshellHeight,
    );
    
    final headshellPaint = Paint()
      ..color = Colors.grey[500]!
      ..style = PaintingStyle.fill;
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(headshellRect, const Radius.circular(4)),
      headshellPaint,
    );
    
    
    
    // 針（カートリッジ部分）- ヘッドシェルの下部中央
    final needleRadius = 5.0;
    final needleCenter = Offset(size.width / 2, length + 2);
    
    final needlePaint = Paint()
      ..color = Colors.grey[800]!
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(needleCenter, needleRadius, needlePaint);
    
    // 針先（尖った部分）- 下向き
    final needleTipPaint = Paint()
      ..color = Colors.grey[900]!
      ..style = PaintingStyle.fill;
    
    final needleTipPath = Path();
    needleTipPath.moveTo(size.width / 2, length + 8);
    needleTipPath.lineTo(size.width / 2 - 3, length + 4);
    needleTipPath.lineTo(size.width / 2 + 3, length + 4);
    needleTipPath.close();
    
    canvas.drawPath(needleTipPath, needleTipPaint);
  }

  @override
  bool shouldRepaint(covariant TonearmPainter oldDelegate) {
    return oldDelegate.length != length;
  }
}

// lib/widgets/record_gauge_widget.dart

/// レコード盤を描画するCustomPainter
class _RecordPainter extends CustomPainter {
  final RecordGaugeState state;
  final Uint8List? albumCoverImage;

  _RecordPainter({
    required this.state,
    this.albumCoverImage,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    final centerLabelRadius = 50.0;
    final availableWidth = maxRadius - centerLabelRadius;
    final trackWidth = availableWidth / 4;

    final trackRadii = <Map<String, double>>[];
    for (int i = 0; i < 4; i++) {
      final outerRadius = maxRadius - (i * trackWidth);
      final innerRadius = outerRadius - trackWidth;
      
      trackRadii.add({
        'outer': outerRadius,
        'inner': innerRadius,
      });
    }

    for (int i = 0; i < 4; i++) {
      final isCompleted = state.isTrackCompleted(i);
      final outerRadius = trackRadii[i]['outer']!;
      final innerRadius = trackRadii[i]['inner']!;
      
      _drawTrackRing(
        canvas, 
        center, 
        outerRadius, 
        innerRadius, 
        isCompleted,
      );
    }

    for (int i = 0; i < 3; i++) {
      final radius = trackRadii[i]['inner']!;
      _drawRingBorder(canvas, center, radius);
    }

    _drawCenterLabel(canvas, center, centerLabelRadius);
  }

  void _drawTrackRing(
    Canvas canvas,
    Offset center,
    double outerRadius,
    double innerRadius,
    bool isCompleted,
  ) {
    final color = isCompleted 
        ? Colors.black 
        : Colors.grey[600]!;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final outerPath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: outerRadius));
    
    final innerPath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: innerRadius));

    final ringPath = Path.combine(
      PathOperation.difference,
      outerPath,
      innerPath,
    );

    canvas.drawPath(ringPath, paint);
  }

  void _drawRingBorder(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(center, radius, paint);
  }

  void _drawCenterLabel(Canvas canvas, Offset center, double labelRadius) {
    // 🆕 修正：完了数に応じて緑枠を描画
    if (state.completedCount > 0) {
      _drawProgressiveBorder(canvas, center, labelRadius);
    }
  }

  // 🆕 新規追加：完了数に応じた段階的な緑枠
  void _drawProgressiveBorder(Canvas canvas, Offset center, double labelRadius) {
    // 完了数に応じた枠の太さ（1〜4タスク完了で3px〜12px）
    final borderWidth = 3.0 + (state.completedCount * 2.25); // 1個: 5.25px, 2個: 7.5px, 3個: 9.75px, 4個: 12px
    
    final borderPaint = Paint()
      ..color = const Color(0xFF1DB954)
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    canvas.drawCircle(center, labelRadius, borderPaint);
    
    // 🆕 オプション：完了数に応じて内側に光彩効果（グロー）を追加
    if (state.completedCount >= 2) {
      final glowPaint = Paint()
        ..color = const Color(0xFF1DB954).withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth + 4.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
      
      canvas.drawCircle(center, labelRadius, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RecordPainter oldDelegate) {
    return oldDelegate.state != state ||
           oldDelegate.albumCoverImage != albumCoverImage;
  }
}




  void _drawGradientFallback(Canvas canvas, Offset center, double labelRadius) {
    final rect = Rect.fromCircle(center: center, radius: labelRadius);
    final gradientPaint = Paint()
      ..shader = const RadialGradient(
        colors: [
          Color(0xFF1DB954),
          Color(0xFF1ED760),
        ],
      ).createShader(rect);
    
    canvas.drawCircle(center, labelRadius, gradientPaint);
  }


/// レコード盤のローディング表示ウィジェット
class RecordGaugeLoadingWidget extends StatelessWidget {
  const RecordGaugeLoadingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Record Gauge',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            fontFamily: 'Hiragino Sans',
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            color: const Color(0xFF808080),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF1DB954),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '読み込み中...',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Hiragino Sans',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// レコード盤のエラー表示ウィジェット
class RecordGaugeErrorWidget extends StatelessWidget {
  final String errorMessage;

  const RecordGaugeErrorWidget({
    super.key,
    this.errorMessage = 'データの読み込みに失敗しました',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Record Gauge',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            fontFamily: 'Hiragino Sans',
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            color: const Color(0xFF808080),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 48,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                errorMessage,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Hiragino Sans',
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}