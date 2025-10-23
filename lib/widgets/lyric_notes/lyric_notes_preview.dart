import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Lyric Notesのプレビュー表示ウィジェット
/// アルバムジャケットの下に配置され、メモの先頭3-4行を表示
class LyricNotesPreview extends StatelessWidget {
  final String? noteContent;
  final double width;
  final Color backgroundColor;
  final VoidCallback onTap;

  const LyricNotesPreview({
    super.key,
    required this.noteContent,
    required this.width,
    required this.backgroundColor,
    required this.onTap,
  });

String _getPreviewText() {
  if (noteContent == null || noteContent!.isEmpty) {
    return 'タップして\nリリックを追加...'; // 🔧 日本語に変更
  }
  
  // 最初の4行を取得（🔧 3行 → 4行に変更）
  final lines = noteContent!.split('\n');
  final previewLines = lines.take(4).join('\n'); // 🔧 3 → 4 に変更
  
  // 100文字以上なら省略（🔧 80 → 100 に変更）
  if (previewLines.length > 100) {
    return '${previewLines.substring(0, 100)}...';
  }
  
  return previewLines;
}

  @override
Widget build(BuildContext context) {
  final hasContent = noteContent != null && noteContent!.isNotEmpty;
  
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: width,
      padding: const EdgeInsets.all(20), // 🔧 16 → 20 に変更
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "Lyrics" ヘッダー（左上に小さく表示）
          // "Lyrics" ヘッダー（左上に小さく表示）
Text(
  'Lyrics',
  style: const TextStyle( // 🔧 修正: GoogleFonts.montserrat → TextStyle
    color: Colors.white70, // 🔧 修正: withOpacity(0.7) → Colors.white70
    fontSize: 12,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.4,
    fontFamily: 'SF Pro Text', // 🔧 追加: PlayerScreenと同じフォント
  ),
),
          const SizedBox(height: 12), // 🔧 8 → 12 に変更
          
          // プレビューテキスト（大きく、太く、白色）
          // プレビューテキスト（大きく、太く、白色）
Text(
  _getPreviewText(),
  style: TextStyle( // 🔧 修正: GoogleFonts → TextStyle
    color: hasContent ? Colors.white : Colors.white.withOpacity(0.5),
    fontSize: 24, // 🔧 修正: 18 → 24（タスク名と同じサイズ）
    fontWeight: FontWeight.w700,
    height: 1.6,
    fontFamily: 'Hiragino Sans', // 🔧 追加
  ),
  maxLines: 4,
  overflow: TextOverflow.ellipsis,
),
          
          const SizedBox(height: 8), // 🔧 新規追加：下部の余白
        ],
      ),
    ),
  );
}
}