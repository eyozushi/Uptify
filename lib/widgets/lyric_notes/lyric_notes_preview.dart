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

  /// プレビューテキスト生成
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
      
      // Level 1には三角マークを追加
      if (note.level == 1) {
        final isExpanded = !note.isCollapsed;
        prefix = isExpanded ? '▼ ' : '► ';
      }
      // Level 2以上にはインデントを追加
      else if (note.level == 2) {
        prefix = '  ';
      } else if (note.level == 3) {
        prefix = '    ';
      }
      
      return prefix + note.text;
    }).join('\n');
    
    // 100文字以上なら省略
    if (previewLines.length > 100) {
      return '${previewLines.substring(0, 100)}...';
    }
    
    return previewLines;
  }

  /// 指定インデックスの行を表示すべきか判定（折りたたみ考慮）
  bool _shouldShowLine(int index) {
    if (index == 0) return true;
    
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
          // "Lyrics" ヘッダー + 編集ボタン
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Lyrics',
                style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
              
              // 編集ボタン（白ペン・緑円）
              GestureDetector(
                onTap: onEdit,
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
          const SizedBox(height: 12),
          
          // プレビューテキスト
          RichText( // 🔧 修正: Text → RichText に変更
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              children: _buildPreviewTextSpans(), // 🆕 追加
            ),
          ),
          
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// プレビューテキストをTextSpanのリストとして生成（完了状態に応じて色分け）
List<TextSpan> _buildPreviewTextSpans() {
  if (notes == null || notes!.isEmpty) {
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
  
  for (int i = 0; i < visibleNotes.length; i++) {
    final note = visibleNotes[i];
    
    String prefix = '';
    
    // Level 1には三角マークを追加
    if (note.level == 1) {
      final isExpanded = !note.isCollapsed;
      prefix = isExpanded ? '▼ ' : '► ';
    }
    // Level 2以上にはインデントを追加
    else if (note.level == 2) {
      prefix = '  ';
    } else if (note.level == 3) {
      prefix = '    ';
    }
    
    final lineText = prefix + note.text;
    
    // 🆕 追加: 完了状態に応じた色
    final textColor = note.isCompleted ? Colors.white : Colors.black;
    
    spans.add(
      TextSpan(
        text: i < visibleNotes.length - 1 ? '$lineText\n' : lineText,
        style: GoogleFonts.inter(
          color: textColor, // 🔧 修正: 完了状態に応じた色
          fontSize: 20,
          fontWeight: FontWeight.w700,
          height: 1.6,
        ).copyWith(
          fontFamilyFallback: const ['Hiragino Sans'],
        ),
      ),
    );
  }
  
  return spans;
}

}