// widgets/lyric_notes/lyric_notes_preview.dart
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
  final VoidCallback onEdit; // 🆕 追加：編集ボタン用

  const LyricNotesPreview({
    super.key,
    required this.notes,
    required this.width,
    required this.backgroundColor,
    required this.onTap,
    required this.onEdit, // 🆕 追加
  });


/// プレビューに表示する行を取得（Level 0 と Level 1 のみ、最大4行、空白行を除外）
List<LyricNoteItem> _getPreviewLines() {
  if (notes == null || notes!.isEmpty) {
    return [];
  }
  
  // Level 0（通常メモ）と Level 1（親）のみを抽出し、空白行を除外
  final previewNotes = notes!
      .where((note) => 
        (note.level == 0 || note.level == 1) && 
        note.text.trim().isNotEmpty  // 🔧 追加: 空白行を除外
      )
      .take(4) // 最大4行
      .toList();
  
  return previewNotes;
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
          // "Lyrics" ヘッダー + 編集ボタン
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Lyrics',
                style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
              
              // 編集ボタン（白ペン・緑円）
GestureDetector(
  onTap: onEdit, // ← この onEdit が正しく LyricNotesExpandedView を開いているか確認
  child: Container(
    width: 36,
    height: 36,
    decoration: const BoxDecoration(
      color: Colors.green,
      shape: BoxShape.circle,
    ),
    child: const Center(
      child: Icon(
        Icons.edit,
        color: Colors.white,
        size: 18,
      ),
    ),
  ),
),
            ],
          ),
          const SizedBox(height: 8), // 🔧 修正: 12 → 8（間隔を詰める）
          
          // プレビューテキスト
          RichText(
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            textHeightBehavior: const TextHeightBehavior(
              applyHeightToFirstAscent: false, // 🔧 修正: 最初の行の上部余白を削除
              applyHeightToLastDescent: false,
              leadingDistribution: TextLeadingDistribution.even,
            ),
            text: TextSpan(
              children: _buildPreviewTextSpans(),
            ),
          ),
          
          const SizedBox(height: 4), // 🔧 修正: 8 → 4（間隔を詰める）
        ],
      ),
    ),
  );
}

/// プレビューテキストをTextSpanのリストとして生成（完了状態に応じて色分け）
List<TextSpan> _buildPreviewTextSpans() {
  final previewLines = _getPreviewLines();
  
  if (previewLines.isEmpty) {
    return [
      TextSpan(
        text: 'タップして\nリリックを追加...',
        style: GoogleFonts.inter(
          color: Colors.white.withOpacity(0.5),
          fontSize: 20,
          fontWeight: FontWeight.w700,
          height: 1.6,
        ).copyWith(
          fontFamilyFallback: const ['Hiragino Sans'],
        ),
      ),
    ];
  }
  
  // 各行をTextSpanとして生成
  final spans = <TextSpan>[];
  
  for (int i = 0; i < previewLines.length; i++) {
    final note = previewLines[i];
    
    String prefix = '';
    
    // Level 1（親）には矢印を追加
    if (note.level == 1) {
      prefix = note.isCollapsed ? '→ ' : '↓ ';
    }
    
    final lineText = prefix + note.text;
    
   // 完了状態に応じて文字色を変更
final textColor = note.isCompleted ? Colors.white : Colors.grey[900]; // 🔧 修正: Colors.grey[800] → Colors.grey[900]
    
    spans.add(
      TextSpan(
        text: i < previewLines.length - 1 ? '$lineText\n' : lineText,
        style: GoogleFonts.inter(
          color: textColor,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          height: 1.6,
          // 🗑️ 削除: leadingDistribution（TextSpanではサポートされていない）
        ).copyWith(
          fontFamilyFallback: const ['Hiragino Sans'],
        ),
      ),
    );
  }
  
  return spans;
}

}