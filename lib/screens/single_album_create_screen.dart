// screens/single_album_create_screen.dart - 最終版
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import '../models/task_item.dart';

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

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _albumCoverImage = bytes;
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

  void _saveAlbum() {
    if (_albumNameController.text.trim().isEmpty) {
      _showError('アルバム名を入力してください');
      return;
    }

    bool hasValidTask = false;
    for (var task in _tasks) {
      if (task.title.trim().isNotEmpty) {
        hasValidTask = true;
        break;
      }
    }

    if (!hasValidTask) {
      _showError('少なくとも1つのタスクに名前を入力してください');
      return;
    }

    final validTasks = _tasks.where((task) => task.title.trim().isNotEmpty).toList();

    final albumData = {
      'albumName': _albumNameController.text.trim(),
      'albumCoverImage': _albumCoverImage,
      'tasks': validTasks,
      'createdAt': DateTime.now().toIso8601String(),
    };

    widget.onSave?.call(albumData);
  }

  void _resetForm() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text(
            'リセットしますか？',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              fontFamily: 'Hiragino Sans',
            ),
          ),
          content: const Text(
            '入力した内容はすべて削除されます。\nこの操作は取り消せません。',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontFamily: 'Hiragino Sans',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'キャンセル',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Hiragino Sans',
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _performReset();
              },
              child: const Text(
                'リセット',
                style: TextStyle(
                  color: Colors.red,
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

  void _performReset() {
    setState(() {
      _albumNameController.clear();
      _albumCoverImage = null;
      _tasks.clear();
      for (var controller in _taskControllers) {
        controller.dispose();
      }
      _taskControllers.clear();
      _addNewTask();
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'リセットしました',
          style: TextStyle(fontFamily: 'Hiragino Sans'),
        ),
        backgroundColor: Color(0xFF1DB954),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'Hiragino Sans'),
        ),
        backgroundColor: Colors.red,
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
    return Material(
      color: Colors.transparent,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ヘッダー - ホーム・チャート画面と完全に同じ構造
            // ヘッダー - ホーム・チャート画面と完全に同じ構造
Container(
  height: 60,
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      const Text(
        'アルバム作成',
        style: TextStyle(
          color: Colors.white,
          fontSize: 32,
          fontWeight: FontWeight.bold,
          fontFamily: 'Hiragino Sans',
        ),
      ),
      Row(
        children: [
          GestureDetector(
            onTap: () {
              _resetForm();
            },
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),  // 🆕 色を統一
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.refresh,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () {
              _saveAlbum();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),  // 🆕 テキスト用にpaddingを変更
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),  // 🆕 色を統一
                borderRadius: BorderRadius.circular(24),  // 🆕 円形から角丸長方形に
              ),
              child: const Text(
                'リリース',  // 🆕 アイコンからテキストに変更
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
            
            const SizedBox(height: 20),
            
            // アルバムカバー
            _buildAlbumCover(),
            
            const SizedBox(height: 30),
            
            // アルバム名
            _buildAlbumNameInput(),
            
            const SizedBox(height: 30),
            
            // タスクリスト
            _buildTaskList(),
            
            const SizedBox(height: 20),
            
            // タスク追加ボタン
            _buildAddTaskButton(),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildAlbumCover() {
  return Center(
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _pickImage();
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 200,
          height: 200,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _albumCoverImage != null
                ? Image.memory(
                    _albumCoverImage!,
                    fit: BoxFit.cover,
                  )
                : Container(
                    color: const Color(0xFF1E1E1E),  // 🆕 色を統一
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate,
                          color: Colors.white,
                          size: 48,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'ジャケット写真を\n選択してください',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontFamily: 'Hiragino Sans',
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildAlbumNameInput() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'アルバム名',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          fontFamily: 'Hiragino Sans',
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _albumNameController,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontFamily: 'Hiragino Sans',
        ),
        decoration: InputDecoration(
          hintText: '例: 朝のルーティーン',
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontFamily: 'Hiragino Sans',
          ),
          filled: true,
          fillColor: const Color(0xFF1E1E1E),  // 🆕 色を統一
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
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

  Widget _buildTaskList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'タスク',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            fontFamily: 'Hiragino Sans',
          ),
        ),
        const SizedBox(height: 12),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _tasks.length,
          onReorder: _reorderTasks,
          itemBuilder: (context, index) {
            return _buildTaskItem(index);
          },
        ),
      ],
    );
  }

  Widget _buildTaskItem(int index) {
  final task = _tasks[index];
  final titleController = _taskControllers[index];
  
  return Container(
    key: Key('task_$index'),
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF1E1E1E),  // 🆕 色を統一
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Icon(
              Icons.drag_handle,
              color: Colors.white.withOpacity(0.5),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: titleController,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontFamily: 'Hiragino Sans',
                ),
                decoration: InputDecoration(
                  hintText: 'タスク名',
                  hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontFamily: 'Hiragino Sans',
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (value) {
                  _updateTask(index, task.copyWith(title: value));
                },
              ),
            ),
            if (_tasks.length > 1)
              IconButton(
                onPressed: () {
                  _removeTask(index);
                },
                icon: Icon(
                  Icons.close,
                  color: Colors.white.withOpacity(0.7),
                  size: 20,
                ),
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const SizedBox(width: 32),
            const Text(
              '時間: ',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontFamily: 'Hiragino Sans',
              ),
            ),
            IconButton(
              onPressed: () {
                if (task.duration > 1) {
                  _updateTask(index, task.copyWith(duration: task.duration - 1));
                }
              },
              icon: const Icon(Icons.remove, color: Colors.white, size: 16),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.1),
                fixedSize: const Size(30, 30),
                padding: EdgeInsets.zero,
              ),
            ),
            Container(
              width: 60,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                '${task.duration}分',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Hiragino Sans',
                ),
              ),
            ),
            IconButton(
              onPressed: () {
                if (task.duration < 60) {
                  _updateTask(index, task.copyWith(duration: task.duration + 1));
                }
              },
              icon: const Icon(Icons.add, color: Colors.white, size: 16),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.1),
                fixedSize: const Size(30, 30),
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

  Widget _buildAddTaskButton() {
    return Center(
      child: ElevatedButton.icon(
        onPressed: () {
          _addNewTask();
        },
        icon: const Icon(
          Icons.add,
          color: Colors.black,
          size: 16,
        ),
        label: const Text(
          'タスクを追加',
          style: TextStyle(
            color: Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: 'Hiragino Sans',
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          elevation: 2,
        ),
      ),
    );
  }
}