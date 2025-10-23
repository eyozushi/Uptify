// widgets/playback/task_history_item.dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import '../../models/task_completion.dart';

/// タスク履歴の1行表示ウィジェット
class TaskHistoryItem extends StatelessWidget {
  /// タスク完了記録
  final TaskCompletion completion;
  
  /// アルバムジャケット画像（オプション）
  final Uint8List? albumImage;
  
  const TaskHistoryItem({
    super.key,
    required this.completion,
    this.albumImage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Row(
        children: [
          // アルバムジャケット
          _buildAlbumCover(),
          
          const SizedBox(width: 12),
          
          // タスク名
          Expanded(
            child: Text(
              completion.taskTitle,
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
          
          const SizedBox(width: 12),
          
          // 再生時刻
          Text(
            _formatTime(completion.completedAt),
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 13,
              fontWeight: FontWeight.w400,
              fontFamily: 'SF Pro Text',
            ),
          ),
        ],
      ),
    );
  }

  /// 【確認】アルバムカバーを構築
Widget _buildAlbumCover() {
  return Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(4),
      color: Colors.white.withOpacity(0.1),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: albumImage != null
          ? Image.memory(
              albumImage!,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
            )
          : Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1DB954),
                    Color(0xFF1ED760),
                  ],
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.music_note,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
    ),
  );
}

  /// 【新規追加】時刻をフォーマット（HH:MM形式）
  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}