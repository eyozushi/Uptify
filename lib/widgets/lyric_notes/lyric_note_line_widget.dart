// widgets/lyric_notes/lyric_note_line_widget.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/lyric_note_item.dart';

/// Lyric Noteの1行を表示するウィジェット
/// 階層レベルに応じて背景色とインデントを変更
class LyricNoteLineWidget extends StatelessWidget {
  final LyricNoteItem noteItem;
  final Color baseColor;              // ベースとなるアルバムカラー
  final VoidCallback? onToggleCheck;  // チェック状態の切り替え
  final VoidCallback? onToggleCollapse; // 折りたたみの切り替え
  final bool hasChildren;             // 子要素を持つか

  const LyricNoteLineWidget({
    super.key,
    required this.noteItem,
    required this.baseColor,
    this.onToggleCheck,
    this.onToggleCollapse,
    this.hasChildren = false,
  });

  /// 階層レベルに応じた背景色を生成
  Color _getBackgroundColor() {
    final hsl = HSLColor.fromColor(baseColor);
    
    double lightness;
    switch (noteItem.level) {
      case 1: // 親: 明るめ
        lightness = 0.35;
        break;
      case 2: // 子: 中間
        lightness = 0.25;
        break;
      case 3: // 孫: 最も暗い
        lightness = 0.15;
        break;
      default:
        lightness = 0.35;
    }
    
    final targetSaturation = (hsl.saturation * 0.6).clamp(0.3, 0.7);
    return hsl
        .withLightness(lightness)
        .withSaturation(targetSaturation)
        .toColor();
  }

  /// 階層レベルに応じたインデント幅を取得
  double _getIndentWidth() {
    switch (noteItem.level) {
      case 1:
        return 0.0;
      case 2:
        return 20.0;
      case 3:
        return 40.0;
      default:
        return 0.0;
    }
  }

  /// 階層レベルに応じたフォントサイズを取得
  double _getFontSize() {
    switch (noteItem.level) {
      case 1: // 親: 大きく
        return 24.0;
      case 2: // 子: 中くらい
        return 18.0;
      case 3: // 孫: 小さめ
        return 16.0;
      default:
        return 24.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(left: _getIndentWidth()),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // トグルマーク（子・孫のみ表示）
          if (noteItem.level > 1) ...[
            GestureDetector(
              onTap: hasChildren ? onToggleCollapse : null,
              child: Padding(
                padding: const EdgeInsets.only(right: 8, top: 4),
                child: Icon(
                  noteItem.isCollapsed 
                      ? Icons.arrow_right 
                      : Icons.arrow_drop_down,
                  color: Colors.white.withOpacity(0.7),
                  size: 20,
                ),
              ),
            ),
          ],

          // チェックボックス（Level 2/3のみ）
          if (noteItem.level > 1) ...[
            GestureDetector(
              onTap: onToggleCheck,
              child: Padding(
                padding: const EdgeInsets.only(right: 8, top: 4),
                child: Icon(
                  noteItem.isChecked 
                      ? Icons.check_box 
                      : Icons.check_box_outline_blank,
                  color: noteItem.isChecked 
                      ? const Color(0xFF1DB954) 
                      : Colors.white.withOpacity(0.7),
                  size: 20,
                ),
              ),
            ),
          ],

          // テキスト内容
          Expanded(
            child: Text(
              noteItem.text,
              style: GoogleFonts.inter(
                color: noteItem.isChecked 
                    ? Colors.white.withOpacity(0.5) 
                    : Colors.white,
                fontSize: _getFontSize(),
                fontWeight: noteItem.level == 1 
                    ? FontWeight.w800 
                    : FontWeight.w700,
                height: 1.6,
                decoration: noteItem.isChecked 
                    ? TextDecoration.lineThrough 
                    : null,
              ).copyWith(
                fontFamilyFallback: const ['Hiragino Sans'],
              ),
            ),
          ),
        ],
      ),
    );
  }
}