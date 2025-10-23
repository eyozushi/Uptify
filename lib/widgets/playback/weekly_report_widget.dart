// widgets/playback/weekly_report_widget.dart
import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../models/playback_report.dart';

/// ウィークリーレポートウィジェット
class WeeklyReportWidget extends StatelessWidget {
  /// レポートデータ
  final PlaybackReport report;
  
  const WeeklyReportWidget({
    super.key,
    required this.report,
  });

  @override
  Widget build(BuildContext context) {
    final dailyCounts = report.data['dailyCounts'] as Map<int, int>? ?? {};
    final totalTasks = report.data['totalTasks'] as int? ?? 0;
    final topTasks = report.data['topTasks'] as List<Map<String, dynamic>>? ?? [];
    
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
          
          // 週間棒グラフ
          _buildWeeklyChart(dailyCounts),
          
          const SizedBox(height: 20),
          
          // トップヒット曲
          _buildTopTasks(topTasks),
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
          'Weekly Hits：$totalTasks タスクを再生',
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

  /// 【修正】週間棒グラフを構築
Widget _buildWeeklyChart(Map<int, int> dailyCounts) {
  final weekdays = ['日', '月', '火', '水', '木', '金', '土'];
  final maxCount = dailyCounts.values.isEmpty 
      ? 1 
      : dailyCounts.values.reduce(math.max);
  
  return Container(
    height: 140,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(7, (index) {
        final count = dailyCounts[index] ?? 0;
        final height = maxCount > 0 ? (count / maxCount) * 100 : 0.0;
        final isMax = count == maxCount && count > 0;
        
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                // カウント表示
                SizedBox(
                  height: 16,
                  child: count > 0
                      ? Text(
                          '$count',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'SF Pro Text',
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 2),
                // 棒グラフ
                Container(
                  width: double.infinity,
                  height: height,
                  decoration: BoxDecoration(
                    color: isMax 
                        ? const Color(0xFF1DB954) 
                        : Colors.white.withOpacity(0.3),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                // 曜日ラベル
                Text(
                  weekdays[index],
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'Hiragino Sans',
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    ),
  );
}

  /// 【新規追加】トップタスクを構築
  Widget _buildTopTasks(List<Map<String, dynamic>> topTasks) {
    if (topTasks.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '今週のトップヒット曲',
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: 'Hiragino Sans',
          ),
        ),
        const SizedBox(height: 12),
        ...topTasks.asMap().entries.map((entry) {
          final rank = entry.key + 1;
          final task = entry.value;
          final title = task['taskTitle'] as String? ?? '不明';
          final count = task['count'] as int? ?? 0;
          
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
                    title,
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
                  '（再生回数 $count回）',
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