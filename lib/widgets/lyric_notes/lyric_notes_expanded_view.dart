import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/lyric_note_item.dart';  // 🆕 追加
import 'lyric_hierarchy_toolbar.dart';        // 🆕 追加
import 'lyric_note_line_widget.dart';         // 🆕 追加

/// Lyric Notesの全画面展開ビュー
/// 下から上にスライドして表示され、自由にメモを編集できる
class LyricNotesExpandedView extends StatefulWidget {
  final String taskTitle;
  final List<LyricNoteItem>? initialNotes;  // 🔧 変更: String → List<LyricNoteItem>
  final Color backgroundColor;
  final Function(List<LyricNoteItem>) onSave;  // 🔧 変更: 型をList<LyricNoteItem>に
  final VoidCallback onClose;

  const LyricNotesExpandedView({
    super.key,
    required this.taskTitle,
    required this.initialNotes,  // 🔧 変更
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
  int _currentLineIndex = 0;  // 現在のカーソル行
  Timer? _autoSaveTimer;

  @override
  void initState() {
    super.initState();
    
    // 初期データの設定
    if (widget.initialNotes != null && widget.initialNotes!.isNotEmpty) {
      _notes = List.from(widget.initialNotes!);
    } else {
      // 空の場合は親レベルの空行を1つ作成
      _notes = [
        LyricNoteItem(
          text: '',
          level: 1,
        ),
      ];
    }
    
    // テキストコントローラーの初期化
    _controller = TextEditingController(text: _buildPlainText());
    _focusNode = FocusNode();
    
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  /// 🆕 新規追加: ノートリストからプレーンテキストを生成
  String _buildPlainText() {
    return _notes.map((note) => note.text).join('\n');
  }

  /// 🆕 新規追加: プレーンテキストからノートリストを再構築
  void _rebuildNotesFromText(String text) {
    final lines = text.split('\n');
    
    // 既存のノートの階層情報を保持しながらテキストを更新
    final newNotes = <LyricNoteItem>[];
    
    for (int i = 0; i < lines.length; i++) {
      if (i < _notes.length) {
        // 既存のノートを更新
        newNotes.add(_notes[i].copyWith(
          text: lines[i],
          updatedAt: DateTime.now(),
        ));
      } else {
        // 新しい行は親レベルとして追加
        newNotes.add(LyricNoteItem(
          text: lines[i],
          level: 1,
        ));
      }
    }
    
    _notes = newNotes;
  }

  /// 🔧 修正: テキスト変更時の処理
  void _onTextChanged() {
    if (!_isModified) {
      setState(() {
        _isModified = true;
      });
    }
    
    // カーソル位置から現在の行インデックスを計算
    _updateCurrentLineIndex();
    
    // プレーンテキストからノートリストを再構築
    _rebuildNotesFromText(_controller.text);
    
    // 自動保存タイマーのリセット
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        _saveNotes();
      }
    });
  }

  /// 🆕 新規追加: カーソル位置から現在の行インデックスを更新
  void _updateCurrentLineIndex() {
    final text = _controller.text;
    final cursorPosition = _controller.selection.baseOffset;
    
    if (cursorPosition < 0 || text.isEmpty) {
      _currentLineIndex = 0;
      return;
    }
    
    final beforeCursor = text.substring(0, cursorPosition);
    _currentLineIndex = '\n'.allMatches(beforeCursor).length;
  }

  /// 🆕 新規追加: フォーカス状態の変化を監視
  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      _updateCurrentLineIndex();
      setState(() {});
    }
  }

  /// 🆕 新規追加: 階層を深くする（→ボタン）
  void _increaseLevel() {
    if (_currentLineIndex >= _notes.length) return;
    
    final currentNote = _notes[_currentLineIndex];
    
    // 最大レベル3まで
    if (currentNote.level >= 3) return;
    
    setState(() {
      _notes[_currentLineIndex] = currentNote.copyWith(
        level: currentNote.level + 1,
        updatedAt: DateTime.now(),
      );
    });
    
    _saveNotes();
  }

  /// 🆕 新規追加: 階層を浅くする（←ボタン）
  void _decreaseLevel() {
    if (_currentLineIndex >= _notes.length) return;
    
    final currentNote = _notes[_currentLineIndex];
    
    // 最小レベル1まで
    if (currentNote.level <= 1) return;
    
    setState(() {
      _notes[_currentLineIndex] = currentNote.copyWith(
        level: currentNote.level - 1,
        updatedAt: DateTime.now(),
      );
    });
    
    _saveNotes();
  }

  /// 🆕 新規追加: リスト化（中央ボタン）
  void _toggleList() {
    if (_currentLineIndex >= _notes.length) return;
    
    final currentNote = _notes[_currentLineIndex];
    
    // 既にレベル2以上の場合は、チェック状態をトグル
    if (currentNote.level >= 2) {
      setState(() {
        _notes[_currentLineIndex] = currentNote.copyWith(
          isChecked: !currentNote.isChecked,
          updatedAt: DateTime.now(),
        );
      });
    } else {
      // レベル1の場合は、レベル2に変更
      setState(() {
        _notes[_currentLineIndex] = currentNote.copyWith(
          level: 2,
          updatedAt: DateTime.now(),
        );
      });
      
      // 次の行に移動してレベル3の空行を追加
      _insertNewLineWithLevel(3);
    }
    
    _saveNotes();
  }

  /// 🆕 新規追加: 指定レベルの新しい行を挿入
  void _insertNewLineWithLevel(int level) {
    final newNote = LyricNoteItem(
      text: '',
      level: level,
    );
    
    setState(() {
      _notes.insert(_currentLineIndex + 1, newNote);
      _currentLineIndex++;
    });
    
    // テキストコントローラーを更新
    _controller.text = _buildPlainText();
    
    // カーソルを新しい行の先頭に移動
    final newCursorPosition = _controller.text.split('\n')
        .take(_currentLineIndex + 1)
        .join('\n')
        .length;
    
    _controller.selection = TextSelection.collapsed(
      offset: newCursorPosition,
    );
  }

  /// 🔧 修正: ノートを保存
  void _saveNotes() {
    widget.onSave(_notes);
  }

  /// 🆕 新規追加: 現在の行のレベルを取得
  int _getCurrentLevel() {
    if (_currentLineIndex >= _notes.length) return 1;
    return _notes[_currentLineIndex].level;
  }

  /// 🆕 新規追加: 階層変更ボタンの有効/無効状態を判定
  bool _canIncreaseLevel() {
    return _getCurrentLevel() < 3;
  }

  bool _canDecreaseLevel() {
    return _getCurrentLevel() > 1;
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // キーボードの高さを取得
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardVisible = keyboardHeight > 0;

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
                    onPressed: widget.onClose,
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
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // 入力エリア
            Expanded(
              child: SingleChildScrollView(
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
                    hintText: 'リリックを書いてください。\n思考、感情、振り返り、\n自由に記録しましょう。',
                    hintStyle: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 24,
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

            // 🆕 追加: 階層操作ツールバー（キーボード表示時のみ）
            if (isKeyboardVisible)
              LyricHierarchyToolbar(
                onIncreaseLevel: _increaseLevel,
                onDecreaseLevel: _decreaseLevel,
                onToggleList: _toggleList,
                backgroundColor: widget.backgroundColor,
                canIncreaseLevel: _canIncreaseLevel(),
                canDecreaseLevel: _canDecreaseLevel(),
              ),
          ],
        ),
      ),
    );
  }
}