import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/lyric_note_item.dart';  // 🆕 追加

/// Lyric Notesのプレビュー表示ウィジェット
/// アルバムジャケットの下に配置され、メモの先頭3-4行を表示
class LyricNotesPreview extends StatelessWidget {
  final List<LyricNoteItem>? notes;  // 🔧 変更: String → List<LyricNoteItem>
  final double width;
  final Color backgroundColor;
  final VoidCallback onTap;

  const LyricNotesPreview({
    super.key,
    required this.notes,  // 🔧 変更
    required this.width,
    required this.backgroundColor,
    required this.onTap,
  });

/// 🔧 修正: 階層構造対応のプレビューテキスト生成
String _getPreviewText() {
  if (notes == null || notes!.isEmpty) {
    return 'タップして\nリリックを追加...';
  }
  
  // 折りたたまれていない行のみを抽出（最大4行）
  final visibleNotes = <LyricNoteItem>[];
  
  for (final note in notes!) {
    if (visibleNotes.length >= 4) break;
    
    // 空行はスキップ
    if (note.text.trim().isEmpty) continue;
    
    visibleNotes.add(note);
  }
  
  if (visibleNotes.isEmpty) {
    return 'タップして\nリリックを追加...';
  }
  
  // 🔧 デバッグ用：階層情報を出力
  print('📝 プレビュー表示: ${visibleNotes.length}行');
  for (final note in visibleNotes) {
    print('  - Level ${note.level}: "${note.text}"');
  }
  
  // インデントを表示用に変換
  final previewLines = visibleNotes.map((note) {
    String prefix = '';
    
    // レベル2以上にはインデントマーカーを追加
    if (note.level == 2) {
      prefix = '  • ';  // 子要素マーカー
    } else if (note.level == 3) {
      prefix = '    - ';  // 孫要素マーカー
    }
    
    return prefix + note.text;
  }).join('\n');
  
  // 100文字以上なら省略
  if (previewLines.length > 100) {
    return '${previewLines.substring(0, 100)}...';
  }
  
  return previewLines;
}

  @override
Widget build(BuildContext context) {
  final hasContent = notes != null && notes!.isNotEmpty;  // 🔧 変更
  
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
              fontSize: 24,
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