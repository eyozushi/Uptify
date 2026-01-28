
import 'package:flutter/material.dart';
import 'dart:async';
import '../../models/lyric_note_item.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class LyricNotesEditorScreen extends StatefulWidget {
  final String taskTitle;
  final List<LyricNoteItem>? initialNotes;
  final Function(List<LyricNoteItem>) onSave;
  final VoidCallback onClose;
  final Color backgroundColor;

  const LyricNotesEditorScreen({
    super.key,
    required this.taskTitle,
    required this.initialNotes,
    required this.onSave,
    required this.onClose,
    this.backgroundColor = Colors.black, // 🔧 修正: const Color(0xFF121212) → Colors.black
  });

  @override
  State<LyricNotesEditorScreen> createState() => _LyricNotesEditorScreenState();
}

class _LyricNotesEditorScreenState extends State<LyricNotesEditorScreen> {

  // 🆕 追加: ダミー文字（Zero-Width Space）
  static const String _dummyChar = ' '; // 半角スペース

  late List<LyricNoteItem> _notes; // 全てのノート（表示/非表示含む）
  final List<TextEditingController> _controllers = [];
  final List<FocusNode> _focusNodes = [];
  Timer? _autoSaveTimer;
  final ScrollController _scrollController = ScrollController();
  bool _isUpdating = false;
  int? _focusedIndex;

  @override
void initState() {
  super.initState();
  
  // 初期データの設定
  if (widget.initialNotes != null && widget.initialNotes!.isNotEmpty) {
    // 🆕 修正: 各行の先頭に _dummyChar を追加
    _notes = widget.initialNotes!.map((note) {
      if (note.text.isEmpty || !note.text.startsWith(_dummyChar)) {
        return note.copyWith(text: _dummyChar + note.text);
      }
      return note;
    }).toList();
  } else {
    _notes = [];
  }
  
  // 常に最後に空行を追加（Level 0, parentId: null）
  _notes.add(LyricNoteItem(text: _dummyChar, level: 0, parentId: null));
  
  // 表示される行のコントローラーを作成
  _rebuildControllers();
  
  print('🎵 LyricNotesEditorScreen初期化: ${_notes.length}行（全体）');
}

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _scrollController.dispose();
    
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    
    super.dispose();
  }

  /// コントローラーを再構築
  void _rebuildControllers() {
    // 既存のコントローラーを破棄
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    
    _controllers.clear();
    _focusNodes.clear();
    
    // 表示される行のみコントローラーを作成
    final visibleNotes = _getVisibleNotes();
    for (int i = 0; i < visibleNotes.length; i++) {
      _setupLine(i, visibleNotes[i]);
    }
  }

  /// 表示すべきノートのリストを取得
List<LyricNoteItem> _getVisibleNotes() {
  final visible = <LyricNoteItem>[];
  
  for (final note in _notes) {
    // 親が折りたたまれているかチェック
    if (note.parentId != null) {
      final parent = _notes.firstWhere(
        (n) => n.id == note.parentId,
        orElse: () => note,
      );
      
      // 親が折りたたまれていたら非表示
      if (parent.isCollapsed) {
        continue;
      }
      
      // 🆕 追加：孫の場合、親の親（祖父）もチェック
      if (note.level >= 3 && parent.parentId != null) {
        final grandParent = _notes.firstWhere(
          (n) => n.id == parent.parentId,
          orElse: () => parent,
        );
        
        // 祖父が折りたたまれていたら非表示
        if (grandParent.isCollapsed) {
          continue;
        }
      }
    }
    
    visible.add(note);
  }
  
  return visible;
}

  /// 実際のノートのインデックスを取得（表示インデックスから）
  int _getRealIndex(int visibleIndex) {
    final visibleNotes = _getVisibleNotes();
    if (visibleIndex >= visibleNotes.length) return -1;
    
    final targetNote = visibleNotes[visibleIndex];
    return _notes.indexWhere((n) => n.id == targetNote.id);
  }

  void _setupLine(int index, LyricNoteItem note) {
  // 🆕 修正: 全ての行で _dummyChar を先頭に持つ
  final displayText = note.text.startsWith(_dummyChar) ? note.text : _dummyChar + note.text;
  
  final controller = TextEditingController(text: displayText);
  final focusNode = FocusNode();
  
  _controllers.add(controller);
  _focusNodes.add(focusNode);
  
  String previousText = displayText;
  bool hasAddedNewLine = false;
  
  controller.addListener(() {
    if (!_isUpdating) {
      final currentText = controller.text;
      
      print('🐛 リスナー発火: index=$index, currentText="$currentText" (length=${currentText.length}), previousText="$previousText" (length=${previousText.length})');
      
      // 🆕 修正: _dummyChar を除去してクリーンなテキストを取得
      final currentTextClean = currentText.startsWith(_dummyChar) 
          ? currentText.substring(_dummyChar.length) 
          : currentText;
      final previousTextClean = previousText.startsWith(_dummyChar) 
          ? previousText.substring(_dummyChar.length) 
          : previousText;
    
    // 🔧 追加：改行が入力された時の処理
final hasNewline = currentText.contains('\n') && !previousText.contains('\n');
final isAddingNewline = currentText.length > previousText.length && currentText.endsWith('\n');

if (hasNewline || isAddingNewline) {
  print('🔍 改行検知: index=$index');

  final realIndex = _getRealIndex(index);
  if (realIndex != -1) {
    final currentNote = _notes[realIndex];
    
    // 親（Level 1）で折りたたみ中の場合
if (currentNote.level == 1 && currentNote.isCollapsed) {
  
  // 🆕 追加：見た目が空（ダミー文字のみ）の場合は、Level 0 に変換
  final textWithoutNewline = currentText.replaceAll('\n', '');
  if (textWithoutNewline.isEmpty || textWithoutNewline == _dummyChar) {
    print('🔍 親（Level 1、折りたたみ中、空）で改行 → Level 0に変換');
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isUpdating) return;
      
      _isUpdating = true;
      
      // 子孫を削除
      final nodesToDelete = <String>[];
      _collectDescendants(currentNote.id, nodesToDelete);
      
      if (nodesToDelete.isNotEmpty) {
        _notes.removeWhere((note) => nodesToDelete.contains(note.id));
      }
      
      // Level 0 に変換（テキストを空にする）
      final noteRealIndex = _notes.indexWhere((n) => n.id == currentNote.id);
      if (noteRealIndex != -1) {
        _notes[noteRealIndex] = _notes[noteRealIndex].copyWith(
          text: '',
          level: 0,
          parentId: null,
          isCollapsed: false,
        );
      }
      
      controller.text = '';
      controller.selection = const TextSelection.collapsed(offset: 0);
      
      setState(() {
        _rebuildControllers();
      });
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _isUpdating = false;
        if (index < _focusNodes.length) {
          _focusNodes[index].requestFocus();
        }
      });
    });
    
    previousText = currentText;
    return;
  }
  
  print('🔍 親（Level 1、折りたたみ中）で改行');
  
  // 🆕 修正: 新しい親を直接 Level 1 + _dummyChar で作成
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted || _isUpdating) return;
    
    _isUpdating = true;
    
    // 改行を除去して元のテキストを復元
    final cleanText = _dummyChar + currentText.replaceAll('\n', '').substring(1); // 先頭の_dummyCharを保持
    controller.text = cleanText;
    controller.selection = TextSelection.collapsed(offset: cleanText.length);
    
    // 元の行のテキストを更新
    _notes[realIndex] = currentNote.copyWith(text: cleanText);
    
    // 新しい親を Level 1 + _dummyChar で直接作成
    final newNote = LyricNoteItem(
      text: _dummyChar,
      level: 1,
      parentId: null,
      isCollapsed: true,
    );
    
    // 🆕 修正: 親の子孫をスキップして挿入位置を決定
int insertPosition = realIndex + 1;
for (int i = realIndex + 1; i < _notes.length; i++) {
  final n = _notes[i];
  if (n.parentId == currentNote.id || _isDescendantOf(n, currentNote.id)) {
    insertPosition = i + 1;
  } else {
    break;
  }
}

_notes.insert(insertPosition, newNote);
    
    setState(() {
      _rebuildControllers();
    });
    
    // フォーカスを新しい行に移動
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isUpdating = false;
      
      final newVisibleIndex = _getVisibleNotes().indexWhere((n) => n.id == newNote.id);
      if (newVisibleIndex != -1 && newVisibleIndex < _focusNodes.length) {
        _focusNodes[newVisibleIndex].requestFocus();
        
        // カーソルをダミー文字の後ろに設定
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (newVisibleIndex < _controllers.length) {
            _controllers[newVisibleIndex].selection = 
                TextSelection.collapsed(offset: _dummyChar.length);
          }
        });
      }
    });
  });
  
  previousText = currentText;
  return;
}

// 🆕 追加: 親（Level 1）で展開中の場合
else if (currentNote.level == 1 && !currentNote.isCollapsed) {
  final textWithoutNewline = currentText.replaceAll('\n', '');
  
  // 見た目が空（ダミー文字のみ）の場合 → Level 0 に変換
  if (textWithoutNewline.isEmpty || textWithoutNewline == _dummyChar) {
    print('🔍 親（Level 1、展開中、空）で改行 → Level 0に変換');
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isUpdating) return;
      
      _isUpdating = true;
      
      // 子孫を削除
      final nodesToDelete = <String>[];
      _collectDescendants(currentNote.id, nodesToDelete);
      
      if (nodesToDelete.isNotEmpty) {
        _notes.removeWhere((note) => nodesToDelete.contains(note.id));
      }
      
      // Level 0 に変換
      final noteRealIndex = _notes.indexWhere((n) => n.id == currentNote.id);
      if (noteRealIndex != -1) {
        _notes[noteRealIndex] = _notes[noteRealIndex].copyWith(
          text: _dummyChar,
          level: 0,
          parentId: null,
          isCollapsed: false,
        );
      }
      
      controller.text = _dummyChar;
      controller.selection = TextSelection.collapsed(offset: _dummyChar.length);
      
      setState(() {
        _rebuildControllers();
      });
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _isUpdating = false;
        
        final newVisibleIndex = _getVisibleNotes().indexWhere((n) => n.id == currentNote.id);
        if (newVisibleIndex != -1 && newVisibleIndex < _focusNodes.length) {
          _focusNodes[newVisibleIndex].requestFocus();
        }
      });
    });
    
    previousText = currentText;
    return;
  }
  
  // ユーザーが入力していた場合 → 子ランクにカーソル移動
  print('🔍 親（Level 1、展開中）で改行 → 子ランクへ');
  
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted || _isUpdating) return;
    
    _isUpdating = true;
    
    // 改行を除去して元のテキストを復元
    final cleanText = textWithoutNewline;
    controller.text = cleanText;
    controller.selection = TextSelection.collapsed(offset: cleanText.length);
    _notes[realIndex] = currentNote.copyWith(text: cleanText);
    
    // この親の子要素を取得
    final children = _notes.where((n) => 
      n.parentId == currentNote.id && n.level == 2
    ).toList();
    
    if (children.isEmpty) {
      // 子がいない場合は新しい子を作成
      final newChild = LyricNoteItem(
        text: _dummyChar,
        level: 2,
        parentId: currentNote.id,
      );
      _notes.insert(realIndex + 1, newChild);
      
      setState(() {
        _rebuildControllers();
      });
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _isUpdating = false;
        
        final newVisibleIndex = _getVisibleNotes().indexWhere((n) => n.id == newChild.id);
        if (newVisibleIndex != -1 && newVisibleIndex < _focusNodes.length) {
          _focusNodes[newVisibleIndex].requestFocus();
          
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (newVisibleIndex < _controllers.length) {
              _controllers[newVisibleIndex].selection = 
                  TextSelection.collapsed(offset: _dummyChar.length);
            }
          });
        }
      });
    } else {
      // 子がいる場合
      final firstChild = children.first;
      final firstChildCleanText = firstChild.text.startsWith(_dummyChar)
          ? firstChild.text.substring(_dummyChar.length)
          : firstChild.text;
      
      if (firstChildCleanText.isEmpty) {
        // 最初の子が空の場合 → その子にカーソル移動
        setState(() {
          _rebuildControllers();
        });
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _isUpdating = false;
          
          final firstChildVisibleIndex = _getVisibleNotes().indexWhere((n) => n.id == firstChild.id);
          if (firstChildVisibleIndex != -1 && firstChildVisibleIndex < _focusNodes.length) {
            _focusNodes[firstChildVisibleIndex].requestFocus();
            
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (firstChildVisibleIndex < _controllers.length) {
                _controllers[firstChildVisibleIndex].selection = 
                    TextSelection.collapsed(offset: _dummyChar.length);
              }
            });
          }
        });
      } else {
        // 最初の子に入力がある場合 → 新しい子を手前に追加
        final firstChildRealIndex = _notes.indexWhere((n) => n.id == firstChild.id);
        
        final newChild = LyricNoteItem(
          text: _dummyChar,
          level: 2,
          parentId: currentNote.id,
        );
        _notes.insert(firstChildRealIndex, newChild);
        
        setState(() {
          _rebuildControllers();
        });
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _isUpdating = false;
          
          final newVisibleIndex = _getVisibleNotes().indexWhere((n) => n.id == newChild.id);
          if (newVisibleIndex != -1 && newVisibleIndex < _focusNodes.length) {
            _focusNodes[newVisibleIndex].requestFocus();
            
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (newVisibleIndex < _controllers.length) {
                _controllers[newVisibleIndex].selection = 
                    TextSelection.collapsed(offset: _dummyChar.length);
              }
            });
          }
        });
      }
    }
  });
  
  previousText = currentText;
  return;
}

// 子（Level 2）の場合
else if (currentNote.level == 2) {
  print('🔍 子（Level 2）で改行');
  
  // 🆕 追加: リスト化されていて展開中の場合
  final hasGrandchildren = _notes.any((n) => n.parentId == currentNote.id && n.level == 3);
  final isLevel2Listified = hasGrandchildren || currentNote.isCollapsed == true;
  
  if (isLevel2Listified && currentNote.isCollapsed == false) {
    final textWithoutNewline = currentText.replaceAll('\n', '');
    
    // 見た目が空（ダミー文字のみ）の場合 → 通常の子に変換
    if (textWithoutNewline.isEmpty || textWithoutNewline == _dummyChar) {
      print('🔍 子（Level 2、リスト化、展開中、空）で改行 → 通常の子に変換');
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _isUpdating) return;
        
        _isUpdating = true;
        
        // 孫を削除
        final nodesToDelete = <String>[];
        _collectDescendants(currentNote.id, nodesToDelete);
        
        if (nodesToDelete.isNotEmpty) {
          _notes.removeWhere((note) => nodesToDelete.contains(note.id));
        }
        
        // 通常の子に変換
        final noteRealIndex = _notes.indexWhere((n) => n.id == currentNote.id);
        if (noteRealIndex != -1) {
          _notes[noteRealIndex] = _notes[noteRealIndex].copyWith(
            text: _dummyChar,
            isCollapsed: false,
          );
        }
        
        controller.text = _dummyChar;
        controller.selection = TextSelection.collapsed(offset: _dummyChar.length);
        
        setState(() {
          _rebuildControllers();
        });
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _isUpdating = false;
          
          final newVisibleIndex = _getVisibleNotes().indexWhere((n) => n.id == currentNote.id);
          if (newVisibleIndex != -1 && newVisibleIndex < _focusNodes.length) {
            _focusNodes[newVisibleIndex].requestFocus();
          }
        });
      });
      
      previousText = currentText;
      return;
    }
    
    // ユーザーが入力していた場合 → 孫ランクにカーソル移動
    print('🔍 子（Level 2、リスト化、展開中）で改行 → 孫ランクへ');
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isUpdating) return;
      
      _isUpdating = true;
      
      // 改行を除去して元のテキストを復元
      final cleanText = textWithoutNewline;
      controller.text = cleanText;
      controller.selection = TextSelection.collapsed(offset: cleanText.length);
      _notes[realIndex] = currentNote.copyWith(text: cleanText);
      
      // この子の孫要素を取得
      final grandchildren = _notes.where((n) => 
        n.parentId == currentNote.id && n.level == 3
      ).toList();
      
      if (grandchildren.isEmpty) {
        // 孫がいない場合は新しい孫を作成
        final newGrandchild = LyricNoteItem(
          text: _dummyChar,
          level: 3,
          parentId: currentNote.id,
        );
        _notes.insert(realIndex + 1, newGrandchild);
        
        setState(() {
          _rebuildControllers();
        });
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _isUpdating = false;
          
          final newVisibleIndex = _getVisibleNotes().indexWhere((n) => n.id == newGrandchild.id);
          if (newVisibleIndex != -1 && newVisibleIndex < _focusNodes.length) {
            _focusNodes[newVisibleIndex].requestFocus();
            
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (newVisibleIndex < _controllers.length) {
                _controllers[newVisibleIndex].selection = 
                    TextSelection.collapsed(offset: _dummyChar.length);
              }
            });
          }
        });
      } else {
        // 孫がいる場合
        final firstGrandchild = grandchildren.first;
        final firstGrandchildCleanText = firstGrandchild.text.startsWith(_dummyChar)
            ? firstGrandchild.text.substring(_dummyChar.length)
            : firstGrandchild.text;
        
        if (firstGrandchildCleanText.isEmpty) {
          // 最初の孫が空の場合 → その孫にカーソル移動
          setState(() {
            _rebuildControllers();
          });
          
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _isUpdating = false;
            
            final firstGrandchildVisibleIndex = _getVisibleNotes().indexWhere((n) => n.id == firstGrandchild.id);
            if (firstGrandchildVisibleIndex != -1 && firstGrandchildVisibleIndex < _focusNodes.length) {
              _focusNodes[firstGrandchildVisibleIndex].requestFocus();
              
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (firstGrandchildVisibleIndex < _controllers.length) {
                  _controllers[firstGrandchildVisibleIndex].selection = 
                      TextSelection.collapsed(offset: _dummyChar.length);
                }
              });
            }
          });
        } else {
          // 最初の孫に入力がある場合 → 新しい孫を手前に追加
          final firstGrandchildRealIndex = _notes.indexWhere((n) => n.id == firstGrandchild.id);
          
          final newGrandchild = LyricNoteItem(
            text: _dummyChar,
            level: 3,
            parentId: currentNote.id,
          );
          _notes.insert(firstGrandchildRealIndex, newGrandchild);
          
          setState(() {
            _rebuildControllers();
          });
          
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _isUpdating = false;
            
            final newVisibleIndex = _getVisibleNotes().indexWhere((n) => n.id == newGrandchild.id);
            if (newVisibleIndex != -1 && newVisibleIndex < _focusNodes.length) {
              _focusNodes[newVisibleIndex].requestFocus();
              
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (newVisibleIndex < _controllers.length) {
                  _controllers[newVisibleIndex].selection = 
                      TextSelection.collapsed(offset: _dummyChar.length);
                }
              });
            }
          });
        }
      }
    });
    
    previousText = currentText;
    return;
  }
  
  // 🔧 既存の処理（リスト化されていない、または折りたたみ中の場合）
  print('🔍 子（Level 2、通常）で改行');
  
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted || _isUpdating) return;
    
    _isUpdating = true;
    
    // 改行を除去してカーソル位置で分割
    final textWithoutNewline = currentText.replaceAll('\n', '');
    final cursorPos = controller.selection.baseOffset;
    final actualCursorPos = cursorPos > 0 ? cursorPos - 1 : cursorPos;
    
    final beforeCursor = textWithoutNewline.substring(0, actualCursorPos.clamp(0, textWithoutNewline.length));
    final afterCursor = textWithoutNewline.substring(actualCursorPos.clamp(0, textWithoutNewline.length));
    
    // 元の行のテキストを更新
    controller.text = beforeCursor;
    controller.selection = TextSelection.collapsed(offset: beforeCursor.length);
    _notes[realIndex] = currentNote.copyWith(text: beforeCursor);
    
    // 新しい子を作成（_dummyChar + afterCursor）
    final newNote = LyricNoteItem(
      text: _dummyChar + afterCursor,
      level: 2,
      parentId: currentNote.parentId,
    );
    
    // 🆕 修正: 子の孫をスキップして挿入位置を決定
int insertPosition = realIndex + 1;
for (int i = realIndex + 1; i < _notes.length; i++) {
  final n = _notes[i];
  if (n.parentId == currentNote.id || _isDescendantOf(n, currentNote.id)) {
    insertPosition = i + 1;
  } else {
    break;
  }
}

_notes.insert(insertPosition, newNote);
    
    setState(() {
      _rebuildControllers();
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isUpdating = false;
      
      final newVisibleIndex = _getVisibleNotes().indexWhere((n) => n.id == newNote.id);
      if (newVisibleIndex != -1 && newVisibleIndex < _focusNodes.length) {
        _focusNodes[newVisibleIndex].requestFocus();
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (newVisibleIndex < _controllers.length) {
            _controllers[newVisibleIndex].selection = 
                TextSelection.collapsed(offset: _dummyChar.length);
          }
        });
      }
    });
  });
  
  previousText = currentText;
  return;
}

// 🆕 追加: 孫（Level 3）の場合
else if (currentNote.level == 3) {
  print('🔍 孫（Level 3）で改行');
  
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted || _isUpdating) return;
    
    _isUpdating = true;
    
    // 改行を除去してカーソル位置で分割
    final textWithoutNewline = currentText.replaceAll('\n', '');
    final cursorPos = controller.selection.baseOffset;
    final actualCursorPos = cursorPos > 0 ? cursorPos - 1 : cursorPos;
    
    final beforeCursor = textWithoutNewline.substring(0, actualCursorPos.clamp(0, textWithoutNewline.length));
    final afterCursor = textWithoutNewline.substring(actualCursorPos.clamp(0, textWithoutNewline.length));
    
    // 元の行のテキストを更新
    controller.text = beforeCursor;
    controller.selection = TextSelection.collapsed(offset: beforeCursor.length);
    _notes[realIndex] = currentNote.copyWith(text: beforeCursor);
    
    // 新しい孫を作成（_dummyChar + afterCursor）
    final newNote = LyricNoteItem(
      text: _dummyChar + afterCursor,
      level: 3,
      parentId: currentNote.parentId,
    );
    
    _notes.insert(realIndex + 1, newNote);
    
    setState(() {
      _rebuildControllers();
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isUpdating = false;
      
      final newVisibleIndex = _getVisibleNotes().indexWhere((n) => n.id == newNote.id);
      if (newVisibleIndex != -1 && newVisibleIndex < _focusNodes.length) {
        _focusNodes[newVisibleIndex].requestFocus();
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (newVisibleIndex < _controllers.length) {
            _controllers[newVisibleIndex].selection = 
                TextSelection.collapsed(offset: _dummyChar.length);
          }
        });
      }
    });
  });
  
  previousText = currentText;
  return;
}

// 🆕 追加: 通常メモ（Level 0）の場合
    else if (currentNote.level == 0) {
      print('🔍 通常メモ（Level 0）で改行');
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _isUpdating) return;
        
        _isUpdating = true;
        
        // 改行を除去してカーソル位置で分割
        final textWithoutNewline = currentText.replaceAll('\n', '');
        final cursorPos = controller.selection.baseOffset;
        final actualCursorPos = cursorPos > 0 ? cursorPos - 1 : cursorPos; // 改行分を考慮
        
        final beforeCursor = textWithoutNewline.substring(0, actualCursorPos.clamp(0, textWithoutNewline.length));
        final afterCursor = textWithoutNewline.substring(actualCursorPos.clamp(0, textWithoutNewline.length));
        
        // 元の行のテキストを更新
        controller.text = beforeCursor;
        controller.selection = TextSelection.collapsed(offset: beforeCursor.length);
        _notes[realIndex] = currentNote.copyWith(text: beforeCursor);
        
        // 新しい行を作成（_dummyChar + afterCursor）
        final newNote = LyricNoteItem(
          text: _dummyChar + afterCursor,
          level: 0,
          parentId: null,
        );
        
        _notes.insert(realIndex + 1, newNote);
        
        setState(() {
          _rebuildControllers();
        });
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _isUpdating = false;
          
          final newVisibleIndex = _getVisibleNotes().indexWhere((n) => n.id == newNote.id);
          if (newVisibleIndex != -1 && newVisibleIndex < _focusNodes.length) {
            _focusNodes[newVisibleIndex].requestFocus();
            
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (newVisibleIndex < _controllers.length) {
                _controllers[newVisibleIndex].selection = 
                    TextSelection.collapsed(offset: _dummyChar.length);
              }
            });
          }
        });
      });
      
      previousText = currentText;
      return;
    }
}
}
    
    // 🔧 修正：親（Level 1）で折りたたみ中、テキストが完全に空になった瞬間を検知
// （ダミー文字のみの場合は変換しない）
final realIndex = _getRealIndex(index);
if (realIndex != -1) {
  final currentNote = _notes[realIndex];
  
  if (currentNote.level == 1 && currentNote.isCollapsed && 
      currentText.isEmpty && previousTextClean.isNotEmpty) {
    print('🔍 親（Level 1、折りたたみ中）が空になった → Level 0に変換');
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _isUpdating) return;
          
          _isUpdating = true;
          
          // 子孫を削除
          final nodesToDelete = <String>[];
          _collectDescendants(currentNote.id, nodesToDelete);
          
          if (nodesToDelete.isNotEmpty) {
            print('🔍 削除する子孫: ${nodesToDelete.length}個');
            _notes.removeWhere((note) => nodesToDelete.contains(note.id));
          }
          
          // Level 0 に変換
          final noteRealIndex = _notes.indexWhere((n) => n.id == currentNote.id);
          if (noteRealIndex != -1) {
            _notes[noteRealIndex] = _notes[noteRealIndex].copyWith(
              level: 0,
              parentId: null,
              isCollapsed: false,
            );
          }
          
          setState(() {
            _rebuildControllers();
          });
          
          WidgetsBinding.instance.addPostFrameCallback((_) {
  _isUpdating = false;
  if (index < _focusNodes.length) {
    _focusNodes[index].requestFocus();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (index < _controllers.length) {
        // 🆕 修正: カーソルを _dummyChar の後ろに設定
        _controllers[index].selection = 
            TextSelection.collapsed(offset: _dummyChar.length);
      }
    });
  }
});
        });
        
        previousText = currentText;
        return;
      }
    }
    
    // 🔧 修正：デリート検知（既存のコード）
    final isDeleting = currentText.length < previousText.length;

// 🔧 追加：親（Level 1）で折りたたみ中、デリートが押された瞬間（previousText に関わらず）
if (realIndex != -1) {
  final currentNote = _notes[realIndex];
  
  if (currentNote.level == 1 && currentNote.isCollapsed && currentText.isEmpty && isDeleting) {
  print('🔍 親（Level 1、折りたたみ中）でデリート検知（改行直後対応）');
    
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted || _isUpdating) return;
    
    _isUpdating = true;
    
    // 子孫を削除
    final nodesToDelete = <String>[];
    _collectDescendants(currentNote.id, nodesToDelete);
    
    if (nodesToDelete.isNotEmpty) {
      print('🔍 削除する子孫: ${nodesToDelete.length}個');
      _notes.removeWhere((note) => nodesToDelete.contains(note.id));
    }
    
    // Level 0 に変換（テキストを _dummyChar に設定）
    final noteRealIndex = _notes.indexWhere((n) => n.id == currentNote.id);
    if (noteRealIndex != -1) {
      _notes[noteRealIndex] = _notes[noteRealIndex].copyWith(
        text: _dummyChar,  // 🆕 修正: '' → _dummyChar
        level: 0,
        parentId: null,
        isCollapsed: false,
      );
    }
    
    setState(() {
      _rebuildControllers();
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isUpdating = false;
      
      // 🆕 修正: 変換後のvisibleIndexを再取得
      final newVisibleIndex = _getVisibleNotes().indexWhere((n) => n.id == currentNote.id);
      
      if (newVisibleIndex != -1 && newVisibleIndex < _focusNodes.length) {
        _focusNodes[newVisibleIndex].requestFocus();
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (newVisibleIndex < _controllers.length) {
            // 🆕 修正: カーソルを _dummyChar の後ろに設定
            _controllers[newVisibleIndex].selection = 
                TextSelection.collapsed(offset: _dummyChar.length);
          }
        });
      }
    });
  });
  
  previousText = currentText;
  return;
}
}
    
    // 🔧 修正：デリート検知（_dummyChar が消えた = 行削除）
if ((currentTextClean.isEmpty && previousTextClean.isEmpty && isDeleting) ||
    (currentText.isEmpty && previousText == _dummyChar)) {
  print('🐛 デリート検知（行削除）: index=$index');

  final realIndex = _getRealIndex(index);
  if (realIndex != -1) {
    final currentNote = _notes[realIndex];
    
    print('🔍 空行でデリート検知: visibleIndex=$index, level=${currentNote.level}');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isUpdating) return;
      
      // 最初の行の場合は削除しない、_dummyChar を復元
      if (index == 0) {
        controller.text = _dummyChar;
        controller.selection = TextSelection.collapsed(offset: _dummyChar.length);
        previousText = _dummyChar;
        return;
      }

      // 🆕 修正: 子（Level 2）で空の場合
if (currentNote.level == 2 && currentNote.parentId != null) {
  // この親の子要素を取得
  final siblings = _notes.where((n) => 
    n.parentId == currentNote.parentId && n.level == 2
  ).toList();
  
  // この行が最初の子かどうかをチェック
  final isFirstChild = siblings.isNotEmpty && siblings.first.id == currentNote.id;
  
  if (isFirstChild) {
    // 最初の子の場合 → 親にカーソル移動のみ（削除しない）
    final parentVisibleIndex = _getVisibleNotes().indexWhere((n) => n.id == currentNote.parentId);
    
    if (parentVisibleIndex != -1 && parentVisibleIndex < _focusNodes.length) {
      print('🔍 子（Level 2、最初の子）で空 → 親にカーソル移動のみ（削除しない）');
      
      // _dummyChar を復元
      controller.text = _dummyChar;
      controller.selection = TextSelection.collapsed(offset: _dummyChar.length);
      previousText = _dummyChar;
      
      // 親にフォーカス移動
      _focusNodes[parentVisibleIndex].requestFocus();
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (parentVisibleIndex < _controllers.length) {
          final parentLength = _controllers[parentVisibleIndex].text.length;
          _controllers[parentVisibleIndex].selection = 
              TextSelection.collapsed(offset: parentLength);
        }
      });
      
      return;
    }
  } else {
    // 2行目以降の子の場合 → 前の子にカーソル移動して、この行を削除
    print('🔍 子（Level 2、2行目以降）で空 → 前の子にカーソル移動して削除');
    
    final prevLength = index - 1 < _controllers.length 
        ? _controllers[index - 1].text.length 
        : 0;
    
    _handleBackspace(index);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (index - 1 >= 0 && index - 1 < _controllers.length) {
        _controllers[index - 1].selection = 
            TextSelection.collapsed(offset: prevLength);
      }
    });
    
    return;
  }
}
      
      // 🆕 修正: 孫（Level 3）で空の場合
if (currentNote.level == 3 && currentNote.parentId != null) {
  // この親の孫要素を取得
  final siblings = _notes.where((n) => 
    n.parentId == currentNote.parentId && n.level == 3
  ).toList();
  
  // この行が最初の孫かどうかをチェック
  final isFirstChild = siblings.isNotEmpty && siblings.first.id == currentNote.id;
  
  if (isFirstChild) {
    // 最初の孫の場合 → 親（Level 2）にカーソル移動のみ（削除しない）
    final parentVisibleIndex = _getVisibleNotes().indexWhere((n) => n.id == currentNote.parentId);
    
    if (parentVisibleIndex != -1 && parentVisibleIndex < _focusNodes.length) {
      print('🔍 孫（Level 3、最初の孫）で空 → 親にカーソル移動のみ（削除しない）');
      
      // _dummyChar を復元
      controller.text = _dummyChar;
      controller.selection = TextSelection.collapsed(offset: _dummyChar.length);
      previousText = _dummyChar;
      
      // 親にフォーカス移動
      _focusNodes[parentVisibleIndex].requestFocus();
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (parentVisibleIndex < _controllers.length) {
          final parentLength = _controllers[parentVisibleIndex].text.length;
          _controllers[parentVisibleIndex].selection = 
              TextSelection.collapsed(offset: parentLength);
        }
      });
      
      return;
    }
  } else {
    // 2行目以降の孫の場合 → 前の孫にカーソル移動して、この行を削除
    print('🔍 孫（Level 3、2行目以降）で空 → 前の孫にカーソル移動して削除');
    
    final prevLength = index - 1 < _controllers.length 
        ? _controllers[index - 1].text.length 
        : 0;
    
    _handleBackspace(index);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (index - 1 >= 0 && index - 1 < _controllers.length) {
        _controllers[index - 1].selection = 
            TextSelection.collapsed(offset: prevLength);
      }
    });
    
    return;
  }
}
      
      // 2行目以降は前の行に戻る
      final prevLength = index - 1 < _controllers.length 
          ? _controllers[index - 1].text.length 
          : 0;
      
      _handleBackspace(index);
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (index - 1 >= 0 && index - 1 < _controllers.length) {
          _controllers[index - 1].selection = 
              TextSelection.collapsed(offset: prevLength);
        }
      });
    });
    
    previousText = currentText;
    return;
  }

  if (realIndex != -1) {
    final currentNote = _notes[realIndex];
    
    print('🔍 空行でデリート検知: visibleIndex=$index, level=${currentNote.level}, isCollapsed=${currentNote.isCollapsed}');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isUpdating) return;
      
      if (index == 0 && currentNote.level == 1) {
        print('🔍 最初の親（Level 1）→ 子孫を削除してLevel 0に変換');
        _isUpdating = true;
        
        final nodesToDelete = <String>[];
        _collectDescendants(currentNote.id, nodesToDelete);
        
        if (nodesToDelete.isNotEmpty) {
          print('🔍 削除する子孫: ${nodesToDelete.length}個');
          _notes.removeWhere((note) => nodesToDelete.contains(note.id));
        }
        
        final updatedRealIndex = _notes.indexWhere((n) => n.id == currentNote.id);
        if (updatedRealIndex != -1) {
          _notes[updatedRealIndex] = _notes[updatedRealIndex].copyWith(
            level: 0,
            parentId: null,
            isCollapsed: false,
          );
        }
        
        setState(() {
          _rebuildControllers();
        });
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
  _isUpdating = false;
  if (index < _focusNodes.length) {
    _focusNodes[index].requestFocus();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (index < _controllers.length) {
        // 🆕 修正: カーソルを _dummyChar の後ろに設定
        _controllers[index].selection = 
            TextSelection.collapsed(offset: _dummyChar.length);
      }
    });
  }
});
        
        previousText = currentText;
        return;
      }
      
      // 🔧 追加：親（Level 1）で折りたたみ中かつ空の場合 → Level 0 に変換
      if (currentNote.level == 1 && currentNote.isCollapsed) {
        print('🔍 親（Level 1、折りたたみ中、空）でデリート → Level 0に変換');
        
        _isUpdating = true;
        
        // 子孫を削除
        final nodesToDelete = <String>[];
        _collectDescendants(currentNote.id, nodesToDelete);
        
        if (nodesToDelete.isNotEmpty) {
          print('🔍 削除する子孫: ${nodesToDelete.length}個');
          _notes.removeWhere((note) => nodesToDelete.contains(note.id));
        }
        
        // Level 0 に変換
        final noteRealIndex = _notes.indexWhere((n) => n.id == currentNote.id);
        if (noteRealIndex != -1) {
          _notes[noteRealIndex] = _notes[noteRealIndex].copyWith(
            level: 0,
            parentId: null,
            isCollapsed: false,
          );
        }
        
        setState(() {
          _rebuildControllers();
        });
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
  _isUpdating = false;
  if (index < _focusNodes.length) {
    _focusNodes[index].requestFocus();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (index < _controllers.length) {
        // 🆕 修正: カーソルを _dummyChar の後ろに設定
        _controllers[index].selection = 
            TextSelection.collapsed(offset: _dummyChar.length);
      }
    });
  }
});
        
        previousText = currentText;
        return;
      }
      
      if (currentNote.level == 1 && index > 0) {
        print('🔍 親（Level 1）で空 → 削除');
        
        final prevLength = index - 1 < _controllers.length 
            ? _controllers[index - 1].text.length 
            : 0;
        
        _handleBackspace(index);
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (index - 1 >= 0 && index - 1 < _controllers.length) {
            _controllers[index - 1].selection = 
                TextSelection.collapsed(offset: prevLength);
          }
        });
        
        previousText = currentText;
        return;
      }
      
      if (currentNote.level == 2 && currentNote.isCollapsed && index > 0) {
        print('🔍 子（Level 2、リスト化）で空 → 通常の子に変換');
        _isUpdating = true;
        
        final noteRealIndex = _notes.indexWhere((n) => n.id == currentNote.id);
        if (noteRealIndex != -1) {
          _notes[noteRealIndex] = _notes[noteRealIndex].copyWith(isCollapsed: false);
        }
        
        setState(() {
          _rebuildControllers();
        });
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
  _isUpdating = false;
  if (index < _focusNodes.length) {
    _focusNodes[index].requestFocus();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (index < _controllers.length) {
        // 🆕 修正: カーソルを _dummyChar の後ろに設定
        _controllers[index].selection = 
            TextSelection.collapsed(offset: _dummyChar.length);
      }
    });
  }
});
        
        previousText = currentText;
        return;
      }
      
      if (index > 0) {
        print('🔍 _handleBackspace呼び出し（スマホ）: visibleIndex=$index');
        
        final prevLength = index - 1 < _controllers.length 
            ? _controllers[index - 1].text.length 
            : 0;
        
        _handleBackspace(index);
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (index - 1 >= 0 && index - 1 < _controllers.length) {
            _controllers[index - 1].selection = 
                TextSelection.collapsed(offset: prevLength);
          }
        });
        
        return;
      }
    });
    
    previousText = currentText;
    return;
  }
}
    
    previousText = currentText;
    
    if (realIndex == -1) return;
    
    _notes[realIndex] = _notes[realIndex].copyWith(
      text: currentTextClean,
      updatedAt: DateTime.now(),
    );
    
    if (realIndex == _notes.length - 1 && currentTextClean.isNotEmpty && !hasAddedNewLine) {
      hasAddedNewLine = true;
      _notes.add(LyricNoteItem(text: _dummyChar, level: 0, parentId: null));
      print('✅ 新しい空行を追加（リビルドなし）: 合計${_notes.length}行');
    }
    
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        _saveNotes();
      }
    });
  }
});
}

/// フォーカスされた行がキーボードに隠れないようにスクロール
void _scrollToFocusedLine(int index) {
  if (!mounted || index >= _controllers.length) return;
  
  // 少し遅延させて、キーボードが表示された後に実行
  Future.delayed(const Duration(milliseconds: 300), () {
    if (!mounted) return;
    
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    
    if (keyboardHeight == 0) return;
    
    // 🔧 修正：RenderBox を使って実際の行の位置を取得
    try {
      final renderObject = context.findRenderObject();
      if (renderObject == null) return;
      
      // 画面の高さとキーボードを考慮した表示可能領域
      final screenHeight = MediaQuery.of(context).size.height;
      final safeBottom = screenHeight - keyboardHeight - 150; // 150px の余裕
      
      // 各行の高さを積算して目標行の位置を推定
      double targetPosition = 0;
      for (int i = 0; i < index; i++) {
        if (i < _controllers.length) {
          final lineText = _controllers[i].text;
          final lineCount = (lineText.split('\n').length).toDouble();
          targetPosition += (16 * 1.3 * lineCount) + 2; // 行の高さ + padding
        }
      }
      
      // 現在のスクロール位置からの相対位置
      final linePositionOnScreen = targetPosition - _scrollController.offset + 100; // ヘッダー分
      
      if (linePositionOnScreen > safeBottom) {
        // スクロールして表示
        final targetScroll = targetPosition - safeBottom + 100;
        
        _scrollController.animateTo(
          targetScroll.clamp(0.0, _scrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      print('スクロール調整エラー: $e');
    }
  });
}

  /// ノートを保存
void _saveNotes() {
  final notesToSave = <LyricNoteItem>[];
  
  for (int i = 0; i < _notes.length; i++) {
    final note = _notes[i];
    
    // 🆕 修正: _dummyChar を除去したテキスト
    final cleanText = note.text.startsWith(_dummyChar) 
        ? note.text.substring(_dummyChar.length) 
        : note.text;
    
    // 最後の行で、かつ空の場合はスキップ
    if (i == _notes.length - 1 && cleanText.trim().isEmpty) {
      continue;
    }
    
    // 🆕 修正: クリーンなテキストで保存
    notesToSave.add(note.copyWith(text: cleanText));
  }
  
  if (notesToSave.isEmpty) {
    print('💾 保存実行: 空リスト（全削除済み）');
  } else {
    print('💾 保存実行: ${notesToSave.length}行');
    for (var note in notesToSave) {
      print('  ${note.toString()}');
    }
  }
  
  widget.onSave(notesToSave);
}

  /// LISTボタンの処理
void _makeList() {
  int focusedVisibleIndex = -1;
  for (int i = 0; i < _focusNodes.length; i++) {
    if (_focusNodes[i].hasFocus) {
      focusedVisibleIndex = i;
      break;
    }
  }
  
  if (focusedVisibleIndex == -1) return;
  
  final realIndex = _getRealIndex(focusedVisibleIndex);
  if (realIndex == -1) return;
  
  final currentNote = _notes[realIndex];
  
  // Level 0 → Level 1（親）に変換
  if (currentNote.level == 0) {
    setState(() {
      // 🆕 修正: テキストはそのまま（既に _dummyChar が入っている）
      _notes[realIndex] = currentNote.copyWith(
        level: 1,
        isCollapsed: true,
        parentId: null,
      );
      _rebuildControllers();
    });
    _saveNotes();
  }
  else if (currentNote.level == 2) {
    setState(() {
      _notes[realIndex] = currentNote.copyWith(
        isCollapsed: true,
      );
      _rebuildControllers();
    });
    _saveNotes();
  }
}

/// 改行が押された時
void _onSubmitted(int visibleIndex) {
  final realIndex = _getRealIndex(visibleIndex);
  if (realIndex == -1) return;
  
  final currentNote = _notes[realIndex];
  
  // 🔧 追加：カーソル位置を取得
  final controller = _controllers[visibleIndex];
  final cursorPosition = controller.selection.baseOffset;
  final currentText = controller.text;
  
  // 🔧 追加：カーソル位置で文字列を分割
  final beforeCursor = cursorPosition >= 0 ? currentText.substring(0, cursorPosition) : currentText;
  final afterCursor = cursorPosition >= 0 && cursorPosition < currentText.length 
      ? currentText.substring(cursorPosition) 
      : '';
  
  // 🔧 追加：現在の行のテキストを「カーソルより前」に更新
  if (afterCursor.isNotEmpty) {
    _isUpdating = true;
    _notes[realIndex] = currentNote.copyWith(
      text: beforeCursor,
      updatedAt: DateTime.now(),
    );
    controller.text = beforeCursor;
    controller.selection = TextSelection.collapsed(offset: beforeCursor.length);
  }
  
  // 親（Level 1）で空（またはダミー文字のみ）の場合 → 通常ノート（Level 0）に戻る
if (currentNote.level == 1 && (beforeCursor.isEmpty || beforeCursor == _dummyChar)) {
  _isUpdating = true;
  
  // 子孫を削除
  final nodesToDelete = <String>[];
  _collectDescendants(currentNote.id, nodesToDelete);
  
  if (nodesToDelete.isNotEmpty) {
    _notes.removeWhere((note) => nodesToDelete.contains(note.id));
  }
  
  // Level 0 に変換（テキストを空にする）
  final noteRealIndex = _notes.indexWhere((n) => n.id == currentNote.id);
  if (noteRealIndex != -1) {
    _notes[noteRealIndex] = _notes[noteRealIndex].copyWith(
      text: '',
      level: 0,
      parentId: null,
      isCollapsed: false,
    );
  }
  
  setState(() {
    _rebuildControllers();
  });
  
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _isUpdating = false;
    
    // 現在の行にフォーカスを戻す
    final newVisibleIndex = _getVisibleNotes().indexWhere((n) => n.id == currentNote.id);
    if (newVisibleIndex != -1 && newVisibleIndex < _focusNodes.length) {
      _focusNodes[newVisibleIndex].requestFocus();
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (newVisibleIndex < _controllers.length) {
          _controllers[newVisibleIndex].selection = 
              const TextSelection.collapsed(offset: 0);
        }
      });
    }
  });
  return;
}
  
  // 🆕 追加：子（Level 2）で空の場合 → 通常の子（Level 2）に戻る
  if (currentNote.level == 2 && beforeCursor.isEmpty && currentNote.isCollapsed) { // 🔧 修正
    _isUpdating = true;
    
    _notes[realIndex] = currentNote.copyWith(isCollapsed: false);
    
    setState(() {
      _rebuildControllers();
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isUpdating = false;
      if (visibleIndex < _focusNodes.length) {
        _focusNodes[visibleIndex].requestFocus();
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (visibleIndex < _controllers.length) {
            _controllers[visibleIndex].selection = 
                const TextSelection.collapsed(offset: 0);
          }
        });
      }
    });
    return;
  }
  
  // 親（Level 1）で展開中（isCollapsed == false）の場合
  if (currentNote.level == 1 && !currentNote.isCollapsed) {
    final children = _notes.where((n) => 
      n.parentId == currentNote.id && n.level >= 2
    ).toList();
    
    if (children.isEmpty) {
      _isUpdating = true;
      
      _notes.insert(realIndex + 1, LyricNoteItem(
  text: _dummyChar + afterCursor,
  level: 2,
  parentId: currentNote.id,
));
      
      setState(() {
        _rebuildControllers();
      });
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _isUpdating = false;
        if (visibleIndex + 1 < _focusNodes.length) {
          _focusNodes[visibleIndex + 1].requestFocus();
          // 🔧 追加：新しい行の先頭にカーソルを移動
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (visibleIndex + 1 < _controllers.length) {
        _controllers[visibleIndex + 1].selection = 
            const TextSelection.collapsed(offset: 0);
      }
    });
        }
      });
      return;
    } else {
      final firstChild = children.first;
      
      if (firstChild.text.isEmpty) {
        final firstChildVisibleIndex = _getVisibleNotes().indexWhere((n) => n.id == firstChild.id);
        
        if (firstChildVisibleIndex != -1 && firstChildVisibleIndex < _focusNodes.length) {
          _focusNodes[firstChildVisibleIndex].requestFocus();
          
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (firstChildVisibleIndex < _controllers.length) {
              _controllers[firstChildVisibleIndex].selection = 
                  const TextSelection.collapsed(offset: 0);
            }
          });
        }
        return;
      } else {
        _isUpdating = true;
        
        final firstChildRealIndex = _notes.indexWhere((n) => n.id == firstChild.id);
        
        _notes.insert(firstChildRealIndex, LyricNoteItem(
          text: afterCursor, // 🔧 修正
          level: 2,
          parentId: currentNote.id,
        ));
        
        setState(() {
          _rebuildControllers();
        });
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _isUpdating = false;
          if (visibleIndex + 1 < _focusNodes.length) {
            _focusNodes[visibleIndex + 1].requestFocus();
            WidgetsBinding.instance.addPostFrameCallback((_) {
      if (visibleIndex + 1 < _controllers.length) {
        _controllers[visibleIndex + 1].selection = 
            const TextSelection.collapsed(offset: 0);
      }
    });
          }
        });
        return;
      }
    }
  }

  // 🆕 追加：親（Level 1）で折りたたみ中（isCollapsed == true）の場合
if (currentNote.level == 1 && currentNote.isCollapsed) {
  print('🔍 親（Level 1、折りたたみ中）でEnter: text="${beforeCursor}", afterCursor="${afterCursor}"');
  
  _isUpdating = true;
  
  int insertPosition = realIndex + 1;
  
  print('🔍 挿入位置: realIndex=$realIndex, insertPosition=$insertPosition');
  
  _notes.insert(insertPosition, LyricNoteItem(
    text: _dummyChar, // 🔧 修正：afterCursor → _dummyChar（PCキーボードの場合も同じ）
    level: 1,
    parentId: null,
    isCollapsed: true,
  ));
  
  
  print('🔍 新しい親を挿入: level=1, isCollapsed=true, text="$afterCursor"');
  print('🔍 挿入後の_notes.length: ${_notes.length}');
  
  setState(() {
    _rebuildControllers();
  });
  
  print('🔍 リビルド完了、_controllers.length: ${_controllers.length}');
  
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _isUpdating = false;
    print('🔍 visibleIndex + 1 = ${visibleIndex + 1}, _focusNodes.length = ${_focusNodes.length}');
    
    if (visibleIndex + 1 < _focusNodes.length) {
      _focusNodes[visibleIndex + 1].requestFocus();
      print('🔍 フォーカス移動: visibleIndex + 1 = ${visibleIndex + 1}');
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (visibleIndex + 1 < _controllers.length) {
          _controllers[visibleIndex + 1].selection = 
              const TextSelection.collapsed(offset: 0);
          print('🔍 カーソルを先頭に設定');
        }
      });
    }
  });
  return;
}

  // 🆕 追加：子（Level 2）でリスト化されていて、展開中でない場合
  if (currentNote.level == 2 && currentNote.isCollapsed == true) {
    _isUpdating = true;
    
    int insertPosition = realIndex + 1;
    for (int i = realIndex + 1; i < _notes.length; i++) {
      final note = _notes[i];
      if (note.level <= 2) break;
      if (note.parentId == currentNote.id) {
        insertPosition = i + 1;
      }
    }
    
    _notes.insert(insertPosition, LyricNoteItem(
      text: afterCursor, // 🔧 修正
      level: 2,
      parentId: currentNote.parentId,
      isCollapsed: true,
    ));
    
    setState(() {
      _rebuildControllers();
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isUpdating = false;
      if (visibleIndex + 1 < _focusNodes.length) {
        _focusNodes[visibleIndex + 1].requestFocus();
        // 🔧 追加
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (visibleIndex + 1 < _controllers.length) {
        _controllers[visibleIndex + 1].selection = 
            const TextSelection.collapsed(offset: 0);
      }
    });
      }
    });
    return;
  }
  
  // 🔧 修正：子（Level 2）でリスト化されていて展開中（isCollapsed == false）の場合
  final hasGrandchildren = _notes.any((n) => n.parentId == currentNote.id && n.level == 3);
  final isLevel2Listified = currentNote.level == 2 && (hasGrandchildren || currentNote.isCollapsed == true);

  if (isLevel2Listified && currentNote.isCollapsed == false) {
    final children = _notes.where((n) => 
      n.parentId == currentNote.id && n.level >= 3
    ).toList();
    
    if (children.isEmpty) {
      _isUpdating = true;
      
      _notes.insert(realIndex + 1, LyricNoteItem(
  text: _dummyChar + afterCursor,
  level: 3,
  parentId: currentNote.id,
));
      
      setState(() {
        _rebuildControllers();
      });
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _isUpdating = false;
        if (visibleIndex + 1 < _focusNodes.length) {
          _focusNodes[visibleIndex + 1].requestFocus();
          // 🔧 追加
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (visibleIndex + 1 < _controllers.length) {
        _controllers[visibleIndex + 1].selection = 
            const TextSelection.collapsed(offset: 0);
      }
    });
        }
      });
      return;
    } else {
      final firstChild = children.first;
      
      if (firstChild.text.isEmpty) {
        final firstChildVisibleIndex = _getVisibleNotes().indexWhere((n) => n.id == firstChild.id);
        
        if (firstChildVisibleIndex != -1 && firstChildVisibleIndex < _focusNodes.length) {
          _focusNodes[firstChildVisibleIndex].requestFocus();
          
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (firstChildVisibleIndex < _controllers.length) {
              _controllers[firstChildVisibleIndex].selection = 
                  const TextSelection.collapsed(offset: 0);
            }
          });
        }
        return;
      } else {
        _isUpdating = true;
        
        final firstChildRealIndex = _notes.indexWhere((n) => n.id == firstChild.id);
        
        _notes.insert(firstChildRealIndex, LyricNoteItem(
          text: afterCursor, // 🔧 修正
          level: 3,
          parentId: currentNote.id,
        ));
        
        setState(() {
          _rebuildControllers();
        });
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _isUpdating = false;
          if (visibleIndex + 1 < _focusNodes.length) {
            _focusNodes[visibleIndex + 1].requestFocus();
            // 🔧 追加
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (visibleIndex + 1 < _controllers.length) {
        _controllers[visibleIndex + 1].selection = 
            const TextSelection.collapsed(offset: 0);
      }
    });
          }
        });
        return;
      }
    }
  }
  
  _isUpdating = true;
  
  // 🔧 修正：新しい行のlevelとparentIdを決定
  int newLevel;
  String? newParentId;
  bool? newIsCollapsed;
  
  if (currentNote.level == 0) {
    newLevel = 0;
    newParentId = null;
    newIsCollapsed = null;
  } else if (currentNote.level == 1) {
    newLevel = 1;
    newParentId = null;
    newIsCollapsed = true;
  } else if (currentNote.level == 2) {
    if (currentNote.isCollapsed == true) {
      newLevel = 2;
      newParentId = currentNote.parentId;
      newIsCollapsed = true;
    } else {
      newLevel = 2;
      newParentId = currentNote.parentId;
      newIsCollapsed = null;
    }
  } else if (currentNote.level == 3) {
    newLevel = 3;
    newParentId = currentNote.parentId;
    newIsCollapsed = null;
  } else {
    newLevel = currentNote.level;
    newParentId = currentNote.parentId;
    newIsCollapsed = null;
  }
  
  int insertPosition = realIndex + 1;
  
  if (currentNote.level == 1) {
    for (int i = realIndex + 1; i < _notes.length; i++) {
      final note = _notes[i];
      
      if (note.level <= 1) {
        break;
      }
      
      if (note.parentId == currentNote.id) {
        insertPosition = i + 1;
      }
    }
  }
  
  if (currentNote.level == 2 && currentNote.isCollapsed == true) {
    for (int i = realIndex + 1; i < _notes.length; i++) {
      final note = _notes[i];
      
      if (note.level <= 2) {
        break;
      }
      
      if (note.parentId == currentNote.id) {
        insertPosition = i + 1;
      }
    }
  }
  
  final newNote = newIsCollapsed != null
    ? LyricNoteItem(
        text: _dummyChar + afterCursor,
        level: newLevel,
        parentId: newParentId,
        isCollapsed: newIsCollapsed,
      )
    : LyricNoteItem(
        text: _dummyChar + afterCursor,
        level: newLevel,
        parentId: newParentId,
      );
  
  _notes.insert(insertPosition, newNote);
  
  setState(() {
    _rebuildControllers();
  });
  
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _isUpdating = false;
    if (visibleIndex + 1 < _focusNodes.length) {
      _focusNodes[visibleIndex + 1].requestFocus();
      // 🔧 追加
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (visibleIndex + 1 < _controllers.length) {
        _controllers[visibleIndex + 1].selection = 
            const TextSelection.collapsed(offset: 0);
      }
    });
    }
  });
}

  /// Backspaceで前の行に戻る
void _handleBackspace(int visibleIndex) {
  final realIndex = _getRealIndex(visibleIndex);
  if (realIndex == -1) return;
  
  final currentText = _controllers[visibleIndex].text;
  
  // テキストが空の場合
  if (currentText.isEmpty) {
    
    // 最初の行の場合
    if (visibleIndex == 0) {
      final currentNote = _notes[realIndex];
      if (currentNote.level == 1) {
        setState(() {
          _notes[realIndex] = currentNote.copyWith(level: 0, parentId: null);
          _rebuildControllers();
        });
      }
      return;
    }

    // 🆕 修正: 子（Level 2）で空の場合
final currentNote = _notes[realIndex];
if (currentNote.level == 2 && currentNote.parentId != null) {
  // この親の子要素を取得
  final siblings = _notes.where((n) => 
    n.parentId == currentNote.parentId && n.level == 2
  ).toList();
  
  // この行が最初の子かどうかをチェック
  final isFirstChild = siblings.isNotEmpty && siblings.first.id == currentNote.id;
  
  if (isFirstChild) {
    // 最初の子の場合 → 親にカーソル移動のみ（削除しない）
    final parentVisibleIndex = _getVisibleNotes().indexWhere((n) => n.id == currentNote.parentId);
    
    if (parentVisibleIndex != -1 && parentVisibleIndex < _focusNodes.length) {
      print('🔍 子（Level 2、最初の子）で空 → 親にカーソル移動のみ（削除しない）');
      
      // 親にフォーカス移動
      _focusNodes[parentVisibleIndex].requestFocus();
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (parentVisibleIndex < _controllers.length) {
          final parentLength = _controllers[parentVisibleIndex].text.length;
          _controllers[parentVisibleIndex].selection = 
              TextSelection.collapsed(offset: parentLength);
        }
      });
      
      return;
    }
  }
  // 2行目以降の子の場合は、下の既存の削除処理に進む
}
    
    // 🆕 修正: 孫（Level 3）で空の場合
if (currentNote.level == 3 && currentNote.parentId != null) {
  // この親の孫要素を取得
  final siblings = _notes.where((n) => 
    n.parentId == currentNote.parentId && n.level == 3
  ).toList();
  
  // この行が最初の孫かどうかをチェック
  final isFirstChild = siblings.isNotEmpty && siblings.first.id == currentNote.id;
  
  if (isFirstChild) {
    // 最初の孫の場合 → 親（Level 2）にカーソル移動のみ（削除しない）
    final parentVisibleIndex = _getVisibleNotes().indexWhere((n) => n.id == currentNote.parentId);
    
    if (parentVisibleIndex != -1 && parentVisibleIndex < _focusNodes.length) {
      print('🔍 孫（Level 3、最初の孫）で空 → 親にカーソル移動のみ（削除しない）');
      
      // 親にフォーカス移動
      _focusNodes[parentVisibleIndex].requestFocus();
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (parentVisibleIndex < _controllers.length) {
          final parentLength = _controllers[parentVisibleIndex].text.length;
          _controllers[parentVisibleIndex].selection = 
              TextSelection.collapsed(offset: parentLength);
        }
      });
      
      return;
    }
  }
  // 2行目以降の孫の場合は、下の既存の削除処理に進む
}
    
    // 2行目以降は前の行に戻る
    _isUpdating = true;
    
    // 🔧 修正：前の行のコントローラーとテキスト長を先に取得
    final prevController = _controllers[visibleIndex - 1];
    final prevLength = prevController.text.length;
    
    
    print('🔍 削除開始: level=${currentNote.level}, id=${currentNote.id}, text="${currentNote.text}"');
    
    // 削除対象のノートIDリストを作成
    final nodesToDelete = <String>[currentNote.id];
    
    // Level 1（親）の場合、常に子孫も削除対象に追加
    if (currentNote.level == 1) {
      print('🔍 親（Level 1）を削除 → 子孫を収集');
      _collectDescendants(currentNote.id, nodesToDelete);
      print('🔍 収集完了: ${nodesToDelete.length}個のノート（親含む）');
    } 
    // Level 2（子）の場合
    else if (currentNote.level == 2) {
      // 孫がいるか、またはisCollapsedがtrueならリスト化されている
      final hasGrandchildren = _notes.any((n) => n.parentId == currentNote.id && n.level == 3);
      if (hasGrandchildren || currentNote.isCollapsed == true) {
        print('🔍 子（Level 2、リスト化）を削除 → 孫を収集');
        _collectDescendants(currentNote.id, nodesToDelete);
        print('🔍 収集完了: ${nodesToDelete.length}個のノート（子含む）');
      }
    }
    
    // デバッグ：削除前の全ノートを表示
    print('🔍 削除前の全ノート: ${_notes.length}個');
    for (var note in _notes) {
      print('  - id=${note.id}, level=${note.level}, parentId=${note.parentId}, text="${note.text}"');
    }
    
    // 削除対象を表示
    print('🔍 削除対象ID: $nodesToDelete');
    
    // 子要素（Level 2以上）を削除する場合の親の折りたたみ状態チェック
    if (currentNote.level >= 2 && currentNote.parentId != null) {
      // この親の他の子要素があるかチェック（削除対象を除く）
      final otherChildren = _notes.where((n) => 
        n.parentId == currentNote.parentId && 
        n.level == currentNote.level &&
        !nodesToDelete.contains(n.id)
      ).toList();
      
      print('🔍 削除後の兄弟: ${otherChildren.length}個');
    }
    
    // 削除対象のノートを全て削除
    _notes.removeWhere((note) => nodesToDelete.contains(note.id));
    
    print('🗑️ 削除実行完了: ${nodesToDelete.length}個のノートを削除');
    print('🔍 削除後の全ノート: ${_notes.length}個');
    for (var note in _notes) {
      print('  - id=${note.id}, level=${note.level}, parentId=${note.parentId}, text="${note.text}"');
    }
    
    setState(() {
      _rebuildControllers();
    });
    
    // 🔧 修正：削除後に前の行の最後にフォーカスとカーソル位置を設定
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isUpdating = false;
      
      if (visibleIndex - 1 >= 0 && visibleIndex - 1 < _focusNodes.length) {
        _focusNodes[visibleIndex - 1].requestFocus();
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (visibleIndex - 1 < _controllers.length) {
            _controllers[visibleIndex - 1].selection = 
                TextSelection.collapsed(offset: prevLength);
          }
        });
      }
    });
  }
}

/// 指定されたノートIDの全ての子孫を収集する（再帰的）
void _collectDescendants(String parentId, List<String> collectedIds) {
  print('🔍 _collectDescendants呼び出し: parentId=$parentId');
  
  // この親の直接の子要素を取得
  final children = _notes.where((n) => n.parentId == parentId).toList();
  
  print('🔍 見つかった子: ${children.length}個');
  
  for (final child in children) {
    print('🔍 子を追加: id=${child.id}, level=${child.level}, text="${child.text}"');
    // 子をリストに追加
    collectedIds.add(child.id);
    
    // 孫以降も再帰的に収集
    _collectDescendants(child.id, collectedIds);
  }
}

/// 指定されたノートが、指定された親の子孫かどうかを判定
bool _isDescendantOf(LyricNoteItem note, String ancestorId) {
  if (note.parentId == null) return false;
  if (note.parentId == ancestorId) return true;
  
  final parent = _notes.firstWhere(
    (n) => n.id == note.parentId,
    orElse: () => note,
  );
  
  if (parent.id == note.id) return false;
  return _isDescendantOf(parent, ancestorId);
}

  /// くの字タップで展開/折りたたみ
void _toggleCollapse(int visibleIndex) {
  final realIndex = _getRealIndex(visibleIndex);
  if (realIndex == -1) return;
  
  final note = _notes[realIndex];
  
  // 🐛 デバッグ：現在の状態を確認
  print('🔍 Toggle前: level=${note.level}, isCollapsed=${note.isCollapsed}, text="${note.text}"');
  
  // 🔧 修正：Level 1（親）または Level 2（リスト化された子）の場合のみToggle可能
  // Level 2 がリスト化されているかを判定
  final hasGrandchildren = _notes.any((n) => n.parentId == note.id && n.level == 3);
  final isLevel2Listified = note.level == 2 && (hasGrandchildren || note.isCollapsed != null);
  
  if (note.level != 1 && !isLevel2Listified) {
    print('❌ Toggle不可: level=${note.level}, リスト化されていない');
    return;
  }
  
  final isCurrentlyCollapsed = note.isCollapsed;
  
  _isUpdating = true;
  
  if (isCurrentlyCollapsed) {
    // 展開：この親/子の子要素が既に存在するかチェック
    final childLevel = note.level + 1;
    final hasChildren = _notes.any((n) => n.parentId == note.id && n.level == childLevel);
    
    // 🔧 修正：isCollapsed を false にする
    _notes[realIndex] = note.copyWith(isCollapsed: false);
    
    // 🐛 デバッグ：変更後の状態を確認
    print('🔍 Toggle後（展開）: level=${_notes[realIndex].level}, isCollapsed=${_notes[realIndex].isCollapsed}');
    
    if (!hasChildren) {
  // 子要素がない場合のみ、新しい子要素を作成
  // 🆕 修正: 親の直後に挿入
  _notes.insert(realIndex + 1, LyricNoteItem(
    text: _dummyChar,
    level: childLevel,
    parentId: note.id,
  ));
}
    
    setState(() {
      _rebuildControllers();
    });
    
    _isUpdating = false;
  } else {
    // 折りたたみ：isCollapsedをtrueに（子要素は残す）
    _notes[realIndex] = note.copyWith(isCollapsed: true);
    
    // 🐛 デバッグ：変更後の状態を確認
    print('🔍 Toggle後（折りたたみ）: level=${_notes[realIndex].level}, isCollapsed=${_notes[realIndex].isCollapsed}');
    
    setState(() {
      _rebuildControllers();
    });
    
    _isUpdating = false;
  }
  
  _saveNotes();
}

  /// プレースホルダーを取得
String _getHintText(int visibleIndex) {
  final realIndex = _getRealIndex(visibleIndex);
  if (realIndex == -1) return '';
  
  final note = _notes[realIndex];
  
  // 全てのノートが空の場合のみ、最初の行にプレースホルダーを表示
  final allNotesEmpty = _notes.every((n) => n.text.isEmpty);
  
  if (visibleIndex == 0 && note.text.isEmpty && note.level == 0 && allNotesEmpty) {
    return 'Take notes.\nYou can also create a list.';
  }
  
  // 親（Level 1）で空（またはダミー文字のみ）の場合
if ((note.text.isEmpty || note.text == _dummyChar) && note.level == 1) {
  return 'Listify';
}
  
  // 🔧 修正: Level 2（子）でリスト化されていて空の場合
  final hasGrandchildren = _notes.any((n) => n.parentId == note.id && n.level == 3);
  final isLevel2Listified = note.level == 2 && (hasGrandchildren || note.isCollapsed == true); // 🔧 修正
  
  if (note.text.isEmpty && isLevel2Listified) {
    return 'Listify';
  }
  
  // 子（Level 2）で通常の子の場合
  if (note.text.isEmpty && note.level == 2 && note.parentId != null) {
    // 親が展開中（isCollapsed == false）かチェック
    final parent = _notes.firstWhere(
      (n) => n.id == note.parentId,
      orElse: () => note,
    );
    
    // 親が展開中の場合のみプレースホルダを表示
    if (parent.isCollapsed == false) {
      // この親の子要素（Level 2）を取得
      final siblings = _notes.where((n) => 
        n.parentId == note.parentId && n.level == 2
      ).toList();
      
      // この行が、この親の最初の子かつ全ての兄弟が空の場合のみ表示
      final isFirstChild = siblings.isNotEmpty && siblings.first.id == note.id;
      final allSiblingsEmpty = siblings.every((n) => n.text.isEmpty);
      
      if (isFirstChild && allSiblingsEmpty) {
        return 'Empty list.';
      }
    }
  }
  
  // 孫（Level 3）の場合
  if (note.text.isEmpty && note.level == 3 && note.parentId != null) {
    // 親（Level 2）が展開中（isCollapsed == false）かチェック
    final parent = _notes.firstWhere(
      (n) => n.id == note.parentId,
      orElse: () => note,
    );
    
    // 親が展開中の場合のみプレースホルダを表示
    if (parent.isCollapsed == false) {
      // この親の孫要素（Level 3）を取得
      final siblings = _notes.where((n) => 
        n.parentId == note.parentId && n.level == 3
      ).toList();
      
      // この行が、この親の最初の孫かつ全ての兄弟が空の場合のみ表示
      final isFirstChild = siblings.isNotEmpty && siblings.first.id == note.id;
      final allSiblingsEmpty = siblings.every((n) => n.text.isEmpty);
      
      if (isFirstChild && allSiblingsEmpty) {
        return 'Empty list.';
      }
    }
  }
  
  return '';
}

/// ヒントテキストを表示すべきか判定
bool _shouldShowHint(int visibleIndex) {
  final realIndex = _getRealIndex(visibleIndex);
  if (realIndex == -1) return false;
  
  if (visibleIndex >= _controllers.length) return false;
  
  final controllerText = _controllers[visibleIndex].text;
  
  // 🔧 修正: 空またはダミー文字のみの場合にヒントを表示
  return controllerText.isEmpty || controllerText == _dummyChar;
}

/// レベルに応じたヒントテキストの左パディングを取得
double _getHintLeftPadding(int level, bool isLevel2Listified) {
  const double dummyCharWidth = 4.0;
  
  if (level == 0) {
    return dummyCharWidth;
  } else if (level == 1) {
    return 4 + 20 + dummyCharWidth; // パディング(4) + 矢印(20) + 半角
  } else if (level == 2) {
    if (isLevel2Listified) {
      return 16 + 20 + dummyCharWidth; // インデント(16) + 矢印(20) + 半角
    } else {
      return 20 + dummyCharWidth; // インデント(20) + 半角
    }
  } else if (level == 3) {
    return 36 + dummyCharWidth; // インデント(36) + 半角
  }
  return dummyCharWidth;
}

  Widget _buildLine(int visibleIndex) {
  if (visibleIndex >= _controllers.length) {
    return const SizedBox.shrink();
  }
  
  final realIndex = _getRealIndex(visibleIndex);
  if (realIndex == -1) return const SizedBox.shrink();
  
  final note = _notes[realIndex];
  final hintText = _getHintText(visibleIndex);
  
  // Level 2 がリスト化されているかを判定
  final hasGrandchildren = _notes.any((n) => n.parentId == note.id && n.level == 3);
  final isLevel2Listified = note.level == 2 && (hasGrandchildren || note.isCollapsed == true); 
  
  return Padding(
    key: ValueKey('line_${note.id}'),
    padding: const EdgeInsets.only(bottom: 2),
    child: GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        if (visibleIndex < _focusNodes.length) {
          _focusNodes[visibleIndex].requestFocus();
          
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (visibleIndex < _controllers.length) {
              _controllers[visibleIndex].selection = 
                  const TextSelection.collapsed(offset: 0);
            }
          });
        }
      },
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    // 🆕 追加: Level 0（通常メモ）の場合、半角スペース分のパディング
    if (note.level == 0)
      const SizedBox(width: 4),
    
    // 🔧 修正: 親（Level 1）の矢印
    if (note.level == 1) ...[
  GestureDetector(
    onTap: () {
      print('🎯 矢印タップ: level=1');
      _toggleCollapse(visibleIndex);
    },
    child: Container(
      width: 20,
      height: 16 * 1.3,
      // 🔧 修正: padding を削除（または top: 0）
      child: Text(
        note.isCollapsed ? '→' : '↓',
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 16,
          height: 1.3,
          fontWeight: FontWeight.w700,
        ).copyWith(
          fontFamilyFallback: const ['Hiragino Sans'],
        ),
      ),
    ),
  ),
],

// Level 2（子）の場合
if (note.level == 2) ...[
  // 🔧 修正: リスト化されていない場合は24、リスト化されている場合は20
  SizedBox(width: isLevel2Listified ? 16 : 20),
  
  // リスト化された子の矢印
  if (isLevel2Listified) ...[
    GestureDetector(
      onTap: () {
        print('🎯 矢印タップ: level=2, isCollapsed=${note.isCollapsed}, text="${note.text}"');
        _toggleCollapse(visibleIndex);
      },
      child: Container(
        width: 20,
        height: 16 * 1.3,
        child: Text(
          note.isCollapsed ? '→' : '↓',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 16,
            height: 1.3,
            fontWeight: FontWeight.w700,
          ).copyWith(
            fontFamilyFallback: const ['Hiragino Sans'],
          ),
        ),
      ),
    ),
  ],
],

// Level 3（孫）の場合
if (note.level == 3)
  const SizedBox(width: 36),  // 🔧 修正: 親(20) + 子矢印(20) = 40
              
              // テキスト入力
              Expanded(
                child: Focus(
                  onKeyEvent: (node, event) {
                    // ... (既存のBackspace処理コード、変更なし)
                    if (event.logicalKey == LogicalKeyboardKey.backspace && 
                        event is KeyDownEvent) {
                      
                      final controller = _controllers[visibleIndex];
                      final currentNote = _notes[realIndex];
                      
                      print('🔍 Backspace押下: visibleIndex=$visibleIndex, level=${currentNote.level}, text="${currentNote.text}", isEmpty=${controller.text.isEmpty}');
                      
                      if (visibleIndex == 0 && controller.text.isEmpty) {
                        print('🔍 最初の行で空: level=${currentNote.level}');
                        
                        if (currentNote.level == 1) {
                          print('🔍 最初の親（Level 1）→ 子孫を削除してLevel 0に変換');
                          _isUpdating = true;
                          
                          final nodesToDelete = <String>[];
                          _collectDescendants(currentNote.id, nodesToDelete);
                          
                          if (nodesToDelete.isNotEmpty) {
                            print('🔍 削除する子孫: ${nodesToDelete.length}個');
                            _notes.removeWhere((note) => nodesToDelete.contains(note.id));
                          }
                          
                          final updatedRealIndex = _notes.indexWhere((n) => n.id == currentNote.id);
                          if (updatedRealIndex != -1) {
                            _notes[updatedRealIndex] = _notes[updatedRealIndex].copyWith(level: 0, parentId: null);
                          }
                          
                          setState(() {
                            _rebuildControllers();
                          });
                          
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _isUpdating = false;
                            if (visibleIndex < _focusNodes.length) {
                              _focusNodes[visibleIndex].requestFocus();
                              
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (visibleIndex < _controllers.length) {
                                  _controllers[visibleIndex].selection = 
                                      const TextSelection.collapsed(offset: 0);
                                }
                              });
                            }
                          });
                          
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      }
                      
                      if (currentNote.level == 1 && controller.text.isEmpty) {
                        print('🔍 親（Level 1）で空 → 削除処理開始');
                        
                        if (visibleIndex > 0) {
                          print('🔍 _handleBackspace呼び出し（親削除）');
                          _handleBackspace(visibleIndex);
                          return KeyEventResult.handled;
                        }
                      }
                      
                      if (currentNote.level == 2 && currentNote.isCollapsed && controller.text.isEmpty) {
                        _isUpdating = true;
                        
                        _notes[realIndex] = currentNote.copyWith(isCollapsed: false);
                        
                        setState(() {
                          _rebuildControllers();
                        });
                        
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _isUpdating = false;
                          if (visibleIndex < _focusNodes.length) {
                            _focusNodes[visibleIndex].requestFocus();
                            
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (visibleIndex < _controllers.length) {
                                _controllers[visibleIndex].selection = 
                                    const TextSelection.collapsed(offset: 0);
                              }
                            });
                          }
                        });
                        
                        return KeyEventResult.handled;
                      }
                      
                      if (controller.text.isEmpty && 
                          controller.selection.baseOffset == 0 && 
                          visibleIndex > 0) {
                        print('🔍 _handleBackspace呼び出し: visibleIndex=$visibleIndex, level=${currentNote.level}');
                        _handleBackspace(visibleIndex);
                        return KeyEventResult.handled;
                      }
                    }
                    return KeyEventResult.ignored;
                  },
                  child: TextField(
  controller: _controllers[visibleIndex],
  focusNode: _focusNodes[visibleIndex],
  scrollPadding: EdgeInsets.only(
    bottom: MediaQuery.of(context).viewInsets.bottom + 100,
  ),
  style: GoogleFonts.inter(
    color: Colors.white,
    fontSize: 16,
    height: 1.3,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  ).copyWith(
    fontFamilyFallback: const ['Hiragino Sans'],
  ),
  decoration: const InputDecoration(
    border: InputBorder.none,
    contentPadding: EdgeInsets.zero,
    isDense: true,
  ),
  maxLines: null,
  keyboardType: TextInputType.multiline,
  // 🔧 追加：textInputAction を指定
  textInputAction: TextInputAction.newline,
  onSubmitted: (value) => _onSubmitted(visibleIndex),
  // 🔧 追加：onChanged で空白行のデリートを検知
  onChanged: (value) {
    // 空になった瞬間を検知
    if (value.isEmpty) {
      final realIndex = _getRealIndex(visibleIndex);
      if (realIndex != -1) {
        final currentNote = _notes[realIndex];
        
        // 空白行で何か入力があった場合（デリート含む）
        // これは次のフレームで処理
        Future.microtask(() {
          if (mounted && _controllers[visibleIndex].text.isEmpty) {
            print('🔍 onChanged: 空白行検知 index=$visibleIndex, text="${currentNote.text}"');
          }
        });
      }
    }
  },
),
                ),
              ),
            ],
          ),
          
          // カスタムヒント表示
AnimatedBuilder(
  animation: _controllers[visibleIndex],
  builder: (context, child) {
    final controllerText = _controllers[visibleIndex].text;
    final isEffectivelyEmpty = controllerText.isEmpty || controllerText == _dummyChar;
    
    // 🆕 修正: コントローラーの状態に基づいてヒントを再計算
    String dynamicHintText = '';
    if (isEffectivelyEmpty) {
      if (note.level == 1) {
        dynamicHintText = 'Listify';
      } else if (note.level == 2 && (hasGrandchildren || note.isCollapsed == true)) {
        dynamicHintText = 'Listify';
      } else if (note.level == 0 && visibleIndex == 0) {
        // 全てのノートが空の場合のみ
        final allNotesEmpty = _notes.every((n) => n.text.isEmpty || n.text == _dummyChar);
        if (allNotesEmpty) {
          dynamicHintText = 'Take notes.\nYou can also create a list.';
        }
      } else if (note.level == 2 && note.parentId != null && !note.isCollapsed!) {
        // 子（Level 2）で通常の子の場合
        final parent = _notes.firstWhere(
          (n) => n.id == note.parentId,
          orElse: () => note,
        );
        if (parent.isCollapsed == false) {
          final siblings = _notes.where((n) => 
            n.parentId == note.parentId && n.level == 2
          ).toList();
          final isFirstChild = siblings.isNotEmpty && siblings.first.id == note.id;
          final allSiblingsEmpty = siblings.every((n) => n.text.isEmpty || n.text == _dummyChar);
          if (isFirstChild && allSiblingsEmpty) {
            dynamicHintText = 'Empty list.';
          }
        }
      } else if (note.level == 3 && note.parentId != null) {
        // 孫（Level 3）の場合
        final parent = _notes.firstWhere(
          (n) => n.id == note.parentId,
          orElse: () => note,
        );
        if (parent.isCollapsed == false) {
          final siblings = _notes.where((n) => 
            n.parentId == note.parentId && n.level == 3
          ).toList();
          final isFirstChild = siblings.isNotEmpty && siblings.first.id == note.id;
          final allSiblingsEmpty = siblings.every((n) => n.text.isEmpty || n.text == _dummyChar);
          if (isFirstChild && allSiblingsEmpty) {
            dynamicHintText = 'Empty list.';
          }
        }
      }
    }
    
    if (isEffectivelyEmpty && dynamicHintText.isNotEmpty) {
      return Positioned(
        left: _getHintLeftPadding(note.level, isLevel2Listified),
        top: 0,
        child: IgnorePointer(
          child: Text(
            dynamicHintText,
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.3),
              fontSize: 16,
              height: 1.3,
              fontWeight: FontWeight.w400,
              letterSpacing: 0,
            ).copyWith(
              fontFamilyFallback: const ['Hiragino Sans'],
            ),
          ),
        ),
      );
    }
    
    return const SizedBox.shrink();
  },
),
        ],
      ),
    ),
  );
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
    height: 36,
    child: Stack(
      alignment: Alignment.center,
      children: [
        // 中央: タスク名（自動スクロール）
Center(
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 90),
    child: AutoScrollText(
      text: widget.taskTitle,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w900,
        fontFamily: 'Hiragino Sans',
        letterSpacing: -0.5,
      ),
    ),
  ),
),
        
        // 左: 戻るボタン（下向きのくの字）
        Positioned(
          left: 0,
          child: IconButton(
            icon: const Icon(
              Icons.keyboard_arrow_down, // 🔧 修正: arrow_back → keyboard_arrow_down
              color: Colors.white,
              size: 32, // 🔧 修正: 28 → 32（少し大きく）
            ),
            onPressed: _saveAndClose,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ),
        
        // 右: ゴミ箱ボタン + Listボタン
        Positioned(
          right: 0,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ゴミ箱ボタン
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.white,
                  size: 24,
                ),
                onPressed: _showDeleteAllConfirmation,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              
              const SizedBox(width: 12),
              
              // Listボタン（緑の円 + アイコンのみ）
              GestureDetector(
                onTap: _onListifyButtonPressed,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1DB954),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.format_list_bulleted,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  ),
),
          Expanded(
  child: GestureDetector(
    onTap: () {
      FocusScope.of(context).unfocus();
    },
    child: Container(
      color: Colors.transparent,
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 150, // 🔧 修正：100 → 150（余裕を増やす）
              ),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
              itemCount: _controllers.length,
              itemBuilder: (context, index) {
                return _buildLine(index);
              },
            ),
          ),
        ],
      ),
    ),
  ),
),
        ],
      ),
    ),
  );
}

/// 🆕 新規追加: 全削除の確認ダイアログを表示
void _showDeleteAllConfirmation() {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Delete All Notes',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          'Are you sure you want to delete all notes for this task?\nThis action cannot be undone.',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // ダイアログを閉じる
            },
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // ダイアログを閉じる
              _deleteAllNotes(); // 全削除を実行
            },
            child: const Text(
              'Yes',
              style: TextStyle(
                color: Color(0xFFEF4444),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    },
  );
}

/// 🆕 新規追加: 全メモを削除
void _deleteAllNotes() {
  setState(() {
    _notes.clear();
    
    // 🆕 修正: 新しい空行に _dummyChar を入れる
    _notes.add(LyricNoteItem(text: _dummyChar, level: 0, parentId: null));
    
    _rebuildControllers();
  });
  
  widget.onSave([]);
  
  print('🗑️ すべてのメモを削除しました（空リスト保存）');
}

/// 🆕 新規追加: Listボタン押下時の処理
void _onListifyButtonPressed() {
  _makeList();
}

/// 🆕 新規追加: 保存して閉じる
void _saveAndClose() {
  _saveNotes();
  widget.onClose();
}

}

// 🆕 自動スクロールテキストウィジェット
class AutoScrollText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final VoidCallback? onTap;
  
  const AutoScrollText({
    super.key,
    required this.text,
    required this.style,
    this.onTap,
  });

  @override
  State<AutoScrollText> createState() => _AutoScrollTextState();
}

class _AutoScrollTextState extends State<AutoScrollText> with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _animationController;
  bool _needsScroll = false;
  double _textWidth = 0;
  double _containerWidth = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIfNeedsScroll();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(AutoScrollText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkIfNeedsScroll();
      });
    }
  }

  void _checkIfNeedsScroll() {
    if (!mounted) return;
    
    final textPainter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    
    _textWidth = textPainter.width;
    
    if (_scrollController.hasClients) {
      _containerWidth = _scrollController.position.viewportDimension;
      _needsScroll = _textWidth > _containerWidth;
      
      if (_needsScroll) {
        _startScrollAnimation();
      } else {
        _animationController.stop();
      }
    }
  }

  void _startScrollAnimation() {
    if (!mounted || !_needsScroll) return;
    
    final scrollDistance = _textWidth - _containerWidth + 20;
    final duration = Duration(milliseconds: (scrollDistance * 30).toInt());
    
    _animationController.duration = duration;
    
    _animationController.addStatusListener((status) {
      if (!mounted) return;
      
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            _scrollController.jumpTo(0);
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted && _needsScroll) {
                _animationController.forward(from: 0);
              }
            });
          }
        });
      }
    });
    
    _animationController.addListener(() {
      if (mounted && _scrollController.hasClients) {
        final scrollDistance = _textWidth - _containerWidth + 20;
        _scrollController.jumpTo(_animationController.value * scrollDistance);
      }
    });
    
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _needsScroll) {
        _animationController.forward();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Text(
          widget.text,
          style: widget.style,
          maxLines: 1,
          overflow: TextOverflow.visible,
        ),
      ),
    );
  }
}