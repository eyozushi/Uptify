// screens/single_album_create_screen.dart - 設定画面風デザイン版
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import '../models/task_item.dart';
import 'package:palette_generator/palette_generator.dart';

class SingleAlbumCreateScreen extends StatefulWidget {
  final VoidCallback? onClose;
  final Function(Map<String, dynamic>)? onSave;

  const SingleAlbumCreateScreen({
    super.key,
    this.onClose,
    this.onSave,
  });

  @override
  State<SingleAlbumCreateScreen> createState() => _SingleAlbumCreateScreenState();
}

class _SingleAlbumCreateScreenState extends State<SingleAlbumCreateScreen> {
  final _albumNameController = TextEditingController();
  Uint8List? _albumCoverImage;
  List<TaskItem> _tasks = [];
  List<TextEditingController> _taskControllers = [];
  
  // 🆕 背景色用のフィールド
  Color _dominantColor = Colors.black;
Color _accentColor = Colors.black;
  bool _isExtractingColors = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _addNewTask();
  }

  @override
  void dispose() {
    _albumNameController.dispose();
    for (var controller in _taskControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _resetForm() {
    setState(() {
      // アルバム名をクリア
      _albumNameController.clear();
      
      // 画像をクリア
      _albumCoverImage = null;
      
      // 背景色をデフォルトに戻す
      _dominantColor = const Color(0xFF2D1B69);
      
      // タスクをクリア
      for (var controller in _taskControllers) {
        controller.dispose();
      }
      _tasks.clear();
      _taskControllers.clear();
      
      // 初期タスクを1つ追加
      _addNewTask();
    });
    
    _showMessage('Form reset', isSuccess: true);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    
    final source = await _showImageSourceDialog();
    if (source == null) return;
    
    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 1000,
      maxHeight: 1000,
      imageQuality: 85,
    );
    
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _albumCoverImage = bytes;
      });
      
      // 色を抽出
      _extractColorsFromImage();
      
      _showMessage('Photo selected', isSuccess: true);
    }
  }

  Future<ImageSource?> _showImageSourceDialog() async {
    return await showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF282828),
          title: const Text(
            'Select Photo',
            style: TextStyle(color: Colors.white, fontFamily: 'Hiragino Sans'),
          ),
          content: const Text(
            'Choose how to get photo',
            style: TextStyle(color: Colors.white70, fontFamily: 'Hiragino Sans'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
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
                    'Camera',
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
                    'Gallery',
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

  // 🆕 新規追加メソッド：画像から色を抽出
  Future<void> _extractColorsFromImage() async {
    if (_isExtractingColors) return;
    
    setState(() {
      _isExtractingColors = true;
    });
    
    try {
      if (_albumCoverImage != null) {
        final imageProvider = MemoryImage(_albumCoverImage!);
        
        final PaletteGenerator paletteGenerator = await PaletteGenerator.fromImageProvider(
          imageProvider,
          size: const Size(200, 200),
          maximumColorCount: 16,
        );
        
        if (mounted) {
          Color selectedColor = const Color(0xFF2D1B69);
          
          // 彩度チェック関数
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
            
            if (population < 500) score -= 300;
            score += saturation * 100;
            if (saturation > 0.15) score += (population / 1000) * 100;
            if (luminance > 0.15 && luminance < 0.7) score += 30;
            if (saturation < 0.15) score -= 200;
            if (luminance > 0.8) score -= 100;
            
            return score;
          }
          
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
            _isExtractingColors = false;
          });
        }
      }
    } catch (e) {
      print('❌ 色抽出エラー: $e');
      setState(() {
        _dominantColor = const Color(0xFF2D1B69);
        _isExtractingColors = false;
      });
    }
  }

  void _addNewTask() {
    setState(() {
      final newTask = TaskItem(
        title: '',
        description: '',
        color: const Color(0xFF1DB954),
        duration: 3,
      );
      _tasks.add(newTask);
      _taskControllers.add(TextEditingController());
    });
  }

  void _removeTask(int index) {
    if (_tasks.length > 1) {
      setState(() {
        _tasks.removeAt(index);
        _taskControllers[index].dispose();
        _taskControllers.removeAt(index);
      });
    }
  }

  void _updateTask(int index, TaskItem updatedTask) {
    setState(() {
      _tasks[index] = updatedTask;
    });
  }

  void _saveAlbum() async {
    if (_albumNameController.text.trim().isEmpty) {
      _showMessage('Please enter the album name', isSuccess: false);
      return;
    }

    bool hasValidTask = false;
    for (int i = 0; i < _tasks.length; i++) {
      final title = _taskControllers[i].text.trim();
      if (title.isNotEmpty) {
        hasValidTask = true;
        break;
      }
    }

    if (!hasValidTask) {
      _showMessage('少なくとも1つのタスクに名前を入力してください', isSuccess: false);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // タスクデータを更新
      for (int i = 0; i < _tasks.length; i++) {
        final title = _taskControllers[i].text.trim();
        if (title.isNotEmpty) {
          _tasks[i] = TaskItem(
            id: _tasks[i].id,
            title: title,
            description: '',
            color: const Color(0xFF1DB954),
            duration: _tasks[i].duration,
          );
        }
      }

      final validTasks = _tasks.where((task) => task.title.trim().isNotEmpty).toList();

      final albumData = {
        'albumName': _albumNameController.text.trim(),
        'albumCoverImage': _albumCoverImage,
        'tasks': validTasks,
        'createdAt': DateTime.now().toIso8601String(),
      };

      if (widget.onSave != null) {
        widget.onSave!(albumData);
      }
    } catch (e) {
      _showMessage('Failed to save', isSuccess: false);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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

  void _reorderTasks(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final TaskItem item = _tasks.removeAt(oldIndex);
      _tasks.insert(newIndex, item);
      
      final TextEditingController controller = _taskControllers.removeAt(oldIndex);
      _taskControllers.insert(newIndex, controller);
    });
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.black,
    body: SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔧 修正：ヘッダー（オーバーフロー対策）
            Container(
              height: 60,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 🔧 修正：Expandedでラップしてスペースを確保
                  Expanded(
                    child: Text(
                      'Release',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
            letterSpacing: -0.5,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Hiragino Sans',
                      ),
                      maxLines: 1,  // 🔧 追加：1行に制限
                      overflow: TextOverflow.ellipsis,  // 🔧 追加：はみ出し対策
                    ),
                  ),
                  
                  const SizedBox(width: 12),  // 🔧 追加：余白を確保
                  
                  Row(
                    mainAxisSize: MainAxisSize.min,  // 🔧 追加：必要最小限のサイズ
                    children: [
                      // リセットボタン
                      GestureDetector(
                        onTap: () {
                          _resetForm();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          child: const Icon(
                            Icons.refresh,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      
                      // リリースボタン
                      GestureDetector(
                        onTap: _isLoading ? null : _saveAlbum,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
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
                                  'Release',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Hiragino Sans',
                                  ),
                                ),
  ),
),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
            
            _buildImageSection(),
            
            const SizedBox(height: 32),
            
            _buildAlbumInfoSection(),
            
            const SizedBox(height: 40),
            
            _buildTasksSection(),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    ),
  );
}


  // 既存メソッドの変更
Widget _buildImageSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              // 🔧 修正：カラーバーを緑に固定
              color: const Color(0xFF1DB954),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Album Cover',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
            letterSpacing: -0.2,
              fontWeight: FontWeight.w600,
              fontFamily: 'Hiragino Sans',
            ),
          ),
        ],
      ),
      
      const SizedBox(height: 20),
      
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
      
      Center(
        child: _buildImageButton(
          onTap: _pickImage,
          icon: Icons.photo_library,
          label: 'Select Photo',
          // 🔧 修正：グレーに変更
          color: const Color(0xFF282828),
        ),
      ),
    ],
  );
}

  // 🆕 新規追加メソッド：画像プレビュー
  Widget _buildImagePreview() {
    if (_albumCoverImage != null) {
      return Image.memory(
        _albumCoverImage!,
        width: 200,
        height: 200,
        fit: BoxFit.cover,
      );
    } else {
      return Container(
        color: const Color(0xFF1DB954),  // 🔧 修正：緑単色に変更
        child: const Center(
          child: Icon(
            Icons.image_outlined,
            size: 48,
            color: Colors.white,
          ),
        ),
      );
    }
  }

  // 🆕 新規追加メソッド：画像ボタン
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

  // 🆕 新規追加メソッド：アルバム情報セクション
  // 既存メソッドの変更
Widget _buildAlbumInfoSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              // 🔧 修正：カラーバーを緑に固定
              color: const Color(0xFF1DB954),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Album Name',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
            letterSpacing: -0.2,
              fontWeight: FontWeight.w600,
              fontFamily: 'Hiragino Sans',
            ),
          ),
        ],
      ),
      
      const SizedBox(height: 20),
      
      TextField(
        controller: _albumNameController,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontFamily: 'Hiragino Sans',
        ),
        decoration: InputDecoration(
          hintText: 'Enter album name',
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontFamily: 'Hiragino Sans',
          ),
          filled: true,
          fillColor: const Color(0xFF282828),  // 🔧 修正：グレーに変更
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

  Widget _buildTasksSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: const Color(0xFF1DB954),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Task Settings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              letterSpacing: -0.2,
              fontWeight: FontWeight.w600,
              fontFamily: 'Hiragino Sans',
            ),
          ),
        ],
      ),
      
      const SizedBox(height: 24),
      
      ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _tasks.length,
        onReorder: _reorderTasks,
        itemBuilder: (context, index) {
          return _buildTaskEditor(index);
        },
      ),
      
      const SizedBox(height: 24),
      
      Center(
        child: GestureDetector(
          onTap: _addNewTask,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1DB954),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.add,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Add Task',
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
      ),
    ],
  );
}

  // 🆕 新規追加メソッド：タスクエディター
  Widget _buildTaskEditor(int index) {
    return Container(
      key: ValueKey(_tasks[index].id),
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.drag_indicator,
                color: Colors.white.withOpacity(0.5),
                size: 24,
              ),
              const SizedBox(width: 12),
              
              Expanded(
                child: Text(
                  'Task ${index + 1}',
                  style: const TextStyle(
                    color: Color(0xFF1DB954),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Hiragino Sans',
                  ),
                ),
              ),
              
              if (_tasks.length > 1)
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
          
          _buildSimpleTaskField(
            label: 'Title',
            controller: _taskControllers[index],
            hint: 'Enter task title',
            onChanged: (value) {
              _updateTask(index, _tasks[index].copyWith(title: value));
            },
          ),
          
          const SizedBox(height: 16),
          
          _buildSimpleTimeSelection(index),
          
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

  // 🆕 新規追加メソッド：シンプルなタスクフィールド
  Widget _buildSimpleTaskField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required Function(String) onChanged,
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
          onChanged: onChanged,
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
            fillColor: const Color(0xFF282828),  // 🔧 修正：グレーに変更
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
              horizontal: 12,
              vertical: 10,
            ),
          ),
        ),
      ],
    );
  }

  // 🆕 新規追加メソッド：シンプルな時間選択
  Widget _buildSimpleTimeSelection(int index) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Duration',
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

  // 🆕 新規追加メソッド：時間ボタン
  Widget _buildDurationButton(int taskIndex, int duration) {
    final isSelected = _tasks[taskIndex].duration == duration;
    const taskColor = Color(0xFF1DB954);
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _tasks[taskIndex] = _tasks[taskIndex].copyWith(duration: duration);
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? taskColor : Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${duration}min',
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
}