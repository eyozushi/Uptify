import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Lyric Notesの全画面展開ビュー
/// 下から上にスライドして表示され、自由にメモを編集できる
class LyricNotesExpandedView extends StatefulWidget {
  final String taskTitle;
  final String? initialNote;
  final Color backgroundColor;
  final Function(String) onSave;
  final VoidCallback onClose;

  const LyricNotesExpandedView({
    super.key,
    required this.taskTitle,
    required this.initialNote,
    required this.backgroundColor,
    required this.onSave,
    required this.onClose,
  });

  @override
  State<LyricNotesExpandedView> createState() => _LyricNotesExpandedViewState();
}

class _LyricNotesExpandedViewState extends State<LyricNotesExpandedView> {
  late TextEditingController _controller;
  bool _isModified = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialNote ?? '');
    _controller.addListener(_onTextChanged);
  }

  /// テキスト変更時の自動保存処理（500msデバウンス）
  void _onTextChanged() {
    if (!_isModified) {
      setState(() {
        _isModified = true;
      });
    }
    
    // 自動保存（500ms後に実行）
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        widget.onSave(_controller.text);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // 閉じるボタン（左上）
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 32),
                    onPressed: widget.onClose,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const Spacer(),
                  
                  // タスク名（中央に大きく表示）
                  Expanded(
                    flex: 3,
                    child: Text(
                      widget.taskTitle,
                      style: GoogleFonts.montserrat(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  
                  const Spacer(),
                  const SizedBox(width: 48), // 閉じるボタンとバランスを取る
                ],
              ),
            ),
            
            const Divider(
              color: Colors.white24,
              height: 1,
            ),
            
            // 入力エリア（画面全体に広がる）
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: TextField(
                  controller: _controller,
                  style: GoogleFonts.notoSansJp(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    height: 1.8,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Write your lyrics here...\n\nCapture your thoughts,\nreflections, and achievements.',
                    hintStyle: GoogleFonts.notoSansJp(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 18,
                      height: 1.8,
                    ),
                    border: InputBorder.none,
                  ),
                  maxLines: null,
                  expands: true,
                  textAlign: TextAlign.left,
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
}