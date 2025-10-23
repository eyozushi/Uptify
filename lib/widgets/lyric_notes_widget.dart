import 'package:flutter/material.dart';
import '../models/task_item.dart';
import '../services/data_service.dart';
import 'lyric_notes/lyric_notes_preview.dart';
import 'lyric_notes/lyric_notes_expanded_view.dart';

class LyricNotesWidget extends StatefulWidget {
  final TaskItem task;
  final double albumWidth;
  final Color albumColor;
  final Function(String taskId, String note)? onNoteSaved;
  final String? albumId; // 🆕 追加: シングルアルバムID
  final bool isSingleAlbum; // 🆕 追加: シングルアルバムかどうか

  const LyricNotesWidget({
    super.key,
    required this.task,
    required this.albumWidth,
    required this.albumColor,
    this.onNoteSaved,
    this.albumId, // 🆕 追加
    this.isSingleAlbum = false, // 🆕 追加（デフォルトはfalse）
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
  try {
    final dataService = DataService();
    
    // 🔧 修正: シングルアルバムかライフドリームアルバムかで分岐
    if (widget.isSingleAlbum && widget.albumId != null) {
      // シングルアルバムの場合
      await dataService.updateSingleAlbumTaskLyricNote(
        albumId: widget.albumId!,
        taskId: widget.task.id,
        note: note,
      );
      print('✅ シングルアルバムのLyric Note保存完了: ${widget.task.title}');
    } else {
      // ライフドリームアルバムの場合
      await dataService.updateTaskLyricNote(widget.task.id, note);
      print('✅ ライフドリームアルバムのLyric Note保存完了: ${widget.task.title}');
    }
    
    // 親ウィジェット（PlayerScreen）に通知
    if (widget.onNoteSaved != null) {
      widget.onNoteSaved!(widget.task.id, note);
    }
  } catch (e) {
    print('❌ Lyric Note保存エラー: $e');
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

    // プレビュー表示のみ
    return LyricNotesPreview(
      noteContent: widget.task.lyricNote,
      width: widget.albumWidth,
      backgroundColor: backgroundColor,
      onTap: _toggleExpanded,
    );
  }
}