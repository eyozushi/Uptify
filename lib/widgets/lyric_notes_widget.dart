import 'package:flutter/material.dart';
import '../models/task_item.dart';
import '../services/data_service.dart';
import 'lyric_notes/lyric_notes_preview.dart';
import 'lyric_notes/lyric_notes_expanded_view.dart';

/// Lyric Notesのメインウィジェット
/// プレビューと展開ビューを管理し、下から上へのアニメーションを制御
class LyricNotesWidget extends StatefulWidget {
  final TaskItem task;
  final double albumWidth;
  final Color albumColor;

  const LyricNotesWidget({
    super.key,
    required this.task,
    required this.albumWidth,
    required this.albumColor,
  });

  @override
  State<LyricNotesWidget> createState() => _LyricNotesWidgetState();
}

class _LyricNotesWidgetState extends State<LyricNotesWidget>
    with SingleTickerProviderStateMixin {
  /// 展開/折りたたみを切り替え
  void _toggleExpanded() {
    // フルスクリーンダイアログとして表示（下から上へスライド）
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
              initialNote: widget.task.lyricNote,
              backgroundColor: _getBrighterColor(widget.albumColor),
              onSave: _saveNote,
              onClose: () => Navigator.of(context).pop(),
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  /// メモを保存
  Future<void> _saveNote(String note) async {
    final dataService = DataService();
    await dataService.updateTaskLyricNote(widget.task.id, note);
  }

  /// アルバムカラーより明るい色を生成
  Color _getBrighterColor(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness + 0.1).clamp(0.0, 1.0)).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = _getBrighterColor(widget.albumColor);

    // プレビュー表示のみ
    return LyricNotesPreview(
      noteContent: widget.task.lyricNote,
      width: widget.albumWidth,
      backgroundColor: backgroundColor,
      onTap: _toggleExpanded,
    );
  }
}