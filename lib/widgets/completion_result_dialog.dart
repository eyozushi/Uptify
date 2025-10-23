import 'package:flutter/material.dart';
import '../models/task_item.dart';

class CompletionResultDialog extends StatelessWidget {
  final String albumName;
  final List<TaskItem> tasks;
  final bool allCompleted;
  final Map<String, int> todayTaskCompletions;
  final VoidCallback onClose;

  const CompletionResultDialog({
    super.key,
    required this.albumName,
    required this.tasks,
    required this.allCompleted,
    required this.todayTaskCompletions,
    required this.onClose,
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
            Icon(
              allCompleted ? Icons.celebration : Icons.info_outline,
              color: allCompleted ? const Color(0xFF1DB954) : Colors.orange,
              size: 64,
            ),
            const SizedBox(height: 20),
            Text(
              allCompleted ? '素晴らしい！' : '記録完了',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: 'Hiragino Sans',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (allCompleted) ...[
              Text(
                '全てのタスクの達成を記録しました！',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 16,
                  fontFamily: 'Hiragino Sans',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1DB954).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1DB954).withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Text(
                      '今日の達成回数',
                      style: const TextStyle(
                        color: Color(0xFF1DB954),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Hiragino Sans',
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...tasks.map((task) {
                      final count = todayTaskCompletions[task.id] ?? 0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                task.title,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 14,
                                  fontFamily: 'Hiragino Sans',
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1DB954),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$count回',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ] else ...[
              Text(
                'また次回頑張りましょう！',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 16,
                  fontFamily: 'Hiragino Sans',
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            GestureDetector(
              onTap: onClose,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1DB954),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '閉じる',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Hiragino Sans',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}