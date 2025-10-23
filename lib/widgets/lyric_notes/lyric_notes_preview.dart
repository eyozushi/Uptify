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

  /// プレビューテキストを生成（先頭3行 or 80文字まで）
  String _getPreviewText() {
    if (noteContent == null || noteContent!.isEmpty) {
      return 'Tap to add lyrics...';
    }
    
    // 最初の3行を取得
    final lines = noteContent!.split('\n');
    final previewLines = lines.take(3).join('\n');
    
    // 80文字以上なら省略
    if (previewLines.length > 80) {
      return '${previewLines.substring(0, 80)}...';
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // "Lyrics" ヘッダー（左上に小さく表示）
            Text(
              'Lyrics',
              style: GoogleFonts.montserrat(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            
            // プレビューテキスト（大きく、太く、白色）
            Text(
              _getPreviewText(),
              style: GoogleFonts.notoSansJp(
                color: hasContent ? Colors.white : Colors.white.withOpacity(0.5),
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}