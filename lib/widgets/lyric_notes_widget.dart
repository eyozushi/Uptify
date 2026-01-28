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

  Color? _cachedBackgroundColor;
  
  @override
void initState() {
  super.initState();
  _currentNotes = widget.task.lyricNotes ?? [];
  
  // 🆕 追加: 初期背景色を計算
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) {
      setState(() {
        _cachedBackgroundColor = _getBrighterColor(widget.albumColor);
      });
    }
  });
}
  
  @override
void didUpdateWidget(LyricNotesWidget oldWidget) {
  super.didUpdateWidget(oldWidget);
  
  // タスクIDが変わった場合も更新
  if (oldWidget.task.id != widget.task.id) {
    print('🔄 LyricNotesWidget: タスク変更検知');
    print('  旧タスク: ${oldWidget.task.title} (ID: ${oldWidget.task.id})');
    print('  新タスク: ${widget.task.title} (ID: ${widget.task.id})');
    print('  新メモ数: ${widget.task.lyricNotes?.length ?? 0}');
    
    setState(() {
      _currentNotes = widget.task.lyricNotes ?? [];
      _cachedBackgroundColor = _getBrighterColor(widget.albumColor); // 🆕 追加
    });
  }
  // 同じタスクでもメモが更新された場合
  else if (widget.task.lyricNotes != null && 
           widget.task.lyricNotes != oldWidget.task.lyricNotes) {
    print('🔄 LyricNotesWidget: 同じタスクのメモ更新検知');
    print('  タスク: ${widget.task.title} (ID: ${widget.task.id})');
    print('  新メモ数: ${widget.task.lyricNotes!.length}');
    
    setState(() {
      _currentNotes = widget.task.lyricNotes!;
    });
  }
  
  // 🆕 追加: アルバム色が変わった場合
  if (oldWidget.albumColor != widget.albumColor) {
    setState(() {
      _cachedBackgroundColor = _getBrighterColor(widget.albumColor);
    });
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
            backgroundColor: Colors.black, // 🔧 追加: 黒色を明示的に指定
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
  // 🔧 修正: キャッシュがあればそれを使用、なければ黒
  final backgroundColor = _cachedBackgroundColor ?? Colors.black;

  return LyricNotesPreview(
    notes: _currentNotes,
    width: widget.albumWidth,
    backgroundColor: backgroundColor,
    onTap: _toggleExpanded,
    onEdit: _openEditor,
  );
}
}