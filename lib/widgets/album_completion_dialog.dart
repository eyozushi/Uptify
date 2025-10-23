import 'package:flutter/material.dart';
import '../models/task_item.dart';

class AlbumCompletionDialog extends StatelessWidget {
  final String albumName;
  final List<TaskItem> tasks;
  final VoidCallback onYes;
  final VoidCallback onNo;

  const AlbumCompletionDialog({
    super.key,
    required this.albumName,
    required this.tasks,
    required this.onYes,
    required this.onNo,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Color(0xFF1DB954),
              size: 64,
            ),
            const SizedBox(height: 20),
            Text(
              'アルバム完了！',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: 'Hiragino Sans',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              '「$albumName」の全ての時間が終了しました。',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 16,
                fontFamily: 'Hiragino Sans',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Text(
              '全てのタスクを実行できましたか？',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                fontFamily: 'Hiragino Sans',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: _buildButton(
                    text: 'いいえ',
                    color: Colors.grey,
                    onTap: onNo,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildButton(
                    text: 'はい',
                    color: const Color(0xFF1DB954),
                    onTap: onYes,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton({
    required String text,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: 'Hiragino Sans',
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}