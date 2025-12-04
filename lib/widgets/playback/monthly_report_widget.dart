// widgets/playback/monthly_report_widget.dart
import 'package:flutter/material.dart';
import '../../models/playback_report.dart';
import 'package:fl_chart/fl_chart.dart';

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
    final totalTasks = report.totalTasks;
    final topAlbums = report.topAlbums;
    final topTasks = report.topTasks;
    
    return SingleChildScrollView(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // トップサマリー
            _buildSummary(totalTasks),
            
            const SizedBox(height: 20),
            
            // 週別平均グラフタイトル
            _buildChartTitle(),
            
            const SizedBox(height: 12),
            
            // 週別平均棒グラフ
            _buildChart(),
            
            const SizedBox(height: 24),
            
            // トップヒット曲
            _buildTopTasks(topTasks),
            
            const SizedBox(height: 24),
            
            // トップアルバム
            _buildTopAlbums(topAlbums),
          ],
        ),
      ),
    );
  }

  /// サマリーを構築
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
          'Monthly Hits：$totalTasks Plays',
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

  /// グラフタイトルを構築
  Widget _buildChartTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Monthly Rhythm',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: 'Hiragino Sans',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Daily average tasks per week',
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 12,
            fontFamily: 'Hiragino Sans',
          ),
        ),
      ],
    );
  }

  /// 週別平均棒グラフを構築
  Widget _buildChart() {
    if (report.weeklyAverage.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'No data available',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
        ),
      );
    }
    
    return SizedBox(
      height: 200,
      child: Padding(
        padding: const EdgeInsets.only(right: 16, top: 16),
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: _getMaxValue() * 1.2,
            barTouchData: BarTouchData(
  enabled: true,
  touchTooltipData: BarTouchTooltipData(
    getTooltipColor: (group) => const Color(0xFF1DB954),
    getTooltipItem: (group, groupIndex, rod, rodIndex) {
      // 🔧 修正：週表示を英語化
      final weekLabel = _getWeekLabel(group.x.toInt());
      return BarTooltipItem(
        '$weekLabel\nAvg ${rod.toY.toStringAsFixed(1)} times',
        const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      );
    },
  ),
),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
  sideTitles: SideTitles(
    showTitles: true,
    getTitlesWidget: (value, meta) {
      final index = value.toInt();
      if (index >= 0 && index < report.weekLabels.length) {
        // 🔧 修正：「第1週」→「W1」に短縮表示
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'W${index + 1}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),
        );
      }
      return const SizedBox.shrink();
    },
  ),
),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      value.toInt().toString(),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    );
                  },
                ),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 1,
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: Colors.white.withOpacity(0.1),
                  strokeWidth: 1,
                );
              },
            ),
            borderData: FlBorderData(show: false),
            barGroups: _buildBarGroups(),
          ),
        ),
      ),
    );
  }

  /// 【新規追加】週ラベルを英語で取得
String _getWeekLabel(int index) {
  if (index >= 0 && index < report.weekLabels.length) {
    final originalLabel = report.weekLabels[index];
    // 「第1週」→「Week 1」に変換
    final weekNumber = originalLabel.replaceAll(RegExp(r'[^0-9]'), '');
    return 'Week $weekNumber';
  }
  return 'Week ${index + 1}';
}

  /// グラフの最大値を取得
  double _getMaxValue() {
    if (report.weeklyAverage.isEmpty) return 5.0;
    
    final maxValue = report.weeklyAverage.reduce((a, b) => a > b ? a : b);
    return maxValue > 0 ? maxValue : 5.0;
  }

  /// 棒グラフのデータを生成
  List<BarChartGroupData> _buildBarGroups() {
    return List.generate(
      report.weeklyAverage.length,
      (index) {
        return BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: report.weeklyAverage[index],
              color: const Color(0xFF1DB954),
              width: 24,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
            ),
          ],
        );
      },
    );
  }

  /// トップヒット曲を構築
  Widget _buildTopTasks(List<Map<String, dynamic>> topTasks) {
    if (topTasks.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Top Tracks This Month',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: 'Hiragino Sans',
          ),
        ),
        const SizedBox(height: 12),
        ...topTasks.take(3).toList().asMap().entries.map((entry) {
          final rank = entry.key + 1;
          final task = entry.value;
          final title = task['taskTitle'] as String? ?? 'Unknown';
          final count = task['count'] as int? ?? 0;
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                // ランキングバッジ
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: rank == 1 
                        ? const Color(0xFF1DB954)
                        : Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$rank',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'SF Pro Text',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // タスク名
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Hiragino Sans',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                // 再生回数
                Text(
                  '$count',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
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

  /// トップアルバムを構築
  Widget _buildTopAlbums(List<Map<String, dynamic>> topAlbums) {
    if (topAlbums.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Top Albums This Month',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: 'Hiragino Sans',
          ),
        ),
        const SizedBox(height: 12),
        ...topAlbums.take(3).toList().asMap().entries.map((entry) {
          final rank = entry.key + 1;
          final album = entry.value;
          final name = album['albumName'] as String? ?? 'Unknown';
          final count = album['count'] as int? ?? 0;
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                // ランキングバッジ
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: rank == 1 
                        ? const Color(0xFF1DB954)
                        : Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$rank',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'SF Pro Text',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // アルバム名
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Hiragino Sans',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                // 再生回数
                Text(
                  '$count',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
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