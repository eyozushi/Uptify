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
          // ヘッダー部分（変更なし）
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
                  onPressed: widget.onClose,
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
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Hiragino Sans',
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                
                const Spacer(),
                const SizedBox(width: 48),
              ],
            ),
          ),
          
          
          
          // 🔧 入力エリア: PlayerScreenのタスク説明文と完全一致
          // 🔧 入力エリア: 太い文字に変更
Expanded(
  child: SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: TextField(
      controller: _controller,
      // 🔧 重要: 太い文字に変更
      style: const TextStyle( // 🔧 const を追加
        color: Colors.white, // 🔧 完全な白に変更
        fontSize: 24, // 🔧 16 → 24 に変更（大きく）
        height: 1.6,
        fontWeight: FontWeight.w700, // 🔧 w300 → w700 に変更（太く）
        fontFamily: 'Hiragino Sans',
      ),
      decoration: InputDecoration(
        hintText: 'リリックを書いてください。\n思考、感情、振り返り、\n自由に記録しましょう。',
        hintStyle: TextStyle(
          color: Colors.white.withOpacity(0.5), // 🔧 0.4 → 0.5 に変更
          fontSize: 24, // 🔧 16 → 24 に変更
          height: 1.6,
          fontWeight: FontWeight.w700, // 🔧 w300 → w400 に変更
          fontFamily: 'Hiragino Sans',
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
}