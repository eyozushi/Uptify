import 'package:flutter/material.dart';
import '../models/task_item.dart';
import '../services/data_service.dart';
import 'lyric_notes/lyric_notes_preview.dart';
import 'lyric_notes/lyric_notes_expanded_view.dart';

class LyricNotesWidget extends StatefulWidget {
  final TaskItem task;
  final double albumWidth;
  final Color albumColor;
  final Function(String taskId, List<LyricNoteItem> notes)? onNoteSaved;  // 🔧 変更
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

class _LyricNotesWidgetState extends State<LyricNotesWidget>
    with SingleTickerProviderStateMixin {
  /// 展開/折りたたみを切り替え
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
            initialNotes: widget.task.lyricNotes,  // 🔧 変更
            backgroundColor: _getBrighterColor(widget.albumColor),
            onSave: _saveNotes,  // 🔧 変更: メソッド名変更
            onClose: () => Navigator.of(context).pop(),
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    ),
  );
}

  /// メモを保存
/// 🔧 修正: ノートリストを保存
Future<void> _saveNotes(List<LyricNoteItem> notes) async {
  try {
    final dataService = DataService();
    
    // シングルアルバムかライフドリームアルバムかで分岐
    if (widget.isSingleAlbum && widget.albumId != null) {
      // シングルアルバムの場合
      await dataService.updateSingleAlbumTaskLyricNotes(
        albumId: widget.albumId!,
        taskId: widget.task.id,
        notes: notes,
      );
      print('✅ シングルアルバムのLyric Notes保存完了: ${widget.task.title} (${notes.length}行)');
    } else {
      // ライフドリームアルバムの場合
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
  
  // 🔧 修正: 明度を適切な範囲に調整（白文字が読みやすい暗めの色）
  double targetLightness;
  
  if (hsl.lightness < 0.3) {
    // 暗すぎる場合: 少し明るくする（0.3〜0.4の範囲）
    targetLightness = 0.35;
  } else if (hsl.lightness > 0.6) {
    // 明るすぎる場合: 暗くする（0.4〜0.5の範囲）
    targetLightness = 0.45;
  } else {
    // 適度な明るさの場合: 少し暗めに調整
    targetLightness = (hsl.lightness * 0.7).clamp(0.3, 0.5);
  }
  
  // 🔧 修正: 彩度も適度に調整（鮮やかすぎないように）
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
    notes: widget.task.lyricNotes,  // 🔧 変更
    width: widget.albumWidth,
    backgroundColor: backgroundColor,
    onTap: _toggleExpanded,
  );
}
}
}