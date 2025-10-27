// widgets/lyric_notes/lyric_notes_expanded_view.dart - Notionスタイル版
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import '../../models/lyric_note_item.dart';
import 'lyric_note_line_widget.dart';

/// Lyric Notesの全画面展開ビュー - Notionスタイル
/// 「リスト化」ボタン1つで階層を作成
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
  late TextEditingController _controller;
  late FocusNode _focusNode;
  late List<LyricNoteItem> _notes;
  bool _isModified = false;
  int _currentLineIndex = 0;
  Timer? _autoSaveTimer;

  final ScrollController _indicatorScrollController = ScrollController();
  final ScrollController _textScrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    _textScrollController.addListener(() {
      if (_textScrollController.hasClients && _indicatorScrollController.hasClients) {
        _indicatorScrollController.jumpTo(_textScrollController.offset);
      }
    });
    
    // 初期データの設定
    if (widget.initialNotes != null && widget.initialNotes!.isNotEmpty) {
      _notes = List.from(widget.initialNotes!);
    } else {
      _notes = [
        LyricNoteItem(
          text: '',
          level: 1,
        ),
      ];
    }
    
    _controller = TextEditingController(text: _buildPlainText());
    _focusNode = FocusNode();
    
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
    
    print('🎵 LyricNotesExpandedView初期化: ${_notes.length}行');
  }

  /// ノートリストからプレーンテキストを生成（折りたたみ考慮）
  String _buildPlainText() {
    final visibleLines = <String>[];
    
    for (int i = 0; i < _notes.length; i++) {
      if (_shouldShowLine(i)) {
        visibleLines.add(_notes[i].text);
      }
    }
    
    return visibleLines.join('\n');
  }

  /// 🆕 表示用のプレーンテキスト生成（折りたたみ状態を反映）
  String _buildVisibleText() {
    final visibleLines = <String>[];
    
    for (int i = 0; i < _notes.length; i++) {
      if (_shouldShowLine(i)) {
        visibleLines.add(_notes[i].text);
      }
    }
    
    return visibleLines.join('\n');
  }

  /// テキストから階層情報を保持しながらノートを再構築
  void _rebuildNotesFromText(String text) {
    final lines = text.split('\n');
    final newNotes = <LyricNoteItem>[];
    
    for (int i = 0; i < lines.length; i++) {
      final lineText = lines[i];
      
      if (i < _notes.length) {
        // 既存のノートの階層情報を保持しつつテキストのみ更新
        newNotes.add(_notes[i].copyWith(
          text: lineText,
          updatedAt: DateTime.now(),
        ));
      } else {
        // 新しい行は親レベル（Level 1）として追加
        newNotes.add(LyricNoteItem(
          text: lineText,
          level: 1,
        ));
      }
    }
    
    setState(() {
      _notes = newNotes;
    });
  }

  /// テキスト変更時の処理
  void _onTextChanged() {
    if (!_isModified) {
      setState(() {
        _isModified = true;
      });
    }
    
    _updateCurrentLineIndex();
    _rebuildNotesFromText(_controller.text);
    
    // 自動保存タイマーのリセット
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        _saveNotes();
      }
    });
  }

  /// カーソル位置から現在の行インデックスを更新
  void _updateCurrentLineIndex() {
    final text = _controller.text;
    final cursorPosition = _controller.selection.baseOffset;
    
    if (cursorPosition < 0 || text.isEmpty) {
      _currentLineIndex = 0;
      return;
    }
    
    final beforeCursor = text.substring(0, cursorPosition.clamp(0, text.length));
    _currentLineIndex = '\n'.allMatches(beforeCursor).length;
  }

  /// フォーカス状態の変化を監視
  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      _updateCurrentLineIndex();
      setState(() {});
    }
  }

  /// 🆕 Notionスタイル：「リスト化」ボタンの処理
  void _makeList() {
    if (_currentLineIndex >= _notes.length) {
      print('⚠️ 無効な行インデックス: $_currentLineIndex');
      return;
    }
    
    final currentNote = _notes[_currentLineIndex];
    
    print('📋 リスト化実行: line=$_currentLineIndex, level=${currentNote.level}, text="${currentNote.text}"');
    
    // 最大レベル4まで
    if (currentNote.level >= 4) {
      print('⚠️ 最大レベル到達: Level ${currentNote.level}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('これ以上深い階層は作成できません（最大4階層）'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // 1. 次の階層の空行を挿入
    final newNote = LyricNoteItem(
      text: '',
      level: currentNote.level + 1,
    );
    
    setState(() {
      _notes.insert(_currentLineIndex + 1, newNote);
    });
    
    print('✅ 新しい階層挿入: level=${currentNote.level + 1} at ${_currentLineIndex + 1}');
    
    // 2. テキストコントローラーを更新
    final lines = _controller.text.split('\n');
    lines.insert(_currentLineIndex + 1, '');
    
    // リスナーを一時的に解除してテキスト更新
    _controller.removeListener(_onTextChanged);
    _controller.text = lines.join('\n');
    _controller.addListener(_onTextChanged);
    
    print('✅ テキストコントローラー更新完了');
    
    // 3. カーソルを新しい行に移動
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      // 新しい行の開始位置を計算
      final linesBeforeNew = lines.take(_currentLineIndex + 2).toList();
      final newCursorPosition = linesBeforeNew.join('\n').length;
      
      _controller.selection = TextSelection.collapsed(
        offset: newCursorPosition.clamp(0, _controller.text.length),
      );
      
      setState(() {
        _currentLineIndex = _currentLineIndex + 1;
      });
      
      print('✅ カーソル移動完了: $_currentLineIndex行目（Level ${currentNote.level + 1}）');
    });
    
    _saveNotes();
  }

  /// 三角マークをクリックして子要素の展開/折りたたみ
  void _toggleCollapseAtIndex(int index) {
    if (index >= _notes.length) {
      print('⚠️ 無効なインデックス: $index');
      return;
    }
    
    final note = _notes[index];
    
    // 子要素が存在するかチェック
    final hasChildren = _hasChildrenAtIndex(index);
    if (!hasChildren) {
      print('⚠️ 子要素なし: index=$index, text="${note.text}"');
      return;
    }
    
    print('🔽 折りたたみトグル実行:');
    print('  - index: $index');
    print('  - text: "${note.text}"');
    print('  - level: ${note.level}');
    print('  - collapsed: ${note.isCollapsed} → ${!note.isCollapsed}');
    print('  - hasChildren: $hasChildren');
    
    setState(() {
      // 折りたたみ状態をトグル
      _notes[index] = note.copyWith(
        isCollapsed: !note.isCollapsed,
        updatedAt: DateTime.now(),
      );
    });
    
    print('✅ 折りたたみ状態更新完了: ${_notes[index].isCollapsed}');
    
    // 🔧 追加：テキストフィールドを折りたたみ状態に応じて更新
    _controller.removeListener(_onTextChanged);
    _controller.text = _buildVisibleText();
    _controller.addListener(_onTextChanged);
    
    // UIを強制的に更新
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });
    
    _saveNotes();
  }

  /// 指定インデックスの行に子要素が存在するかチェック
  bool _hasChildrenAtIndex(int index) {
    if (index >= _notes.length - 1) return false;
    
    final currentLevel = _notes[index].level;
    
    // 次の行が現在の行よりレベルが深い場合、子要素が存在
    if (index + 1 < _notes.length) {
      return _notes[index + 1].level > currentLevel;
    }
    
    return false;
  }

  /// 指定インデックスの行を表示すべきか判定
  bool _shouldShowLine(int index) {
    if (index == 0) return true;  // 最初の行は常に表示
    
    final currentLevel = _notes[index].level;
    
    // 親レベル（Level 1）は常に表示
    if (currentLevel == 1) return true;
    
    // 親をさかのぼって、折りたたまれている親がいないかチェック
    for (int i = index - 1; i >= 0; i--) {
      final note = _notes[i];
      
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

  /// チェックボックスのトグル
  void _toggleCheckAtIndex(int index) {
    if (index >= _notes.length) return;
    
    final note = _notes[index];
    
    setState(() {
      _notes[index] = note.copyWith(
        isChecked: !note.isChecked,
        updatedAt: DateTime.now(),
      );
    });
    
    print('✓ チェック切り替え: line=$index, checked=${_notes[index].isChecked}');
    _saveNotes();
  }

  /// ノートを保存
  void _saveNotes() {
    // 空行を除外してから保存
    final nonEmptyNotes = _notes.where((note) => note.text.trim().isNotEmpty).toList();
    
    print('💾 保存実行: ${nonEmptyNotes.length}行');
    for (var note in nonEmptyNotes) {
      print('  - L${note.level}: ${note.text.substring(0, note.text.length.clamp(0, 20))}... (checked=${note.isChecked}, collapsed=${note.isCollapsed})');
    }
    
    widget.onSave(nonEmptyNotes);
  }

  /// 現在の行のレベルを取得
  int _getCurrentLevel() {
    if (_currentLineIndex >= _notes.length) return 1;
    return _notes[_currentLineIndex].level;
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    _indicatorScrollController.dispose();
    _textScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: widget.backgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            // ヘッダー部分
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white,
                      size: 32,
                    ),
                    onPressed: () {
                      _saveNotes();
                      widget.onClose();
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const Spacer(),
                  Expanded(
                    flex: 3,
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
                  const Spacer(),
                  // 現在のレベル表示
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'L${_getCurrentLevel()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 🆕 シンプルなツールバー：「リスト化」ボタン1つだけ
            Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                  bottom: BorderSide(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
              ),
              child: Center(
                child: GestureDetector(
                  onTap: _makeList,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1DB954),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.format_list_bulleted,
                          color: Colors.white,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'リスト化',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Hiragino Sans',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 現在の階層情報を表示
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    _getCurrentLevel() == 1 
                        ? Icons.notes 
                        : _getCurrentLevel() == 2 
                            ? Icons.subdirectory_arrow_right 
                            : _getCurrentLevel() == 3
                                ? Icons.more_horiz
                                : Icons.circle,
                    color: Colors.white.withOpacity(0.7),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _getCurrentLevel() == 1 
                        ? '通常のメモ' 
                        : _getCurrentLevel() == 2 
                            ? '子要素（1階層目）' 
                            : _getCurrentLevel() == 3
                                ? '孫要素（2階層目）'
                                : 'ひ孫要素（3階層目）',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Hiragino Sans',
                    ),
                  ),
                ],
              ),
            ),

            // 入力エリア
            Expanded(
              child: Stack(
                children: [
                  // 階層インジケーター（左端に表示）
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 60,
                      color: Colors.black.withOpacity(0.1),
                      child: ListView.builder(
                        controller: _indicatorScrollController,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(top: 20),
                        itemCount: _notes.length,
                        itemBuilder: (context, index) {
                          final note = _notes[index];
                          final isCurrent = index == _currentLineIndex;
                          final hasChildren = _hasChildrenAtIndex(index);
                          
                          // 🔧 追加：折りたたまれた行は表示しない
                          if (!_shouldShowLine(index)) {
                            return const SizedBox.shrink();
                          }
                          
                          return Container(
                            height: 38.4,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 4),
                            decoration: isCurrent 
                                ? BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    border: Border(
                                      left: BorderSide(
                                        color: const Color(0xFF1DB954),
                                        width: 3,
                                      ),
                                    ),
                                  )
                                : null,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // 🔧 修正：三角マークのタップ領域を拡大して確実にタップできるように
                                GestureDetector(
                                  onTap: hasChildren ? () {
                                    print('🔽 三角マークタップ: index=$index, collapsed=${note.isCollapsed}');
                                    _toggleCollapseAtIndex(index);
                                  } : null,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),  // タップ領域拡大
                                    color: Colors.transparent,  // タップ可能領域を視覚化しやすく
                                    child: Icon(
                                      note.isCollapsed 
                                          ? Icons.arrow_right 
                                          : Icons.arrow_drop_down,
                                      color: hasChildren 
                                          ? (isCurrent 
                                              ? const Color(0xFF1DB954)
                                              : Colors.white.withOpacity(0.7))
                                          : Colors.transparent,
                                      size: 20,
                                    ),
                                  ),
                                ),
                                
                                // インデント表示
                                SizedBox(width: (note.level - 1) * 8.0),
                                
                                // チェックボックス（Level 2以上のみ）
                                if (note.level >= 2) ...[
                                  GestureDetector(
                                    onTap: () {
                                      print('✓ チェックボックスタップ: index=$index, checked=${note.isChecked}');
                                      _toggleCheckAtIndex(index);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(4),  // タップ領域拡大
                                      color: Colors.transparent,
                                      child: Icon(
                                        note.isChecked 
                                            ? Icons.check_box 
                                            : Icons.check_box_outline_blank,
                                        color: note.isChecked 
                                            ? const Color(0xFF1DB954) 
                                            : (isCurrent 
                                                ? Colors.white.withOpacity(0.8)
                                                : Colors.white.withOpacity(0.3)),
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  
                  // テキスト入力フィールド
                  Positioned(
                    left: 60,
                    top: 0,
                    right: 0,
                    bottom: 0,
                    child: SingleChildScrollView(
                      controller: _textScrollController,
                      padding: const EdgeInsets.all(20),
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 24,
                          height: 1.6,
                          fontWeight: FontWeight.w800,
                        ).copyWith(
                          fontFamilyFallback: const ['Hiragino Sans'],
                        ),
                        decoration: InputDecoration(
                          hintText: 'リリックを書いてください。\n\n「リスト化」ボタンで階層リストを作成できます。\n\n例：\n知らなかった英単語\n  日常英語\n    apple - りんご',
                          hintStyle: GoogleFonts.inter(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 20,
                            height: 1.6,
                            fontWeight: FontWeight.w700,
                          ).copyWith(
                            fontFamilyFallback: const ['Hiragino Sans'],
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        autofocus: false,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}