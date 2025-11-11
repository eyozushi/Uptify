// widgets/lyric_notes_widget.dart
import 'package:flutter/material.dart';
import '../models/task_item.dart';
import '../models/lyric_note_item.dart';
import '../services/data_service.dart';
import 'lyric_notes/lyric_notes_preview.dart';
import 'lyric_notes/lyric_notes_expanded_view.dart';
import 'lyric_notes/lyric_notes_editor_screen.dart';

class LyricNotesWidget extends StatefulWidget {
  final TaskItem task;
  final double albumWidth;
  final Color albumColor;
  final Function(String taskId, List<LyricNoteItem> notes)? onNoteSaved;
  final String? albumId;
  final bool isSingleAlbum;

  const LyricNotesWidget({
    super.key,
    required this.task,
    required this.albumWidth,
    required this.albumColor,
    this.onNoteSaved,
    this.albumId,
    this.isSingleAlbum = false,
  });

  @override
  State<LyricNotesWidget> createState() => _LyricNotesWidgetState();
}

class _LyricNotesWidgetState extends State<LyricNotesWidget> {
  // 🆕 追加: 最新のノートを保持
  late List<LyricNoteItem> _currentNotes;
  
  @override
  void initState() {
    super.initState();
    _currentNotes = widget.task.lyricNotes ?? [];
  }
  
  @override
  void didUpdateWidget(LyricNotesWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 🔧 修正: taskが更新されたら、ノートも更新
    if (oldWidget.task.id == widget.task.id && 
        widget.task.lyricNotes != null) {
      _currentNotes = widget.task.lyricNotes!;
    }
  }
  
  /// 拡大表示を開く
  void _toggleExpanded() {
    Navigator.of(context).push(
      PageRouteBuilder(
        fullscreenDialog: true,
        opaque: false,
        barrierColor: Colors.transparent,
        pageBuilder: (context, animation, secondaryAnimation) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            )),
            child: LyricNotesExpandedView(
              taskTitle: widget.task.title,
              initialNotes: _currentNotes,
              backgroundColor: _getBrighterColor(widget.albumColor),
              onSave: _saveNotes,
              onClose: () => Navigator.of(context).pop(),
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  /// 編集画面を直接開く
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
              taskTitle: widget.task.title,
              initialNotes: _currentNotes,
              onSave: _saveNotes,
              onClose: () => Navigator.of(context).pop(),
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  /// メモを保存
  Future<void> _saveNotes(List<LyricNoteItem> notes) async {
    try {
      // 🔧 修正: ローカルの状態を更新
      setState(() {
        _currentNotes = notes;
      });
      
      final dataService = DataService();
      
      // シングルアルバムかライフドリームアルバムかで分岐
      if (widget.isSingleAlbum && widget.albumId != null) {
        await dataService.updateSingleAlbumTaskLyricNotes(
          albumId: widget.albumId!,
          taskId: widget.task.id,
          notes: notes,
        );
        print('✅ シングルアルバムのLyric Notes保存完了: ${widget.task.title} (${notes.length}行)');
      } else {
        await dataService.updateTaskLyricNotes(widget.task.id, notes);
        print('✅ ライフドリームアルバムのLyric Notes保存完了: ${widget.task.title} (${notes.length}行)');
      }
      
      // 親ウィジェット（PlayerScreen）に通知
      if (widget.onNoteSaved != null) {
        widget.onNoteSaved!(widget.task.id, notes);
      }
    } catch (e) {
      print('❌ Lyric Notes保存エラー: $e');
    }
  }

  /// アルバムカラーより視認性の高い背景色を生成
  Color _getBrighterColor(Color color) {
    final hsl = HSLColor.fromColor(color);
    
    double targetLightness;
    
    if (hsl.lightness < 0.3) {
      targetLightness = 0.35;
    } else if (hsl.lightness > 0.6) {
      targetLightness = 0.45;
    } else {
      targetLightness = (hsl.lightness * 0.7).clamp(0.3, 0.5);
    }
    
    final targetSaturation = (hsl.saturation * 0.6).clamp(0.3, 0.7);
    
    return hsl
        .withLightness(targetLightness)
        .withSaturation(targetSaturation)
        .toColor();
  }
  
  @override
  Widget build(BuildContext context) {
    final backgroundColor = _getBrighterColor(widget.albumColor);

    return LyricNotesPreview(
      notes: _currentNotes,
      width: widget.albumWidth,
      backgroundColor: backgroundColor,
      onTap: _toggleExpanded,
      onEdit: _openEditor,
    );
  }
}