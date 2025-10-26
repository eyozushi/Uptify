// widgets/lyric_notes/lyric_hierarchy_toolbar.dart
import 'package:flutter/material.dart';

/// Lyric Notes階層操作ツールバー
/// キーボード直上に表示され、階層の深さとリスト化を制御する
class LyricHierarchyToolbar extends StatelessWidget {
  final VoidCallback onIncreaseLevel;   // 階層を深くする（→ボタン）
  final VoidCallback onDecreaseLevel;   // 階層を浅くする（←ボタン）
  final VoidCallback onToggleList;      // リスト化（中央ボタン）
  final Color backgroundColor;
  final bool canIncreaseLevel;          // 階層を深くできるか（最大Level 3）
  final bool canDecreaseLevel;          // 階層を浅くできるか（最小Level 1）

  const LyricHierarchyToolbar({
    super.key,
    required this.onIncreaseLevel,
    required this.onDecreaseLevel,
    required this.onToggleList,
    required this.backgroundColor,
    this.canIncreaseLevel = true,
    this.canDecreaseLevel = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 左ボタン: 階層を浅くする（←）
          _buildToolbarButton(
            icon: Icons.arrow_back,
            label: '浅く',
            onTap: canDecreaseLevel ? onDecreaseLevel : null,
            isEnabled: canDecreaseLevel,
          ),

          // 中央ボタン: リスト化（チェックマーク）
          _buildToolbarButton(
            icon: Icons.check_box_outline_blank,
            label: 'リスト化',
            onTap: onToggleList,
            isEnabled: true,
            isCenter: true,
          ),

          // 右ボタン: 階層を深くする（→）
          _buildToolbarButton(
            icon: Icons.arrow_forward,
            label: '深く',
            onTap: canIncreaseLevel ? onIncreaseLevel : null,
            isEnabled: canIncreaseLevel,
          ),
        ],
      ),
    );
  }

  /// ツールバーボタンのウィジェット
  Widget _buildToolbarButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    required bool isEnabled,
    bool isCenter = false,
  }) {
    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isEnabled 
                  ? Colors.white 
                  : Colors.white.withOpacity(0.3),
              size: isCenter ? 28 : 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isEnabled 
                    ? Colors.white 
                    : Colors.white.withOpacity(0.3),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                fontFamily: 'Hiragino Sans',
              ),
            ),
          ],
        ),
      ),
    );
  }
}