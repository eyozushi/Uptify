// widgets/completion_dialog.dart - シンプル版
import 'package:flutter/material.dart';
import '../models/task_item.dart';

class CompletionDialog extends StatelessWidget {
  final TaskItem task;
  final String albumName;
  final int elapsedSeconds;
  final VoidCallback onYes;
  final VoidCallback onNo;
  final VoidCallback onCancel;

  const CompletionDialog({
    super.key,
    required this.task,
    required this.albumName,
    required this.elapsedSeconds,
    required this.onYes,
    required this.onNo,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final minutes = elapsedSeconds ~/ 60;
    final seconds = elapsedSeconds % 60;
    final timeText = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black, // 🔧 修正: 黒単色背景
          borderRadius: BorderRadius.circular(20),
          // 🔧 修正: 囲む線を削除
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🔧 修正: チェックマークアイコンのみ（円は削除）
            Icon(
              Icons.check_circle,
              color: task.color,
              size: 60,
            ),
            
            const SizedBox(height: 20),
            
            // タイトル
            const Text(
              'Task Complete!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
            letterSpacing: -0.3,
                fontWeight: FontWeight.bold,
                fontFamily: 'Hiragino Sans',
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 12),
            
            // タスク名
            Text(
              '「${task.title}」',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
            letterSpacing: -0.2,
                fontWeight: FontWeight.w600,
                fontFamily: 'Hiragino Sans',
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 8),
            
            // 経過時間
            Text(
              'Execution Time: $timeText',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
                fontFamily: 'Hiragino Sans',
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 24),
            
            // 質問
            const Text(
              'Did you complete this task?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontFamily: 'Hiragino Sans',
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 32),
            
            // ボタン
            Row(
              children: [
                Expanded(
                  child: _buildButton(
                    text: 'Not Done',
                    color: Colors.grey, // 🔧 修正: 灰色単色
                    textColor: Colors.white,
                    onPressed: onNo,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildButton(
                    text: 'Done!',
                    color: const Color(0xFF1DB954), // 🔧 修正: 緑色単色
                    textColor: Colors.white,
                    onPressed: onYes,
                  ),
                ),
              ],
            ),
            
            // 🔧 修正: スキップボタンを削除
          ],
        ),
      ),
    );
  }

  Widget _buildButton({
    required String text,
    required Color color,
    required Color textColor,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            // 🔧 修正: 光る効果（boxShadow）を削除
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'Hiragino Sans',
              ),
            ),
          ),
        ),
      ),
    );
  }
}