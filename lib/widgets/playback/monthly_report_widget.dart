// widgets/playback/monthly_report_widget.dart
import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../models/playback_report.dart';

/// マンスリーレポートウィジェット
class MonthlyReportWidget extends StatelessWidget {
  /// レポートデータ
  final PlaybackReport report;
  
  const MonthlyReportWidget({
    super.key,
    required this.report,
  });

  @override
  Widget build(BuildContext context) {
    final dailyTrend = report.data['dailyTrend'] as List<int>? ?? [];
    final totalTasks = report.data['totalTasks'] as int? ?? 0;
    final topAlbums = report.data['topAlbums'] as List<Map<String, dynamic>>? ?? [];
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),  // より暗いグレーに変更
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // トップサマリー
          _buildSummary(totalTasks),
          
          const SizedBox(height: 20),
          
          // 月間トレンドグラフ
          _buildTrendChart(dailyTrend),
          
          const SizedBox(height: 20),
          
          // トップアルバム
          _buildTopAlbums(topAlbums),
        ],
      ),
    );
  }

  /// 【新規追加】サマリーを構築
  Widget _buildSummary(int totalTasks) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFF1DB954),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'Monthly Hits：$totalTasks タスクを再生',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: 'Hiragino Sans',
          ),
        ),
      ],
    );
  }

  /// 【新規追加】月間トレンドグラフを構築
  Widget _buildTrendChart(List<int> dailyTrend) {
    if (dailyTrend.isEmpty) {
      return Container(
        height: 120,
        child: Center(
          child: Text(
            'データがありません',
            style: TextStyle(
              color: const Color(0xFF1E1E1E),  // より暗いグレーに変更
              fontSize: 14,
              fontFamily: 'Hiragino Sans',
            ),
          ),
        ),
      );
    }
    
    final maxCount = dailyTrend.reduce(math.max);
    
    return Container(
      height: 120,
      child: CustomPaint(
        painter: _TrendLinePainter(
          data: dailyTrend,
          maxValue: maxCount > 0 ? maxCount : 1,
        ),
        size: Size.infinite,
      ),
    );
  }

  /// 【新規追加】トップアルバムを構築
  Widget _buildTopAlbums(List<Map<String, dynamic>> topAlbums) {
    if (topAlbums.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '今月のトップアルバム',
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: 'Hiragino Sans',
          ),
        ),
        const SizedBox(height: 12),
        ...topAlbums.take(3).toList().asMap().entries.map((entry) {
          final rank = entry.key + 1;
          final album = entry.value;
          final name = album['albumName'] as String? ?? '不明';
          final count = album['count'] as int? ?? 0;
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Text(
                  '$rank位：',
                  style: const TextStyle(
                    color: Color(0xFF1DB954),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'SF Pro Text',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Hiragino Sans',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '（再生タスク数 $count）',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'SF Pro Text',
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }
}

/// 【新規追加】折れ線グラフ描画用のカスタムペインター
class _TrendLinePainter extends CustomPainter {
  final List<int> data;
  final int maxValue;
  
  _TrendLinePainter({
    required this.data,
    required this.maxValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    
    final paint = Paint()
      ..color = const Color(0xFF1DB954)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    
    final path = Path();
    final stepX = size.width / (data.length - 1);
    
    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = size.height - (data[i] / maxValue) * size.height;
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}