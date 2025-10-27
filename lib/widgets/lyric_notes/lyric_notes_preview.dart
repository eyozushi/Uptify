import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/lyric_note_item.dart';

/// Lyric Notesのプレビュー表示ウィジェット
/// アルバムジャケットの下に配置され、メモの先頭3-4行を表示
class LyricNotesPreview extends StatelessWidget {
  final List<LyricNoteItem>? notes;
  final double width;
  final Color backgroundColor;
  final VoidCallback onTap;

  const LyricNotesPreview({
    super.key,
    required this.notes,
    required this.width,
    required this.backgroundColor,
    required this.onTap,
  });

  /// 🔧 修正：階層構造と展開/折りたたみに対応したプレビューテキスト生成
  String _getPreviewText() {
    if (notes == null || notes!.isEmpty) {
      return 'タップして\nリリックを追加...';
    }
    
    // 表示すべき行を抽出（最大4行、折りたたみ考慮）
    final visibleNotes = <LyricNoteItem>[];
    
    for (int i = 0; i < notes!.length; i++) {
      if (visibleNotes.length >= 4) break;
      
      final note = notes![i];
      
      // 空行はスキップ
      if (note.text.trim().isEmpty) continue;
      
      // この行を表示すべきか判定（折りたたみ考慮）
      if (_shouldShowLine(i)) {
        visibleNotes.add(note);
      }
    }
    
    if (visibleNotes.isEmpty) {
      return 'タップして\nリリックを追加...';
    }
    
    // フォントサイズに応じたプレビュー行を生成
    final previewLines = visibleNotes.map((note) {
      String prefix = '';
      
      // レベル2以上には三角マーカーとインデントを追加
      if (note.level == 2) {
        prefix = '  ▸ ';  // 子要素マーカー
      } else if (note.level == 3) {
        prefix = '    ▸ ';  // 孫要素マーカー（深いインデント）
      }
      
      // チェック済みの場合は打ち消し線風に表示
      final displayText = note.isChecked 
          ? '${prefix}✓ ${note.text}' 
          : prefix + note.text;
      
      return displayText;
    }).join('\n');
    
    // 100文字以上なら省略
    if (previewLines.length > 100) {
      return '${previewLines.substring(0, 100)}...';
    }
    
    return previewLines;
  }

  /// 🆕 補助メソッド：指定インデックスの行を表示すべきか判定（折りたたみ考慮）
  bool _shouldShowLine(int index) {
    if (index == 0) return true;  // 最初の行は常に表示
    
    final currentLevel = notes![index].level;
    
    // 親レベル（Level 1）は常に表示
    if (currentLevel == 1) return true;
    
    // 親をさかのぼって、折りたたまれている親がいないかチェック
    for (int i = index - 1; i >= 0; i--) {
      final note = notes![i];
      
      // より浅いレベル（親）を見つけた
      if (note.level < currentLevel) {
        // その親が折りたたまれていたら、この行は非表示
        if (note.isCollapsed) {
          return false;
        }
        
        // さらに上の親を探す必要があれば継続
        if (note.level > 1) {
          continue;
        }
        
        break;
      }
    }
    
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final hasContent = notes != null && notes!.isNotEmpty;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // "Lyrics" ヘッダー
            Text(
              'Lyrics',
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 12),
            
            // プレビューテキスト
            Text(
              _getPreviewText(),
              style: GoogleFonts.inter(
                color: hasContent ? Colors.white : Colors.white.withOpacity(0.5),
                fontSize: 20,  // 🔧 修正：24 → 20（プレビューは少し小さめ）
                fontWeight: FontWeight.w700,
                height: 1.6,
              ).copyWith(
                fontFamilyFallback: const ['Hiragino Sans'],
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}