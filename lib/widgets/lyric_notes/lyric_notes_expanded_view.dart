// widgets/lyric_notes/lyric_notes_expanded_view.dart - 完全修正版
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';  // 🔧 追加：Timerのために必須
import '../../models/lyric_note_item.dart';
import 'lyric_hierarchy_toolbar.dart';
import 'lyric_note_line_widget.dart';

/// Lyric Notesの全画面展開ビュー
/// 下から上にスライドして表示され、自由にメモを編集できる
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

  @override
  void initState() {
    super.initState();
    
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

  /// ノートリストからプレーンテキストを生成
  String _buildPlainText() {
    return _notes.map((note) => note.text).join('\n');
  }

  /// 🔧 修正版：階層情報を保持しながらテキストを更新
  void _rebuildNotesFromText(String text) {
    final lines = text.split('\n');
    final newNotes = <LyricNoteItem>[];
    
    for (int i = 0; i < lines.length; i++) {
      if (i < _notes.length) {
        // 既存のノートの階層情報を保持
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
    print('📝 テキスト再構築: ${_notes.length}行, 現在行=$_currentLineIndex');
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
    
    print('📍 カーソル位置: $_currentLineIndex行目');
  }

  /// フォーカス状態の変化を監視
  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      _updateCurrentLineIndex();
      setState(() {});
    }
  }

  /// 🔧 修正版：階層を深くする（→ボタン）
  void _increaseLevel() {
    if (_currentLineIndex >= _notes.length) return;
    
    final currentNote = _notes[_currentLineIndex];
    
    // 最大レベル3まで
    if (currentNote.level >= 3) {
      print('⚠️ 最大レベル到達');
      return;
    }
    
    setState(() {
      _notes[_currentLineIndex] = currentNote.copyWith(
        level: currentNote.level + 1,
        updatedAt: DateTime.now(),
      );
    });
    
    print('➡️ レベル上昇: ${currentNote.level} → ${currentNote.level + 1}');
    _saveNotes();
  }

  /// 🔧 修正版：階層を浅くする（←ボタン）
  void _decreaseLevel() {
    if (_currentLineIndex >= _notes.length) return;
    
    final currentNote = _notes[_currentLineIndex];
    
    // 最小レベル1まで
    if (currentNote.level <= 1) {
      print('⚠️ 最小レベル到達');
      return;
    }
    
    setState(() {
      _notes[_currentLineIndex] = currentNote.copyWith(
        level: currentNote.level - 1,
        updatedAt: DateTime.now(),
      );
    });
    
    print('⬅️ レベル低下: ${currentNote.level} → ${currentNote.level - 1}');
    _saveNotes();
  }

  /// 🔧 修正版：リスト化（中央ボタン）
  void _toggleList() {
    if (_currentLineIndex >= _notes.length) return;
    
    final currentNote = _notes[_currentLineIndex];
    
    print('🎯 リスト化実行: level=${currentNote.level}, checked=${currentNote.isChecked}');
    
    // 既にレベル2以上の場合は、チェック状態をトグル
    if (currentNote.level >= 2) {
      setState(() {
        _notes[_currentLineIndex] = currentNote.copyWith(
          isChecked: !currentNote.isChecked,
          updatedAt: DateTime.now(),
        );
      });
      print('✅ チェック切り替え: ${!currentNote.isChecked}');
    } else {
      // レベル1の場合は、レベル2に変更
      setState(() {
        _notes[_currentLineIndex] = currentNote.copyWith(
          level: 2,
          updatedAt: DateTime.now(),
        );
      });
      print('📋 レベル1→2に変更');
      
      // 次の行に移動してレベル3の空行を追加
      _insertNewLineWithLevel(3);
    }
    
    _saveNotes();
  }

  /// 指定レベルの新しい行を挿入
  void _insertNewLineWithLevel(int level) {
    final newNote = LyricNoteItem(
      text: '',
      level: level,
    );
    
    setState(() {
      _notes.insert(_currentLineIndex + 1, newNote);
      _currentLineIndex++;
    });
    
    print('➕ 新規行挿入: level=$level at ${_currentLineIndex}');
    
    // テキストコントローラーを更新
    _controller.text = _buildPlainText();
    
    // カーソルを新しい行の先頭に移動
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      final lines = _controller.text.split('\n');
      final newCursorPosition = lines.take(_currentLineIndex + 1).join('\n').length;
      
      _controller.selection = TextSelection.collapsed(
        offset: newCursorPosition.clamp(0, _controller.text.length),
      );
    });
  }

  /// ノートを保存
  void _saveNotes() {
    // 空行を除外してから保存
    final nonEmptyNotes = _notes.where((note) => note.text.trim().isNotEmpty).toList();
    
    print('💾 保存実行: ${nonEmptyNotes.length}行');
    for (var note in nonEmptyNotes) {
      print('  - L${note.level}: ${note.text.substring(0, note.text.length.clamp(0, 20))}... (checked=${note.isChecked})');
    }
    
    widget.onSave(nonEmptyNotes);
  }

  /// 現在の行のレベルを取得
  int _getCurrentLevel() {
    if (_currentLineIndex >= _notes.length) return 1;
    return _notes[_currentLineIndex].level;
  }

  /// 階層変更ボタンの有効/無効状態を判定
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
                  // デバッグ情報表示
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

            // 🔧 修正：ツールバーを常時上部に表示
            Container(
              height: 44,
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // 左ボタン: 階層を浅くする（←）
                  _buildCompactButton(
                    icon: Icons.arrow_back,
                    label: '浅く',
                    onTap: _canDecreaseLevel() ? _decreaseLevel : null,
                  ),
                  
                  // 中央ボタン: リスト化（チェックマーク）
                  _buildCompactButton(
                    icon: Icons.check_box_outline_blank,
                    label: 'リスト',
                    onTap: _toggleList,
                    isCenter: true,
                  ),
                  
                  // 右ボタン: 階層を深くする（→）
                  _buildCompactButton(
                    icon: Icons.arrow_forward,
                    label: '深く',
                    onTap: _canIncreaseLevel() ? _increaseLevel : null,
                  ),
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
          ],
        ),
      ),
    );
  }

  /// 🆕 コンパクトなボタンウィジェット
  Widget _buildCompactButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool isCenter = false,
  }) {
    final isEnabled = onTap != null;
    
    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isEnabled 
                  ? Colors.white 
                  : Colors.white.withOpacity(0.3),
              size: isCenter ? 22 : 20,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isEnabled 
                    ? Colors.white 
                    : Colors.white.withOpacity(0.3),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: 'Hiragino Sans',
              ),
            ),
          ],
        ),
      ),
    );
  }
}