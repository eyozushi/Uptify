// widgets/playback/daily_report_widget.dart
import 'package:flutter/material.dart';
import '../../models/playback_report.dart';
import '../../models/task_completion.dart';
import '../../services/data_service.dart';
import 'task_history_item.dart';

/// デイリーレポートウィジェット
class DailyReportWidget extends StatefulWidget {
  /// レポートデータ
  final PlaybackReport report;
  
  const DailyReportWidget({
    super.key,
    required this.report,
  });

  @override
  State<DailyReportWidget> createState() => _DailyReportWidgetState();
}

class _DailyReportWidgetState extends State<DailyReportWidget> {
  final DataService _dataService = DataService();
  
  // アルバムジャケット画像のキャッシュ
  final Map<String, dynamic> _albumImages = {};
  bool _isLoadingImages = true;

  @override
  void initState() {
    super.initState();
    _loadAlbumImages();
  }

  /// 【新規追加】アルバム画像を読み込み
  Future<void> _loadAlbumImages() async {
    try {
      final taskHistory = widget.report.data['taskHistory'] as List<TaskCompletion>? ?? [];
      
      // ライフドリームアルバムの画像
      final lifeDreamImage = await _dataService.loadImageBytes();
      if (lifeDreamImage != null) {
        _albumImages['life_dream'] = lifeDreamImage;
      }
      
      // シングルアルバムの画像
      final singleAlbums = await _dataService.loadSingleAlbums();
      for (final album in singleAlbums) {
        if (album.albumCoverImage != null) {
          _albumImages[album.id] = album.albumCoverImage;
        }
      }
      
      if (mounted) {
        setState(() {
          _isLoadingImages = false;
        });
      }
    } catch (e) {
      print('❌ アルバム画像読み込みエラー: $e');
      if (mounted) {
        setState(() {
          _isLoadingImages = false;
        });
      }
    }
  }

  @override
Widget build(BuildContext context) {
  final taskHistory = widget.report.data['taskHistory'] as List<TaskCompletion>? ?? [];
  final totalTasks = widget.report.data['totalTasks'] as int? ?? 0;
  
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
        _buildSummary(totalTasks),
        const SizedBox(height: 16),
        Expanded(
          child: _isLoadingImages
              ? const Center(child: CircularProgressIndicator())
              : _buildTaskHistoryList(taskHistory),
        ),
      ],
    ),
  );
}

  /// 【既存】サマリーを構築
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
          'Daily Take：$totalTasks Plays',
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

  /// 【修正】タスク履歴リストを構築（スクロール対応）
Widget _buildTaskHistoryList(List<TaskCompletion> taskHistory) {
  if (taskHistory.isEmpty) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'No tasks played on this day',
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 14,
            fontFamily: 'Hiragino Sans',
          ),
        ),
      ),
    );
  }
  
  return ListView.builder(
    padding: EdgeInsets.zero,
    itemCount: taskHistory.length,
    itemBuilder: (context, index) {
      final completion = taskHistory[index];
      
      // アルバム画像を取得
      dynamic albumImage;
      
      if (completion.albumType == 'single' && completion.albumId != null) {
        albumImage = _albumImages[completion.albumId];
      } else {
        albumImage = _albumImages['life_dream'];
      }
      
      return TaskHistoryItem(
        completion: completion,
        albumImage: albumImage,
      );
    },
  );
}
}