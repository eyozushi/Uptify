// settings_screen.dart - onCloseとonSaveコールバック対応完全版
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import '../models/task_item.dart';
import '../models/single_album.dart';
import '../services/data_service.dart';
import 'package:flutter/services.dart';
import 'package:palette_generator/palette_generator.dart';

class SettingsScreen extends StatefulWidget {
  final String idealSelf;
  final String artistName;
  final String todayLyrics;
  final File? albumImage;
  final Uint8List? albumCoverImage;
  final List<TaskItem> tasks;
  final bool isEditingLifeDream;
  final String? albumId;  // 🆕 追加：削除用のアルバムID
  final VoidCallback? onClose;
  final Function(Map<String, dynamic>)? onSave;
  final VoidCallback? onDelete;  // 🆕 追加：削除コールバック

  const SettingsScreen({
    super.key,
    required this.idealSelf,
    required this.artistName,
    required this.todayLyrics,
    this.albumImage,
    this.albumCoverImage,
    required this.tasks,
    this.isEditingLifeDream = true,
    this.albumId,  // 🆕 追加
    this.onClose,
    this.onSave,
    this.onDelete,  // 🆕 追加
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}


class _SettingsScreenState extends State<SettingsScreen> {
  final DataService _dataService = DataService();

  // 🆕 新規追加：背景色用のフィールド
  Color _dominantColor = const Color(0xFF2D1B69);
  Color _accentColor = const Color(0xFF1A1A2E);
  bool _isExtractingColors = false;
  
  late TextEditingController _idealSelfController;
  
  List<TaskItem> _tasks = [];
  List<TextEditingController> _taskTitleControllers = [];

  List<TextEditingController> _taskUrlControllers = [];
  bool _isLoading = false;
  
  // 画像関連の変数
  File? _albumImage;
  Uint8List? _imageBytes;
  bool _hasImageChanged = false;

  @override
void initState() {
  super.initState();
  
  _idealSelfController = TextEditingController(text: widget.idealSelf);
  // 🗑️ 削除：_artistNameController、_todayLyricsController
  
  _albumImage = widget.albumImage;
  _imageBytes = widget.albumCoverImage;
  
  _initializeTasks();
  
  // 🔧 修正：タスクコントローラーの初期化（descriptionを削除）
  for (int i = 0; i < _tasks.length; i++) {
    _taskTitleControllers.add(TextEditingController(text: _tasks[i].title));
    _taskUrlControllers.add(TextEditingController(text: _tasks[i].assistUrl ?? ''));
  }
  
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _extractColorsFromImage();
  });
}

  void _initializeTasks() {
  _tasks.clear();
  
  // シングルアルバムの場合は既存タスクをそのまま使用（IDとLyric Noteを保持）
  if (!widget.isEditingLifeDream) {
    for (int i = 0; i < widget.tasks.length; i++) {
      final task = widget.tasks[i];
      _tasks.add(TaskItem(
        id: task.id, // 🔧 追加：既存のIDを保持
        title: task.title,
        description: task.description,
        color: const Color(0xFF1DB954),
        duration: task.duration,
        assistUrl: task.assistUrl,
        lyricNote: task.lyricNote, // 🔧 追加：既存のLyric Noteを保持
      ));
    }
  } else {
    // ライフドリームアルバムは4つ固定（IDとLyric Noteを保持）
    for (int i = 0; i < widget.tasks.length && i < 4; i++) {
      final task = widget.tasks[i];
      _tasks.add(TaskItem(
        id: task.id, // 🔧 追加：既存のIDを保持
        title: task.title,
        description: task.description,
        color: const Color(0xFF1DB954),
        duration: task.duration,
        assistUrl: task.assistUrl,
        lyricNote: task.lyricNote, // 🔧 追加：既存のLyric Noteを保持
      ));
    }
    
    final defaultTasks = _dataService.getDefaultTasks();
    for (int i = _tasks.length; i < 4; i++) {
      final defaultTask = defaultTasks[i];
      _tasks.add(TaskItem(
        id: defaultTask.id, // 🔧 追加：デフォルトタスクのIDを使用
        title: defaultTask.title,
        description: defaultTask.description,
        color: const Color(0xFF1DB954),
        duration: defaultTask.duration,
        assistUrl: defaultTask.assistUrl,
        lyricNote: defaultTask.lyricNote, // 🔧 追加：デフォルトのLyric Note
      ));
    }
  }
}
  @override
void dispose() {
  _idealSelfController.dispose();
  // 🗑️ 削除：_artistNameController、_todayLyricsController
  
  for (var controller in _taskTitleControllers) {
    controller.dispose();
  }
  // 🗑️ 削除：_taskDescriptionControllers
  for (var controller in _taskUrlControllers) {
    controller.dispose();
  }
  
  super.dispose();
}

  Future<void> _selectImageFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      
      final source = await _showImageSourceDialog();
      if (source == null) return;
      
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
      );
      
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _imageBytes = bytes;
          _albumImage = null;
          _hasImageChanged = true;
        });
        _showMessage('写真を選択しました', isSuccess: true);
      } else {
        _showMessage('写真の選択がキャンセルされました', isSuccess: false);
      }
    } catch (e) {
      _showMessage('写真の選択に失敗しました: $e', isSuccess: false);
    }
  }

  Future<ImageSource?> _showImageSourceDialog() async {
    return await showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Text(
            '写真を選択',
            style: TextStyle(color: Colors.white, fontFamily: 'Hiragino Sans'),
          ),
          content: const Text(
            '写真の取得方法を選択してください',
            style: TextStyle(color: Colors.white70, fontFamily: 'Hiragino Sans'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'キャンセル',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(ImageSource.camera),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.camera_alt, color: Color(0xFF1DB954), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'カメラ',
                    style: TextStyle(color: Color(0xFF1DB954)),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(ImageSource.gallery),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.photo_library, color: Color(0xFF1DB954), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'ギャラリー',
                    style: TextStyle(color: Color(0xFF1DB954)),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _removeImage() {
    setState(() {
      _albumImage = null;
      _imageBytes = null;
      _hasImageChanged = true;
    });
    _showMessage('画像を削除しました', isSuccess: true);
  }

  void _showMessage(String message, {required bool isSuccess}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Text(
              message,
              style: const TextStyle(fontFamily: 'Hiragino Sans'),
            ),
          ],
        ),
        backgroundColor: isSuccess ? const Color(0xFF1DB954) : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Future<void> _saveSettings() async {
  setState(() {
    _isLoading = true;
  });

  try {
    // タスクデータを更新
    for (int i = 0; i < _tasks.length; i++) {
      _tasks[i] = TaskItem(
        id: _tasks[i].id, // 🔧 追加：既存のIDを保持
        title: _taskTitleControllers[i].text.trim().isEmpty 
            ? 'タスク${i + 1}' 
            : _taskTitleControllers[i].text,
        description: '',
        color: const Color(0xFF1DB954),
        duration: _tasks[i].duration,
        assistUrl: _taskUrlControllers[i].text.trim().isEmpty 
            ? null 
            : _taskUrlControllers[i].text.trim(),
        lyricNote: _tasks[i].lyricNote, // 🔧 追加：既存のLyric Noteを保持
      );
    }

    // 🔧 修正：シングルアルバムとドリームアルバムで保存先を分岐
    if (!widget.isEditingLifeDream && widget.albumId != null) {
      // シングルアルバムの場合
      final updatedAlbum = SingleAlbum(
        id: widget.albumId!,
        albumName: _idealSelfController.text,
        albumCoverImage: _hasImageChanged ? _imageBytes : widget.albumCoverImage,
        tasks: _tasks,
        createdAt: DateTime.now(),
      );
      
      await _dataService.saveSingleAlbum(updatedAlbum);
      
      if (mounted) {
        _showMessage('「${updatedAlbum.albumName}」を更新しました', isSuccess: true);
        
        final result = {
          'idealSelf': _idealSelfController.text,
          'artistName': widget.artistName,
          'todayLyrics': widget.todayLyrics,
          'tasks': _tasks,
          'albumImage': null,
          'imageBytes': _imageBytes,
          'hasImageChanged': _hasImageChanged,
        };
        
        if (widget.onSave != null) {
          widget.onSave!(result);
        } else {
          Navigator.pop(context, result);
        }
      }
    } else {
      // ドリームアルバムの場合（既存の処理）
      final data = {
        'idealSelf': _idealSelfController.text,
        'artistName': widget.artistName,
        'todayLyrics': widget.todayLyrics,
        'tasks': _tasks.map((task) => task.toJson()).toList(),
        'imageBytes': _imageBytes,
      };

      await _dataService.saveUserData(data);
      
      if (mounted) {
        _showMessage('設定を保存しました', isSuccess: true);
        
        final result = {
          'idealSelf': _idealSelfController.text,
          'artistName': widget.artistName,
          'todayLyrics': widget.todayLyrics,
          'tasks': _tasks,
          'albumImage': _albumImage,
          'imageBytes': _imageBytes,
          'hasImageChanged': _hasImageChanged,
        };
        
        if (widget.onSave != null) {
          widget.onSave!(result);
        } else {
          Navigator.pop(context, result);
        }
      }
    }
  } catch (e) {
    if (mounted) {
      _showMessage('保存に失敗しました', isSuccess: false);
    }
    print('❌ 設定保存エラー: $e');
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

  @override
Widget build(BuildContext context) {
  return Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(_dominantColor, Colors.black, 0.3)!,  // 🔧 修正：上部のまま
          Color.lerp(_dominantColor, Colors.black, 0.3)!,  // 🔧 修正：全体に同じ色
        ],
        stops: const [0.0, 1.0],  // 🔧 修正：グラデーションなしで均一に
      ),
    ),
    child: Padding(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
      ),
      child: Column(
        children: [
          _buildHeader(),
          
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    
                    _buildImageSection(),
                    
                    const SizedBox(height: 32),
                    
                    _buildAlbumInfoSection(),
                    
                    const SizedBox(height: 40),
                    
                    _buildTasksSection(),
                    
                    const SizedBox(height: 32),
                    
                    if (!widget.isEditingLifeDream) _buildDeleteSection(),
                    
                    const SizedBox(height: 20),
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

  Widget _buildHeader() {
  return Padding(
    padding: const EdgeInsets.all(20),
    child: SizedBox(
      height: 44,  // 🔧 追加：十分な高さを確保
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 中央のタイトル
          const Center(
            child: Text(
              'アルバム設定',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                fontFamily: 'Hiragino Sans',
              ),
            ),
          ),
          
          // 左側の戻るボタン
          Positioned(
            left: 0,
            top: 0,  // 🔧 追加
            bottom: 0,  // 🔧 追加
            child: GestureDetector(
              onTap: widget.onClose ?? () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                alignment: Alignment.center,  // 🔧 追加
                child: const Icon(
                  Icons.chevron_left,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
          
          // 右側の保存ボタン
          Positioned(
            right: 0,
            top: 0,  // 🔧 追加
            bottom: 0,  // 🔧 追加
            child: GestureDetector(
              onTap: _isLoading ? null : _saveSettings,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                alignment: Alignment.center,  // 🔧 追加
                decoration: BoxDecoration(
                  color: _isLoading 
                      ? Colors.white.withOpacity(0.1)
                      : const Color(0xFF1DB954),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        '保存',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          fontFamily: 'Hiragino Sans',
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
  

  Widget _buildImageSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // 🔧 修正：セクションヘッダー（統一スタイル）
      Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: _dominantColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            widget.isEditingLifeDream ? '理想像の画像' : 'アルバムカバー',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              fontFamily: 'Hiragino Sans',
            ),
          ),
        ],
      ),
      
      const SizedBox(height: 20),
      
      // 画像プレビュー
      Center(
        child: Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _buildImagePreview(),
          ),
        ),
      ),
      
      const SizedBox(height: 20),
      
      // 🔧 修正：写真選択ボタンのみ（削除ボタンと説明文を削除）
      Center(
        child: _buildImageButton(
          onTap: _selectImageFromGallery,
          icon: Icons.photo_library,
          label: '写真を選択',
          color: _dominantColor,
        ),
      ),
      
      // 🗑️ 削除：削除ボタン
      // 🗑️ 削除：説明文
    ],
  );
}

  Widget _buildImagePreview() {
    if (_imageBytes != null) {
      return Image.memory(
        _imageBytes!,
        width: 200,
        height: 200,
        fit: BoxFit.cover,
      );
    } else if (_albumImage != null) {
      return Image.file(
        _albumImage!,
        width: 200,
        height: 200,
        fit: BoxFit.cover,
      );
    } else {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1DB954),
              Color(0xFF1ED760),
              Color(0xFF17A2B8),
            ],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image_outlined,
                size: 48,
                color: Colors.white,
              ),
              SizedBox(height: 12),
              Text(
                '画像なし',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontFamily: 'Hiragino Sans',
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildImageButton({
    required VoidCallback onTap,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                fontFamily: 'Hiragino Sans',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTasksSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // 🔧 修正：セクションヘッダー（枠なし）
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: _dominantColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'タスク設定',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Hiragino Sans',
                ),
              ),
            ],
          ),
          
          // 🆕 追加：シングルアルバムの場合のみタスク追加ボタン
          if (!widget.isEditingLifeDream)
            GestureDetector(
              onTap: _addNewTask,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _dominantColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add,
                      color: _dominantColor,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'タスク追加',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Hiragino Sans',
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      
      const SizedBox(height: 24),
      
      // 🔧 修正：ReorderableListViewでドラッグ対応
      ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _tasks.length,
        onReorder: _onReorderTasks,
        itemBuilder: (context, index) {
          return _buildTaskEditor(index);
        },
      ),
    ],
  );
}
  Widget _buildTaskEditor(int index) {
  return Container(
    key: ValueKey(_tasks[index].id),
    margin: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 🔧 修正：タスクヘッダー（シンプル化）
        Row(
          children: [
            // ドラッグハンドル
            Icon(
              Icons.drag_indicator,
              color: Colors.white.withOpacity(0.5),
              size: 24,
            ),
            const SizedBox(width: 12),
            
            // 🔧 修正：タスク番号削除、タイトルを緑色に
            Expanded(
              child: Text(
                'タスク ${index + 1}',
                style: const TextStyle(
                  color: Color(0xFF1DB954),  // 🔧 修正：緑色
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Hiragino Sans',
                ),
              ),
            ),
            
            // シングルアルバムの場合のみ削除ボタン
            if (!widget.isEditingLifeDream && _tasks.length > 1)
              GestureDetector(
                onTap: () => _removeTask(index),
                child: Icon(
                  Icons.remove_circle_outline,
                  color: Colors.red.withOpacity(0.7),
                  size: 24,
                ),
              ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // 🔧 修正：タイトル（統一スタイル）
        _buildSimpleTaskField(
          label: 'タイトル',
          controller: _taskTitleControllers[index],
          hint: 'タスクのタイトルを入力',
        ),
        
        const SizedBox(height: 16),
        
        // 🔧 修正：URL（統一スタイル）
        _buildSimpleTaskUrlField(
          label: 'URL',
          controller: _taskUrlControllers[index],
          hint: 'https://example.com',
          taskIndex: index,
        ),
        
        const SizedBox(height: 16),
        
        // 🔧 修正：再生時間（統一スタイル）
        _buildSimpleTimeSelection(index),
        
        // 区切り線
        if (index < _tasks.length - 1)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Divider(
              color: Colors.white.withOpacity(0.1),
              thickness: 1,
            ),
          ),
      ],
    ),
  );
}

// 🆕 新規追加メソッド：シンプルなタスクフィールド（統一スタイル）
Widget _buildSimpleTaskField({
  required String label,
  required TextEditingController controller,
  required String hint,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          fontFamily: 'Hiragino Sans',
        ),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: controller,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontFamily: 'Hiragino Sans',
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.3),
            fontSize: 14,
            fontFamily: 'Hiragino Sans',
          ),
          filled: true,
          fillColor: Colors.black.withOpacity(0.3),
          border: OutlineInputBorder(  // 🔧 修正：角を丸く
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
              color: Color(0xFF1DB954),
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
      ),
    ],
  );
}

// 🆕 新規追加メソッド：シンプルなURLフィールド（統一スタイル）
Widget _buildSimpleTaskUrlField({
  required String label,
  required TextEditingController controller,
  required String hint,
  required int taskIndex,
}) {
  final hasUrl = controller.text.trim().isNotEmpty;
  
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'URL',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              fontFamily: 'Hiragino Sans',
            ),
          ),
          if (hasUrl)
            GestureDetector(
              onTap: () {
                setState(() {
                  controller.clear();
                });
                _showMessage('URLをクリアしました', isSuccess: true);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.clear,
                      color: Colors.red.withOpacity(0.8),
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'クリア',
                      style: TextStyle(
                        color: Colors.red.withOpacity(0.8),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 8),
      TextField(
        controller: controller,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontFamily: 'Hiragino Sans',
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.3),
            fontSize: 14,
            fontFamily: 'Hiragino Sans',
          ),
          filled: true,
          fillColor: Colors.black.withOpacity(0.3),
          border: OutlineInputBorder(  // 🔧 修正：角を丸く
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
              color: Color(0xFF1DB954),
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
        keyboardType: TextInputType.url,
        textInputAction: TextInputAction.done,
        onChanged: (value) {
          setState(() {});
        },
      ),
    ],
  );
}

// 🆕 新規追加メソッド：シンプルな時間選択（統一スタイル、イラストなし）
Widget _buildSimpleTimeSelection(int index) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        '再生時間',
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          fontFamily: 'Hiragino Sans',
        ),
      ),
      
      const SizedBox(height: 8),
      
      Row(
        children: [
          _buildDurationButton(index, 1),
          const SizedBox(width: 12),
          _buildDurationButton(index, 3),
          const SizedBox(width: 12),
          _buildDurationButton(index, 5),
        ],
      ),
    ],
  );
}

  Widget _buildDurationButton(int taskIndex, int duration) {
  final isSelected = _tasks[taskIndex].duration == duration;
  const taskColor = Color(0xFF1DB954);
  
  return Expanded(
    child: GestureDetector(
      onTap: () {
        setState(() {
          _tasks[taskIndex] = TaskItem(
            id: _tasks[taskIndex].id, // 🔧 追加：既存のIDを保持
            title: _tasks[taskIndex].title,
            description: _tasks[taskIndex].description,
            color: taskColor,
            duration: duration,
            assistUrl: _tasks[taskIndex].assistUrl,
            lyricNote: _tasks[taskIndex].lyricNote, // 🔧 追加：既存のLyric Noteを保持
          );
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? taskColor : Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '${duration}分',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: 'Hiragino Sans',
          ),
        ),
      ),
    ),
  );
}

  Widget _buildSettingField({
  required String label,
  required TextEditingController controller,
  required String hint,
  int maxLines = 1,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          color: Colors.white.withOpacity(0.9),
          fontSize: 14,
          fontWeight: FontWeight.w500,
          fontFamily: 'Hiragino Sans',
        ),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontFamily: 'Hiragino Sans',
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontFamily: 'Hiragino Sans',
          ),
          filled: true,
          fillColor: Colors.black.withOpacity(0.2),
          border: InputBorder.none,  // 🔧 修正：枠を削除
          enabledBorder: InputBorder.none,  // 🔧 追加
          focusedBorder: UnderlineInputBorder(  // 🔧 修正：フォーカス時は下線のみ
            borderSide: const BorderSide(
              color: Color(0xFF1DB954),
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    ],
  );
}




  Widget _buildDeleteSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // 🔧 修正：セクションヘッダー（枠なし）
      Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            '危険な操作',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              fontFamily: 'Hiragino Sans',
            ),
          ),
        ],
      ),
      
      const SizedBox(height: 20),
      
      Text(
        'このアルバムを削除すると、すべてのデータが完全に削除され、元に戻すことはできません。',
        style: TextStyle(
          color: Colors.white.withOpacity(0.8),
          fontSize: 14,
          height: 1.5,
          fontFamily: 'Hiragino Sans',
        ),
      ),
      
      const SizedBox(height: 20),
      
      Center(
        child: GestureDetector(
          onTap: _showDeleteConfirmDialog,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.delete_forever,
                  color: Colors.red,
                  size: 22,
                ),
                SizedBox(width: 12),
                Text(
                  'このアルバムを削除',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Hiragino Sans',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

// 🆕 新規追加メソッド：タスクの順序変更
void _onReorderTasks(int oldIndex, int newIndex) {
  setState(() {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    
    final task = _tasks.removeAt(oldIndex);
    _tasks.insert(newIndex, task);
    
    final titleController = _taskTitleControllers.removeAt(oldIndex);
    _taskTitleControllers.insert(newIndex, titleController);
    
    final urlController = _taskUrlControllers.removeAt(oldIndex);
    _taskUrlControllers.insert(newIndex, urlController);
  });
}

void _addNewTask() {
  if (_tasks.length >= 10) {
    _showMessage('タスクは最大10個までです', isSuccess: false);
    return;
  }
  
  setState(() {
    // 🔧 修正：新しいタスクに一意のIDを生成
    final newTaskId = 'task_${DateTime.now().millisecondsSinceEpoch}_${_tasks.length}';
    
    _tasks.add(TaskItem(
      id: newTaskId, // 🔧 追加：一意のIDを設定
      title: 'タスク${_tasks.length + 1}',
      description: '',
      color: const Color(0xFF1DB954),
      duration: 3,
      assistUrl: null,
      lyricNote: null, // 🔧 追加：初期値null
    ));
    
    _taskTitleControllers.add(TextEditingController(text: 'タスク${_tasks.length}'));
    _taskUrlControllers.add(TextEditingController(text: ''));
  });
  
  _showMessage('タスクを追加しました', isSuccess: true);
}

// 🆕 新規追加メソッド：タスクを削除
void _removeTask(int index) {
  if (_tasks.length <= 1) {
    _showMessage('タスクは最低1つ必要です', isSuccess: false);
    return;
  }
  
  setState(() {
    _tasks.removeAt(index);
    _taskTitleControllers[index].dispose();
    _taskTitleControllers.removeAt(index);
    _taskUrlControllers[index].dispose();
    _taskUrlControllers.removeAt(index);
  });
  
  _showMessage('タスクを削除しました', isSuccess: true);
}

// 🆕 新規追加メソッド：削除確認ダイアログ
void _showDeleteConfirmDialog() {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_rounded,
                color: Colors.red,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'アルバムを削除',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Hiragino Sans',
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '「${_idealSelfController.text}」を削除してもよろしいですか？',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                fontFamily: 'Hiragino Sans',
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.red.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: const Text(
                '⚠️ この操作は取り消せません\n\n・アルバムの全データが削除されます\n・タスク履歴も削除されます\n・ホーム画面から消えます',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.5,
                  fontFamily: 'Hiragino Sans',
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'キャンセル',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                fontFamily: 'Hiragino Sans',
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteAlbum();
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.red.withOpacity(0.2),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              '削除する',
              style: TextStyle(
                color: Colors.red,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'Hiragino Sans',
              ),
            ),
          ),
        ],
      );
    },
  );
}

// 🆕 新規追加メソッド：アルバム削除処理
void _deleteAlbum() async {
  if (widget.onDelete != null) {
    // 親ウィジェットの削除処理を呼び出し
    widget.onDelete!();
  } else {
    // フォールバック：直接削除処理
    if (widget.albumId != null) {
      try {
        await _dataService.deleteSingleAlbum(widget.albumId!);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '「${_idealSelfController.text}」を削除しました',
                      style: const TextStyle(fontFamily: 'Hiragino Sans'),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
          
          // 設定画面を閉じる
          if (widget.onClose != null) {
            widget.onClose!();
          } else {
            Navigator.of(context).pop();
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('削除に失敗しました'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

  // 🆕 新規追加メソッド：アルバム画像から色を抽出
Future<void> _extractColorsFromImage() async {
  if (_isExtractingColors) return;
  
  setState(() {
    _isExtractingColors = true;
  });
  
  try {
    ImageProvider? imageProvider;
    
    // 画像ソースを決定
    if (_imageBytes != null) {
      imageProvider = MemoryImage(_imageBytes!);
    } else if (_albumImage != null && _albumImage!.existsSync()) {
      imageProvider = FileImage(_albumImage!);
    }
    
    if (imageProvider != null) {
      final PaletteGenerator paletteGenerator = await PaletteGenerator.fromImageProvider(
        imageProvider,
        size: const Size(200, 200),
        maximumColorCount: 16,
      );
      
      if (mounted) {
        Color selectedColor = const Color(0xFF2D1B69); // フォールバック
        
        // 彩度をチェックする関数
        double getSaturation(Color color) {
          final r = color.red / 255.0;
          final g = color.green / 255.0;
          final b = color.blue / 255.0;
          
          final max = [r, g, b].reduce((a, b) => a > b ? a : b);
          final min = [r, g, b].reduce((a, b) => a < b ? a : b);
          
          if (max == 0) return 0;
          return (max - min) / max;
        }
        
        // 色をスコアリング
        double scoreColor(PaletteColor paletteColor) {
          final color = paletteColor.color;
          final population = paletteColor.population;
          final saturation = getSaturation(color);
          final luminance = color.computeLuminance();
          
          double score = 0;
          
          if (population < 500) {
            score -= 300;
          }
          
          score += saturation * 100;
          
          if (saturation > 0.15) {
            score += (population / 1000) * 100;
          }
          
          if (luminance > 0.15 && luminance < 0.7) {
            score += 30;
          }
          
          if (saturation < 0.15) {
            score -= 200;
          }
          
          if (luminance > 0.8) {
            score -= 100;
          }
          
          return score;
        }
        
        // 全ての色をスコアリングして最適な色を選択
        final List<PaletteColor> allColors = [
          if (paletteGenerator.vibrantColor != null) paletteGenerator.vibrantColor!,
          if (paletteGenerator.lightVibrantColor != null) paletteGenerator.lightVibrantColor!,
          if (paletteGenerator.darkVibrantColor != null) paletteGenerator.darkVibrantColor!,
          if (paletteGenerator.mutedColor != null) paletteGenerator.mutedColor!,
          if (paletteGenerator.lightMutedColor != null) paletteGenerator.lightMutedColor!,
          if (paletteGenerator.darkMutedColor != null) paletteGenerator.darkMutedColor!,
          if (paletteGenerator.dominantColor != null) paletteGenerator.dominantColor!,
        ];
        
        if (allColors.isNotEmpty) {
          PaletteColor bestColor = allColors[0];
          double bestScore = scoreColor(bestColor);
          
          for (final paletteColor in allColors) {
            final score = scoreColor(paletteColor);
            if (score > bestScore) {
              bestScore = score;
              bestColor = paletteColor;
            }
          }
          
          selectedColor = bestColor.color;
        }
        
        setState(() {
          _dominantColor = selectedColor;
          _accentColor = Colors.black;
          _isExtractingColors = false;
        });
      }
    } else {
      setState(() {
        _dominantColor = const Color(0xFF2D1B69);
        _accentColor = Colors.black;
        _isExtractingColors = false;
      });
    }
  } catch (e) {
    print('❌ 色抽出エラー: $e');
    setState(() {
      _dominantColor = const Color(0xFF2D1B69);
      _accentColor = Colors.black;
      _isExtractingColors = false;
    });
  }
}



// 🆕 新規追加メソッド：アルバム情報セクション
Widget _buildAlbumInfoSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // 🔧 修正：セクションヘッダー（統一スタイル）
      Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: _dominantColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'アルバム名',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              fontFamily: 'Hiragino Sans',
            ),
          ),
        ],
      ),
      
      const SizedBox(height: 20),
      
      // 入力フィールド
      TextField(
        controller: _idealSelfController,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontFamily: 'Hiragino Sans',
        ),
        decoration: InputDecoration(
          hintText: 'アルバム名を入力',
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontFamily: 'Hiragino Sans',
          ),
          filled: true,
          fillColor: Colors.black.withOpacity(0.2),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
              color: Color(0xFF1DB954),
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    ],
  );
}




}