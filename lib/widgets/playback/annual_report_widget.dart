// widgets/playback/annual_report_widget.dart
import 'package:flutter/material.dart';
import '../../models/playback_report.dart';

/// アニュアルレポートウィジェット
class AnnualReportWidget extends StatelessWidget {
  /// レポートデータ
  final PlaybackReport report;
  
  const AnnualReportWidget({
    super.key,
    required this.report,
  });

  @override
  Widget build(BuildContext context) {
    final totalTasks = report.data['totalTasks'] as int? ?? 0;
    final totalMinutes = report.data['totalMinutes'] as int? ?? 0;
    final topAlbums = report.data['topAlbums'] as List<Map<String, dynamic>>? ?? [];
    final topTasks = report.data['topTasks'] as List<Map<String, dynamic>>? ?? [];
    final maxStreakDays = report.data['maxStreakDays'] as int? ?? 0;
    final peakMonth = report.data['peakMonth'] as String? ?? '不明';
    
    return SingleChildScrollView(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),  // より暗いグレーに変更
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummary(totalTasks),
            const SizedBox(height: 20),
            _buildTotalTime(totalMinutes),
            const SizedBox(height: 20),
            _buildTopAlbums(topAlbums),
            const SizedBox(height: 20),
            _buildTopTasks(topTasks),
            const SizedBox(height: 20),
            _buildStreakInfo(maxStreakDays, peakMonth),
          ],
        ),
      ),
    );
  }

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
          'Annual Legacy：$totalTasks タスクを再生',
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

  Widget _buildTotalTime(int totalMinutes) {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1DB954).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.timer_outlined,
            color: Color(0xFF1DB954),
            size: 24,
          ),
          const SizedBox(width: 12),
          Text(
            '総再生時間：${hours}時間${minutes}分',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              fontFamily: 'Hiragino Sans',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopAlbums(List<Map<String, dynamic>> topAlbums) {
  if (topAlbums.isEmpty) {
    return const SizedBox.shrink();
  }
  
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        '年間トップアルバム',
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
        final name = album['albumName'] as String? ?? '不明';
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
                '$count回',
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

  Widget _buildTopTasks(List<Map<String, dynamic>> topTasks) {
  if (topTasks.isEmpty) {
    return const SizedBox.shrink();
  }
  
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        '年間トップヒット曲',
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
        final title = task['taskTitle'] as String? ?? '不明';
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
                '$count回',
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

  Widget _buildStreakInfo(int maxStreakDays, String peakMonth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '継続性の記録',
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: 'Hiragino Sans',
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.local_fire_department,
                      color: Color(0xFFFF6B35),
                      size: 24,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${maxStreakDays}日',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'SF Pro Text',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '連続達成',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 11,
                        fontFamily: 'Hiragino Sans',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.trending_up,
                      color: Color(0xFF1DB954),
                      size: 24,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      peakMonth,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'SF Pro Text',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ピーク月',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 11,
                        fontFamily: 'Hiragino Sans',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}