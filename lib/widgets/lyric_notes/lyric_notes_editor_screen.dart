// widgets/lyric_notes/lyric_notes_editor_screen.dart - フェーズ2: 親子関係対応版
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
  static const String _dummyChar = '\u200B';

  late List<LyricNoteItem> _notes; // 全てのノート（表示/非表示含む）
  final List<TextEditingController> _controllers = [];
  final List<FocusNode> _focusNodes = [];
  Timer? _autoSaveTimer;
  final ScrollController _scrollController = ScrollController();
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    
    // 初期データの設定
    if (widget.initialNotes != null && widget.initialNotes!.isNotEmpty) {
      _notes = List.from(widget.initialNotes!);
    } else {
      _notes = [];
    }
    
    // 常に最後に空行を追加（Level 0, parentId: null）
    _notes.add(LyricNoteItem(text: '', level: 0, parentId: null));
    
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

  /// 行のコントローラーをセットアップ
void _setupLine(int index, LyricNoteItem note) {
  // 🔧 修正: 空の場合はダミー文字を入れる
  final displayText = note.text.isEmpty ? _dummyChar : note.text;
  final controller = TextEditingController(text: displayText);
  final focusNode = FocusNode();
  
  _controllers.add(controller);
  _focusNodes.add(focusNode);
  
  // 🆕 追加: 前回のテキストを保持する変数
  String previousText = displayText;
  
  // コントローラーにリスナーを追加
controller.addListener(() {
  if (!_isUpdating) {
    final currentText = controller.text;
    
    // 🐛 デバッグ: 現在の状態を表示
    print('🐛 リスナー発火: index=$index, currentText="$currentText" (length=${currentText.length}), previousText="$previousText" (length=${previousText.length})');
    
    // 🔧 修正: ダミー文字のみの場合は空として扱う
    final currentTextClean = currentText == _dummyChar ? '' : currentText;
    final previousTextClean = previousText == _dummyChar ? '' : previousText;
    
    // 🔧 修正: ダミー文字が削除された（空→空のデリート）を検知
    if (currentText.isEmpty && previousText == _dummyChar) {
      print('🐛 デリート検知条件: currentText.isEmpty=${currentText.isEmpty}, previousText==$_dummyChar=${previousText == _dummyChar}');
      
      final realIndex = _getRealIndex(index);
      if (realIndex != -1) {
        final currentNote = _notes[realIndex];
        
        print('🔍 空行でデリート検知（ダミー文字削除）: visibleIndex=$index, level=${currentNote.level}');
    
          // 🔧 修正: WidgetsBinding.instance.addPostFrameCallbackで遅延実行
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _isUpdating) return;
            
            // 最初の行で親の場合
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
                _notes[updatedRealIndex] = _notes[updatedRealIndex].copyWith(level: 0, parentId: null);
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
                      // 🔧 修正: ダミー文字を再設定
                      _controllers[index].text = _dummyChar;
                      _controllers[index].selection = 
                          const TextSelection.collapsed(offset: 0);
                    }
                  });
                }
              });
              
              previousText = _dummyChar; // 🔧 修正: previousTextを更新
              return;
            }
            
            // 親（Level 1）で空の場合
            if (currentNote.level == 1) {
              print('🔍 親（Level 1）で空 → Level 0に変換');
              _isUpdating = true;
              
              final noteRealIndex = _notes.indexWhere((n) => n.id == currentNote.id);
              if (noteRealIndex != -1) {
                _notes[noteRealIndex] = _notes[noteRealIndex].copyWith(level: 0, parentId: null);
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
                      // 🔧 修正: ダミー文字を再設定
                      _controllers[index].text = _dummyChar;
                      _controllers[index].selection = 
                          const TextSelection.collapsed(offset: 0);
                    }
                  });
                }
              });
              
              previousText = _dummyChar; // 🔧 修正: previousTextを更新
              return;
            }
            
            // 子（Level 2）でリスト化されていて空の場合
            if (currentNote.level == 2 && currentNote.isCollapsed) {
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
                      // 🔧 修正: ダミー文字を再設定
                      _controllers[index].text = _dummyChar;
                      _controllers[index].selection = 
                          const TextSelection.collapsed(offset: 0);
                    }
                  });
                }
              });
              
              previousText = _dummyChar; // 🔧 修正: previousTextを更新
              return;
            }
            
            // 2行目以降で空の場合、前の行に戻る
            if (index > 0) {
              print('🔍 _handleBackspace呼び出し（スマホ、ダミー文字削除）: visibleIndex=$index');
              _handleBackspace(index);
              return;
            }
          });
          
          previousText = currentText;
          return;
        }
      }
      
      // 前回のテキストを更新
      previousText = currentText;
      
      // 🔧 修正: テキストが変更された時、ダミー文字を除去して保存
      final realIndex = _getRealIndex(index);
      if (realIndex == -1) return;
      
      // ダミー文字を除去してノートを更新
      _notes[realIndex] = _notes[realIndex].copyWith(
        text: currentTextClean,
        updatedAt: DateTime.now(),
      );
      
      // 最後の行に入力があった場合、新しい空行を追加
      if (realIndex == _notes.length - 1 && currentTextClean.isNotEmpty) {
        _notes.add(LyricNoteItem(text: '', level: 0, parentId: null));
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_isUpdating) {
            setState(() {
              _rebuildControllers();
            });
          }
        });
      }
      
      // 自動保存
      _autoSaveTimer?.cancel();
      _autoSaveTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted) {
          _saveNotes();
        }
      });
    }
  });
}

  /// ノートを保存
void _saveNotes() {
  final notesToSave = <LyricNoteItem>[];
  
  // 最後の空行（新規入力用）を除外したリストを作成
  for (int i = 0; i < _notes.length; i++) {
    final note = _notes[i];
    
    // 最後の行で、かつ空の場合はスキップ（新規入力用の空行）
    if (i == _notes.length - 1 && note.text.trim().isEmpty) {
      continue;
    }
    
    // それ以外の行を追加
    notesToSave.add(note);
  }
  
  // 🔧 修正: デバッグログを追加
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
  // フォーカスされている行を探す
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
      _notes[realIndex] = currentNote.copyWith(
        level: 1,
        isCollapsed: true,
        parentId: null, // 親なのでparentIdはnull
      );
      _rebuildControllers();
    });
    _saveNotes();
  }
  // 🆕 追加：Level 2（子） → Level 2（親として扱い、展開可能に）
  else if (currentNote.level == 2) {
    setState(() {
      _notes[realIndex] = currentNote.copyWith(
        isCollapsed: true, // 折りたたみ可能に
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
  
  // 親（Level 1）で空の場合 → 通常ノート（Level 0）に戻る
  if (currentNote.level == 1 && currentNote.text.isEmpty) {
    _isUpdating = true;
    
    _notes[realIndex] = currentNote.copyWith(level: 0, parentId: null);
    
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
  
  // 🆕 追加：子（Level 2）で空の場合 → 通常の子（Level 2）に戻る
  if (currentNote.level == 2 && currentNote.text.isEmpty && currentNote.isCollapsed) {
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
        text: '',
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
          text: '',
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
          }
        });
        return;
      }
    }
  }

  // 🆕 追加：親（Level 1）で折りたたみ中（isCollapsed == true）の場合
  if (currentNote.level == 1 && currentNote.isCollapsed) {
    _isUpdating = true;
    
    int insertPosition = realIndex + 1;
    for (int i = realIndex + 1; i < _notes.length; i++) {
      final note = _notes[i];
      if (note.level <= 1) break;
      if (note.parentId == currentNote.id) {
        insertPosition = i + 1;
      }
    }
    
    _notes.insert(insertPosition, LyricNoteItem(
      text: '',
      level: 1,
      parentId: null,
      isCollapsed: true,
    ));
    
    setState(() {
      _rebuildControllers();
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isUpdating = false;
      if (visibleIndex + 1 < _focusNodes.length) {
        _focusNodes[visibleIndex + 1].requestFocus();
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
      text: '',
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
        text: '',
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
          text: '',
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
          }
        });
        return;
      }
    }
  }
  
  _isUpdating = true;
  
  // 🔧 修正：新しい行のlevelとparentIdを決定
  // 🔧 修正：新しい行のlevelとparentIdを決定
  int newLevel;
  String? newParentId;
  bool? newIsCollapsed; // 🆕 追加
  
  if (currentNote.level == 0) {
    newLevel = 0;
    newParentId = null;
    newIsCollapsed = null;
  } else if (currentNote.level == 1) {
    newLevel = 1;
    newParentId = null;
    newIsCollapsed = true;
  } else if (currentNote.level == 2) {
    // 🔧 修正：Level 2の処理を修正
    if (currentNote.isCollapsed == true) {
      // リスト化された子 → 同じレベルのリスト化された子
      newLevel = 2;
      newParentId = currentNote.parentId;
      newIsCollapsed = true;
    } else {
      // 🔧 修正：通常の子 → 同じ親の通常の子（isCollapsedはnullまたはfalse）
      newLevel = 2;
      newParentId = currentNote.parentId;
      newIsCollapsed = null; // 🔧 修正：nullに変更（falseではなく）
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
  
  // 新しい行を挿入する位置を計算
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
  
  // 🔧 修正：新しい行を挿入（isCollapsedがnullの場合は省略）
  final newNote = newIsCollapsed != null
      ? LyricNoteItem(
          text: '',
          level: newLevel,
          parentId: newParentId,
          isCollapsed: newIsCollapsed,
        )
      : LyricNoteItem(
          text: '',
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
    
    // 2行目以降は前の行に戻る
    _isUpdating = true;
    
    // 前の行のコントローラーとテキスト長を先に取得
    final prevController = _controllers[visibleIndex - 1];
    final prevLength = prevController.text.length;
    
    // 削除する行の情報を取得
    final currentNote = _notes[realIndex];
    
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
      
      // 他の子要素がなければ、親を折りたたみ状態に
      if (otherChildren.isEmpty) {
        final parentIndex = _notes.indexWhere((n) => n.id == currentNote.parentId);
        if (parentIndex != -1) {
          _notes[parentIndex] = _notes[parentIndex].copyWith(isCollapsed: true);
          print('🔍 親を折りたたみ状態に変更');
        }
      }
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
    
    // 削除後に前の行にフォーカスとカーソル位置を設定
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
      _notes.insert(realIndex + 1, LyricNoteItem(
        text: '',
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
  
  // 親（Level 1）で空の場合
  if (note.text.isEmpty && note.level == 1) {
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
  
  // 🔧 修正: コントローラーのテキストから判定
  // ダミー文字のみ、または完全に空の場合のみヒントを表示
  final cleanText = controllerText == _dummyChar ? '' : controllerText;
  
  return cleanText.isEmpty;
}

/// レベルに応じたヒントテキストの左パディングを取得
double _getHintLeftPadding(int level, bool isLevel2Listified) {
  if (level == 0) {
    return 0; // インデントなし
  } else if (level == 1) {
    return 20; // 親の矢印分
  } else if (level == 2) {
    if (isLevel2Listified) {
      // リスト化された子の場合: 親のインデント(20) + 自身の矢印(20)
      return 40;
    } else {
      // 通常の子の場合: 親のインデント(20)のみ
      return 20;
    }
  } else if (level == 3) {
    // 孫の場合: 親(20) + 子(20)
    return 40;
  }
  return 0;
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
            crossAxisAlignment: CrossAxisAlignment.start, // 🔧 修正: center → start（元に戻す）
            children: [
              // 🔧 修正: 親（Level 1）の矢印
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
  const SizedBox(width: 20),
  
  // 🔧 修正: リスト化された子の矢印
  if (isLevel2Listified) ...[
    GestureDetector(
      onTap: () {
        print('🎯 矢印タップ: level=2, isCollapsed=${note.isCollapsed}, text="${note.text}"');
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
],
              
              // Level 3（孫）の場合、親＋子の矢印分だけインデント
              if (note.level == 3)
                const SizedBox(width: 40),
              
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
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 16,
                      height: 1.3,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0,
                      // 🗑️ 削除: leadingDistribution
                    ).copyWith(
                      fontFamilyFallback: const ['Hiragino Sans'],
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                    maxLines: null,
                    keyboardType: TextInputType.text,
                    onSubmitted: (value) => _onSubmitted(visibleIndex),
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
    final cleanText = controllerText == _dummyChar ? '' : controllerText;
    
    if (cleanText.isEmpty && hintText.isNotEmpty) {
      return Positioned(
        left: _getHintLeftPadding(note.level, isLevel2Listified),
        top: 0, // 🔧 修正: 1 → 0
        child: IgnorePointer(
          child: Text(
            hintText,
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
// ヘッダー
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  child: SizedBox(
    height: 36,
    child: Stack(
      alignment: Alignment.center,
      children: [
        // 中央: タスク名（絶対的な中央に固定）
        Center(
          child: Text(
            widget.taskTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              fontFamily: 'Hiragino Sans',
              letterSpacing: -0.5
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
          // 編集エリア（既存のコード）
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
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
    // すべてのノートをクリア
    _notes.clear();
    
    // 新しい空行を1つだけ追加
    _notes.add(LyricNoteItem(text: '', level: 0, parentId: null));
    
    // コントローラーを再構築
    _rebuildControllers();
  });
  
  // 🔧 修正: 空リストを明示的に保存
  widget.onSave([]); // 空リストを保存
  
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