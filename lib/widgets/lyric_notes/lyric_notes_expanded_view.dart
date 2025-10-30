// widgets/lyric_notes/lyric_notes_expanded_view.dart - Notionスタイル版（シンプル化）
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import '../../models/lyric_note_item.dart';

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

  // 🗑️ 削除: _indicatorScrollController は不要
  final ScrollController _textScrollController = ScrollController();
  
  // 🆕 追加: 三角ボタンの状態管理
  final Map<int, bool> _expandedStates = {}; // index → 展開状態

  final Map<int, String> _placeholders = {}; 

  @override
  void initState() {
  super.initState();
  
  // 🗑️ 削除: スクロール同期処理は不要
  
  // 初期データの設定
  if (widget.initialNotes != null && widget.initialNotes!.isNotEmpty) {
    _notes = List.from(widget.initialNotes!);
    // 🆕 追加: 展開状態の初期化
    for (int i = 0; i < _notes.length; i++) {
      _expandedStates[i] = !_notes[i].isCollapsed;
    }
  } else {
    _notes = [
      LyricNoteItem(
        text: '',
        level: 0, // 🔧 変更: Level 1 → Level 0（通常のノート）
      ),
    ];
  }
  
  _controller = TextEditingController(text: _buildPlainText());
  _focusNode = FocusNode();
  
  _controller.addListener(_onTextChanged);
  _focusNode.addListener(_onFocusChanged);
  
  print('🎵 LyricNotesExpandedView初期化: ${_notes.length}行');
}

  /// ノートリストからプレーンテキストを生成（三角マーク付き）
/// ノートリストからプレーンテキストを生成
String _buildPlainText() {
  final visibleLines = <String>[];
  
  for (int i = 0; i < _notes.length; i++) {
    if (_shouldShowLine(i)) {
      final note = _notes[i];
      String lineText = '';
      
      if (note.level == 1) {
        final isExpanded = _expandedStates[i] ?? false;
        final triangle = isExpanded ? '▼' : '►';
        final placeholder = note.text.isEmpty ? 'リスト化' : note.text;
        lineText = '$triangle $placeholder';
      } else {
        lineText = note.text;
      }
      
      visibleLines.add(lineText);
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
  /// テキストから階層情報を保持しながらノートを再構築
void _rebuildNotesFromText(String text) {
  final lines = text.split('\n');
  final newNotes = <LyricNoteItem>[];
  
  for (int i = 0; i < lines.length; i++) {
    String lineText = lines[i];
    int level = 0; // デフォルトは通常のノート
    
    // 三角マークの検出と除去
    if (lineText.startsWith('▼ ')) {
      level = 1;
      lineText = lineText.substring(2); // '▼ ' を除去
    } else if (lineText.startsWith('► ')) {
      level = 1;
      lineText = lineText.substring(2); // '► ' を除去
    }
    
    if (i < _notes.length) {
      // 既存のノートの階層情報を保持しつつテキストのみ更新
      newNotes.add(_notes[i].copyWith(
        text: lineText,
        level: level, // テキストから判定したレベルを使用
        updatedAt: DateTime.now(),
      ));
    } else {
      // 新しい行は通常のノート（Level 0）として追加
      newNotes.add(LyricNoteItem(
        text: lineText,
        level: level,
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
  
  // 入力されたらプレースホルダーを削除
  final currentLines = _controller.text.split('\n');
  for (int i = 0; i < currentLines.length; i++) {
    if (_placeholders.containsKey(i)) {
      // "► " より長い文字があればプレースホルダーを削除
      if (currentLines[i].length > 2) {
        setState(() {
          _placeholders.remove(i);
        });
      }
    }
  }
  
  final oldLineCount = _notes.length;
  final newLineCount = currentLines.length;
  
  // 改行が追加された場合
  if (newLineCount > oldLineCount) {
    final addedLineIndex = newLineCount - 1;
    
    if (addedLineIndex > 0 && addedLineIndex - 1 < _notes.length) {
      final prevNote = _notes[addedLineIndex - 1];
      
      // 前の行がLevel 1なら、新しい行もLevel 1にする
      if (prevNote.level == 1) {
        _controller.removeListener(_onTextChanged);
        currentLines[addedLineIndex] = '► ';
        _controller.text = currentLines.join('\n');
        
        // カーソル位置を三角の後ろに設定
        final cursorPos = currentLines.take(addedLineIndex + 1).join('\n').length;
        _controller.selection = TextSelection.collapsed(offset: cursorPos);
        
        _controller.addListener(_onTextChanged);
        
        // ノートを追加
        _notes.insert(addedLineIndex, LyricNoteItem(text: '', level: 1));
        _expandedStates[addedLineIndex] = false;
        _placeholders[addedLineIndex] = 'listify'; // プレースホルダー設定
        
        setState(() {
          _currentLineIndex = addedLineIndex;
        });
        
        return;
      }
    }
  }
  
  // 通常のテキスト更新処理
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

/// 追加された行のインデックスを見つける
int _findAddedLineIndex(List<String> lines) {
  for (int i = 0; i < lines.length; i++) {
    if (i >= _notes.length || lines[i].isEmpty) {
      return i;
    }
  }
  return lines.length - 1;
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

  /// 🆕 シンプル版：「リスト化」ボタンの処理
/// リスト化ボタンの処理
/// リスト化ボタンの処理
void _makeList() {
  if (_currentLineIndex >= _notes.length) return;
  
  final currentNote = _notes[_currentLineIndex];
  
  // Level 0 → Level 1 に変換
  if (currentNote.level == 0 && currentNote.text.isEmpty) {
    setState(() {
      _notes[_currentLineIndex] = currentNote.copyWith(level: 1);
      _expandedStates[_currentLineIndex] = false;
      _placeholders[_currentLineIndex] = 'listify'; // プレースホルダー設定
    });
    
    // テキストに三角マークのみ追加
    final lines = _controller.text.split('\n');
    lines[_currentLineIndex] = '► ';
    
    _controller.removeListener(_onTextChanged);
    _controller.text = lines.join('\n');
    _controller.addListener(_onTextChanged);
    
    // カーソル位置を三角の後ろに設定
    final cursorPos = lines.take(_currentLineIndex + 1).join('\n').length;
    _controller.selection = TextSelection.collapsed(offset: cursorPos);
    
    _saveNotes();
  }
}
/// 🆕 新規メソッド: カーソルを指定行に移動
void _moveCursorToLine(int lineIndex) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    
    final lines = _controller.text.split('\n');
    if (lineIndex >= lines.length) return;
    
    // 新しい行の開始位置を計算
    final linesBeforeNew = lines.take(lineIndex + 1).toList();
    final newCursorPosition = linesBeforeNew.join('\n').length;
    
    _controller.selection = TextSelection.collapsed(
      offset: newCursorPosition.clamp(0, _controller.text.length),
    );
    
    setState(() {
      _currentLineIndex = lineIndex;
    });
    
    print('✅ カーソル移動完了: $lineIndex行目');
  });
}

  /// 三角マークをクリックして子要素の展開/折りたたみ
  /// 三角マークをクリックして子要素の展開/折りたたみ
/// 三角マークをタップして展開/折りたたみ
void _toggleCollapseAtIndex(int index) {
  if (index >= _notes.length) return;
  
  final note = _notes[index];
  
  if (note.level != 1) return;
  
  final isCurrentlyExpanded = _expandedStates[index] ?? false;
  
  setState(() {
    _expandedStates[index] = !isCurrentlyExpanded;
    _notes[index] = note.copyWith(
      isCollapsed: isCurrentlyExpanded,
      updatedAt: DateTime.now(),
    );
  });
  
  // 展開した場合は子要素を追加
  if (!isCurrentlyExpanded) {
    final newNote = LyricNoteItem(
      text: '',
      level: 2,
    );
    
    setState(() {
      _notes.insert(index + 1, newNote);
    });
    
    // テキストを更新
    final lines = _controller.text.split('\n');
    lines[index] = '▼ ${note.text}';
    lines.insert(index + 1, '');
    
    _controller.removeListener(_onTextChanged);
    _controller.text = lines.join('\n');
    _controller.addListener(_onTextChanged);
    
    // カーソルを子要素に移動
    _moveCursorToLine(index + 1);
  } else {
    // 折りたたんだ場合はテキストを更新
    final lines = _controller.text.split('\n');
    lines[index] = '► ${note.text}';
    
    _controller.removeListener(_onTextChanged);
    _controller.text = lines.join('\n');
    _controller.addListener(_onTextChanged);
  }
  
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
  /// 指定インデックスの行を表示すべきか判定
bool _shouldShowLine(int index) {
  if (index == 0) return true;  // 最初の行は常に表示
  
  final currentLevel = _notes[index].level;
  
  // Level 0, 1 は常に表示
  if (currentLevel <= 1) return true;
  
  // Level 2, 3 は親が展開されているかチェック
  for (int i = index - 1; i >= 0; i--) {
    final note = _notes[i];
    
    // より浅いレベル（親）を見つけた
    if (note.level < currentLevel) {
      // Level 1の親が折りたたまれていたら非表示
      if (note.level == 1) {
        final isExpanded = _expandedStates[i] ?? true;
        if (!isExpanded) {
          return false;
        }
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
    if (_currentLineIndex >= _notes.length) return 0;
    return _notes[_currentLineIndex].level;
  }

  @override
void dispose() {
  _autoSaveTimer?.cancel();
  _controller.dispose();
  _focusNode.dispose();
  // 🗑️ 削除: _indicatorScrollController.dispose();
  _textScrollController.dispose();
  super.dispose();
}


/// プレースホルダー付きのテキストを生成（スペース確保用）
String _buildTextWithPlaceholders() {
  final lines = _controller.text.split('\n');
  final result = <String>[];
  
  for (int i = 0; i < lines.length; i++) {
    if (_placeholders.containsKey(i) && lines[i] == '► ') {
      result.add('► ${_placeholders[i]}');
    } else {
      result.add(lines[i]);
    }
  }
  
  return result.join('\n');
}

/// くの字アイコン付きプレースホルダーを構築
Widget _buildPlaceholderWithChevron() {
  final lines = _controller.text.split('\n');
  final widgets = <Widget>[];
  
  for (int i = 0; i < lines.length; i++) {
    if (_placeholders.containsKey(i) && (lines[i] == '► ' || lines[i].isEmpty)) {
      final isExpanded = _expandedStates[i] ?? false;
      
      widgets.add(
        SizedBox(
          height: 24.0 * 1.6,
          child: Row(
            children: [
              _ChevronIcon(
                isExpanded: isExpanded,
                size: 18,
              ),
              const SizedBox(width: 4),
              Text(
                _placeholders[i]!,
                style: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 24,
                  height: 1.6,
                  fontWeight: FontWeight.w800,
                ).copyWith(
                  fontFamilyFallback: const ['Hiragino Sans'],
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // 空の行を追加（位置合わせ用）
      widgets.add(
        SizedBox(
          height: 24.0 * 1.6,
        ),
      );
    }
  }
  
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: widgets,
  );
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
                      onPressed: () {
                        _saveNotes();
                        widget.onClose();
                      },
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
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Hiragino Sans',
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  
                  // 右: リスト化ボタン
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: _makeList,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: CustomPaint(
                          size: const Size(20, 20),
                          painter: _RoundedTrianglePainter(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 入力エリア
          // 入力エリア
// 入力エリア
// 入力エリア
Expanded(
  child: SingleChildScrollView(
    controller: _textScrollController,
    padding: const EdgeInsets.all(20),
    child: Stack(
      children: [
        // 実際のテキスト入力フィールド
        GestureDetector(
          onTapDown: (details) {
            _handleTriangleTap(details.localPosition);
          },
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
            decoration: const InputDecoration(
              hintText: 'リリックを書いてください。\n\n右上の三角ボタンでリスト化できます。',
              hintStyle: TextStyle(
                color: Color(0x80FFFFFF),
                fontSize: 20,
                height: 1.6,
                fontWeight: FontWeight.w700,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
            maxLines: null,
            keyboardType: TextInputType.multiline,
            autofocus: false,
          ),
        ),
        
        // プレースホルダーのテキスト表示（TextFieldと完全に同じ位置）
        // くの字アイコンとプレースホルダー表示
if (_placeholders.isNotEmpty)
  Positioned(
    top: 0,
    left: 0,
    right: 0,
    child: IgnorePointer(
      child: _buildPlaceholderWithChevron(),
    ),
  ),
      ],
    ),
  ),
),
        ],
      ),
    ),
  );
}

/// 三角マークのタップを検出
void _handleTriangleTap(Offset localPosition) {
  // タップされた位置から行インデックスを計算
  final lineHeight = 24.0 * 1.6; // fontSize * height
  final tappedLine = (localPosition.dy / lineHeight).floor();
  
  if (tappedLine < 0 || tappedLine >= _notes.length) return;
  
  final note = _notes[tappedLine];
  
  print('👆 タップ検出: line=$tappedLine, level=${note.level}, x=${localPosition.dx}, y=${localPosition.dy}');
  
  // Level 1の三角マークがタップされたか判定
  // 三角マーク（▸）は約20px幅、タップ領域を40pxに拡大
  if (note.level == 1 && localPosition.dx < 40) {
    print('🔽 三角マークタップ: line=$tappedLine');
    _toggleCollapseAtIndex(tappedLine);
  }
}

}

/// 右向き正三角形を描画するCustomPainter
class _RoundedTrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path();
    
    // 右向き正三角形
    final height = size.height;
    final width = height * 0.866; // √3/2 ≈ 0.866
    
    // 左の頂点
    path.moveTo(0, 0);
    // 右の頂点
    path.lineTo(width, height / 2);
    // 左下の頂点
    path.lineTo(0, height);
    path.close();
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


/// Notion風のくの字アイコン
class _ChevronIcon extends StatelessWidget {
  final bool isExpanded;
  final double size;

  const _ChevronIcon({
    required this.isExpanded,
    this.size = 18.0,
  });


  @override
  Widget build(BuildContext context) {
    return AnimatedRotation(
      turns: isExpanded ? 0.25 : 0, // 90度回転で下向き
      duration: const Duration(milliseconds: 200),
      child: Icon(
        Icons.chevron_right,
        size: size,
        color: Colors.white.withOpacity(0.7),
      ),
    );
  }
}

