// widgets/lyric_notes/lyric_notes_expanded_view.dart - 表示専用版
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/lyric_note_item.dart';
import 'lyric_notes_editor_screen.dart';

/// Lyric Notesの全画面表示ビュー（読み取り専用）
class LyricNotesExpandedView extends StatefulWidget {
  final String taskTitle;
  final List<LyricNoteItem>? initialNotes;
  final Color backgroundColor;
  final Function(List<LyricNoteItem>) onSave;
  final VoidCallback onClose;

  const LyricNotesExpandedView({
    super.key,
    required this.taskTitle,
    required this.initialNotes,
    required this.backgroundColor,
    required this.onSave,
    required this.onClose,
  });

  @override
  State<LyricNotesExpandedView> createState() => _LyricNotesExpandedViewState();
}

class _LyricNotesExpandedViewState extends State<LyricNotesExpandedView> {
  late List<LyricNoteItem> _notes;
  final Map<int, bool> _expandedStates = {};
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    
    // 初期データの設定
    if (widget.initialNotes != null && widget.initialNotes!.isNotEmpty) {
      _notes = List.from(widget.initialNotes!);
    } else {
      _notes = [];
    }
    
    // 展開状態を初期化
    for (int i = 0; i < _notes.length; i++) {
      _expandedStates[i] = !_notes[i].isCollapsed;
    }
    
    print('🎵 LyricNotesExpandedView初期化（読み取り専用）: ${_notes.length}行');
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 編集ページを開く
void _openEditor() {
  Navigator.of(context).push(
    PageRouteBuilder(
      fullscreenDialog: true,
      opaque: true,
      pageBuilder: (context, animation, secondaryAnimation) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          )),
          child: LyricNotesEditorScreen(
            taskTitle: widget.taskTitle,
            initialNotes: _notes,
            backgroundColor: Colors.black, // 🔧 追加: 黒色を明示的に指定
            onSave: (notes) {
              setState(() {
                _notes = notes;
                
                // 展開状態も更新
                _expandedStates.clear();
                for (int i = 0; i < _notes.length; i++) {
                  _expandedStates[i] = !_notes[i].isCollapsed;
                }
              });
              
              if (notes.isEmpty) {
                print('🔍 ExpandedView: 空リストを受信（全削除）');
              } else {
                print('🔍 ExpandedView: ${notes.length}行を受信');
              }
              
              widget.onSave(notes);
            },
            onClose: () => Navigator.of(context).pop(),
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    ),
  );
}

@override
void didUpdateWidget(LyricNotesExpandedView oldWidget) {
  super.didUpdateWidget(oldWidget);
  
  // 🆕 追加: 親からのデータが更新された場合、ローカル変数も更新
  if (widget.initialNotes != oldWidget.initialNotes) {
    setState(() {
      _notes = widget.initialNotes != null && widget.initialNotes!.isNotEmpty
          ? List.from(widget.initialNotes!)
          : [];
      
      // 展開状態を再初期化
      _expandedStates.clear();
      for (int i = 0; i < _notes.length; i++) {
        _expandedStates[i] = !_notes[i].isCollapsed;
      }
      
      print('🔍 ExpandedView: データ更新 (${_notes.length}行)');
    });
  }
}

  /// くの字タップで展開/折りたたみ
void _toggleCollapse(int index) {
  if (index >= _notes.length) return;
  
  final note = _notes[index];
  
  // 🔧 修正: Level 1（親）または Level 2（リスト化された子）のみToggle可能
  final hasGrandchildren = _notes.any((n) => n.parentId == note.id && n.level == 3);
  final isLevel2Listified = note.level == 2 && (hasGrandchildren || note.isCollapsed == true); 
  
  if (note.level != 1 && !isLevel2Listified) return;
  
  setState(() {
    _expandedStates[index] = !(_expandedStates[index] ?? true);
    _notes[index] = note.copyWith(
      isCollapsed: !(_expandedStates[index] ?? true),
    );
  });
  
  widget.onSave(_notes);
}
  /// 指定行を表示すべきか判定（折りたたみ考慮）
bool _shouldShowLine(int index) {
  if (index == 0) return true;
  
  final currentNote = _notes[index];
  
  // Level 0とLevel 1は常に表示
  if (currentNote.level <= 1) return true;
  
  // Level 2以上の場合、親の折りたたみ状態をチェック
  if (currentNote.parentId != null) {
    // 親を探す
    final parentIndex = _notes.indexWhere((n) => n.id == currentNote.parentId);
    
    if (parentIndex != -1) {
      // 親が折りたたまれていたら非表示
      final parentExpanded = _expandedStates[parentIndex] ?? true;
      if (!parentExpanded) return false;
      
      // 🔧 修正：親（Level 2）の場合、さらに祖父（Level 1）もチェック
      final parent = _notes[parentIndex];
      if (parent.level == 2 && parent.parentId != null) {
        final grandParentIndex = _notes.indexWhere((n) => n.id == parent.parentId);
        
        if (grandParentIndex != -1) {
          final grandParentExpanded = _expandedStates[grandParentIndex] ?? true;
          if (!grandParentExpanded) return false;
        }
      }
    }
  }
  
  return true;
}
  Widget _buildLine(int index) {
  if (index >= _notes.length) {
    return const SizedBox.shrink();
  }
  
  final note = _notes[index];
  final isExpanded = _expandedStates[index] ?? true;
  
  // Level 0と Level 1は大きく表示（Spotifyスタイル）
  final fontSize = (note.level == 0 || note.level == 1) ? 24.0 : 18.0;
  final fontWeight = (note.level == 0 || note.level == 1) ? FontWeight.w800 : FontWeight.w700;
  final lineHeight = fontSize * 1.6;
  
  // 完了状態に応じて文字色を変更
final textColor = note.isCompleted ? Colors.white : Colors.grey[900]; // 🔧 修正: Colors.grey[800] → Colors.grey[900]
  
  // Level 2がリスト化されているかを判定
  final hasGrandchildren = _notes.any((n) => n.parentId == note.id && n.level == 3);
  final isLevel2Listified = note.level == 2 && (hasGrandchildren || note.isCollapsed == true);
  
  return Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: GestureDetector(
      onTap: () => _toggleLineCompletion(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: lineHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start, // 🔧 修正: center → start（元に戻す）
          children: [
            // Level 1（親）の矢印
if (note.level == 1) ...[
  GestureDetector(
    onTap: () => _toggleCollapse(index),
    child: Container(
      width: 24,
      height: lineHeight,
      // 🔧 修正: padding を削除
      alignment: Alignment.topLeft,
      child: Text(
        isExpanded ? '↓' : '→',
        style: GoogleFonts.inter(
          color: textColor,
          fontSize: fontSize,
          height: 1.6,
          fontWeight: FontWeight.w700,
        ).copyWith(
          fontFamilyFallback: const ['Hiragino Sans'],
        ),
      ),
    ),
  ),
  const SizedBox(width: 4),
],

// Level 2（子）のインデントと矢印
if (note.level == 2) ...[
  const SizedBox(width: 24 + 4),
  
  if (isLevel2Listified) ...[
    GestureDetector(
      onTap: () => _toggleCollapse(index),
      child: Container(
        width: 24,
        height: lineHeight,
        // 🔧 修正: padding を削除
        alignment: Alignment.topLeft,
        child: Text(
          isExpanded ? '↓' : '→',
          style: GoogleFonts.inter(
            color: textColor,
            fontSize: fontSize,
            height: 1.6,
            fontWeight: FontWeight.w700,
          ).copyWith(
            fontFamilyFallback: const ['Hiragino Sans'],
          ),
        ),
      ),
    ),
    const SizedBox(width: 4),
  ],
],
            
            // Level 3（孫）のインデント
            if (note.level == 3)
              const SizedBox(width: (24 + 4) * 2),
            
            // テキスト表示
            Expanded(
              child: Text(
                note.text,
                style: GoogleFonts.inter(
                  color: textColor,
                  fontSize: fontSize,
                  height: 1.6,
                  fontWeight: fontWeight,
                  // 🗑️ 削除: leadingDistribution
                ).copyWith(
                  fontFamilyFallback: const ['Hiragino Sans'],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
/// 行の完了状態を切り替え（子孫も連動）
void _toggleLineCompletion(int index) {
  if (index >= _notes.length) return;
  
  final note = _notes[index];
  final newCompletionState = !note.isCompleted;
  
  setState(() {
    // 該当行の完了状態を変更
    _notes[index] = note.copyWith(isCompleted: newCompletionState);
    
    // 子孫も連動して変更
    _updateDescendantsCompletion(note.id, newCompletionState);
  });
  
  // 保存
  widget.onSave(_notes);
  
  print('✅ 完了状態変更: "${note.text}" → ${newCompletionState ? "完了" : "未完了"}');
}

/// 指定された親IDの子孫すべての完了状態を更新（再帰的）
void _updateDescendantsCompletion(String parentId, bool isCompleted) {
  for (int i = 0; i < _notes.length; i++) {
    final note = _notes[i];
    
    // この親の直接の子要素を見つけたら
    if (note.parentId == parentId) {
      // 完了状態を更新
      _notes[i] = note.copyWith(isCompleted: isCompleted);
      
      // さらにその子孫も再帰的に更新
      _updateDescendantsCompletion(note.id, isCompleted);
    }
  }
}

  @override
Widget build(BuildContext context) {
  return Material(
    color: widget.backgroundColor,
    child: SafeArea(
      child: Column(
        children: [
          // ヘッダー
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SizedBox(
              height: 32,
              child: Stack(
                children: [
                  // 左: 戻るボタン
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.white,
                        size: 32,
                      ),
                      onPressed: widget.onClose,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                  
                  // 中央: タスク名
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 48),
                      child: Text(
                        widget.taskTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Hiragino Sans',
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  
                  // 右: 編集ボタン（白ペン・緑円）
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: _openEditor,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.edit,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // 表示エリア
          Expanded(
            child: _notes.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        '右上のボタンから\nノートを編集して',
                        style: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 20,
                          height: 1.6,
                          fontWeight: FontWeight.w700,
                        ).copyWith(
                          fontFamilyFallback: const ['Hiragino Sans'],
                        ),
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (int i = 0; i < _notes.length; i++)
                          if (_shouldShowLine(i))
                            _buildLine(i),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    ),
  );
}
}