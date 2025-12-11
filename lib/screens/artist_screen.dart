// artist_screen.dart - スクロール覆い被さり修正版
import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../models/task_item.dart';
import '../models/single_album.dart';
import '../services/data_service.dart';
import '../services/task_completion_service.dart';
import '../services/achievement_service.dart'; // 🆕 追加

class ArtistScreen extends StatefulWidget {
  final String artistName;
  final Uint8List? profileImageBytes;
  final Uint8List? lifeDreamAlbumCoverImage;
  final List<TaskItem> tasks;
  final List<SingleAlbum> singleAlbums;
  final VoidCallback? onClose;
  final Function(int taskIndex)? onPlayTask;
  final Function(SingleAlbum album)? onNavigateToAlbumDetail;
  final Function(SingleAlbum album, int taskIndex)? onPlaySingleAlbumTask;
  final VoidCallback? onNavigateToLifeDreamAlbumDetail; // 🆕 追加

  const ArtistScreen({
    super.key,
    required this.artistName,
    this.profileImageBytes,
    this.lifeDreamAlbumCoverImage,
    required this.tasks,
    required this.singleAlbums,
    this.onClose,
    this.onPlayTask,
    this.onNavigateToAlbumDetail,
    this.onPlaySingleAlbumTask,
    this.onNavigateToLifeDreamAlbumDetail, // 🆕 追加
  });

  @override
  State<ArtistScreen> createState() => _ArtistScreenState();
}

class _ArtistScreenState extends State<ArtistScreen> {
  final DataService _dataService = DataService();
  final TaskCompletionService _taskCompletionService = TaskCompletionService();
  final AchievementService _achievementService = AchievementService();
  
  int _totalTasksCompleted = 0;
  List<Map<String, dynamic>> _taskRanking = [];
  bool _isLoading = true;

  @override
void initState() {
  super.initState();
  // 🔧 修正：即座にデータ読み込み開始
  _loadArtistData();
}

  Future<void> _loadArtistData() async {
  try {
    // 累計完了回数を取得
    final totalCompleted = await _taskCompletionService.getTotalCompletedTasks();
    
    // 全完了記録を一度だけ取得
    final allCompletions = await _achievementService.loadTaskCompletions();
    
    List<Map<String, dynamic>> taskStats = [];
    
    // ライフドリームアルバムのタスクを追加
    print('📊 ライフドリームアルバムのタスク数: ${widget.tasks.length}');
    for (final task in widget.tasks) {
      final taskCompletions = allCompletions.where((c) => c.taskId == task.id && c.wasSuccessful).length;
      
      taskStats.add({
        'task': task,
        'completions': taskCompletions,
      });
      print('  - ${task.title}: $taskCompletions');
    }
    
    // 🔧 修正：シングルアルバムがあれば追加（なくてもエラーにしない）
    if (widget.singleAlbums.isNotEmpty) {
      print('📊 シングルアルバム数: ${widget.singleAlbums.length}');
      for (final album in widget.singleAlbums) {
        print('  - アルバム: ${album.albumName}, タスク数: ${album.tasks.length}');
        for (final task in album.tasks) {
          final taskCompletions = allCompletions.where((c) => c.taskId == task.id && c.wasSuccessful).length;
          
          taskStats.add({
            'task': task,
            'completions': taskCompletions,
          });
          print('    - ${task.title}: $taskCompletions');
        }
      }
    } else {
      print('📊 シングルアルバムなし - ライフドリームアルバムのみでランキング表示');
    }
    
    print('📊 全タスク統計数: ${taskStats.length}');
    
    // 完了回数でソートしてランキング作成
    taskStats.sort((a, b) => (b['completions'] as int).compareTo(a['completions'] as int));
    
    setState(() {
      _totalTasksCompleted = totalCompleted;
      _taskRanking = taskStats.take(5).toList(); // 上位5位
      _isLoading = false;
    });
    
    print('📊 ランキング表示数: ${_taskRanking.length}');
  } catch (e) {
    print('❌ アーティストデータ読み込みエラー: $e');
    setState(() {
      _isLoading = false;
    });
  }
}
  Widget _buildProfileImage() {
  final screenHeight = MediaQuery.of(context).size.height;
  final profileHeight = screenHeight * 0.5; // 画面の半分
  
  return SizedBox(
    width: double.infinity,
    height: profileHeight,
    child: Stack(
      children: [
        // 顔写真
        Positioned.fill(
          child: widget.profileImageBytes != null
              ? Image.memory(
                  widget.profileImageBytes!,
                  width: double.infinity,
                  height: profileHeight,
                  fit: BoxFit.cover,
                )
              : Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF8B5CF6),
                        Color(0xFF06B6D4),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.person,
                      color: Colors.white,
                      size: profileHeight * 0.3,
                    ),
                  ),
                ),
        ),
        
        // 下部グラデーション影
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: profileHeight * 0.4, // 画像の下部40%に影
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Color(0x40000000), // 薄い黒
                  Color(0x80000000), // 中程度の黒
                  Color(0xCC000000), // 濃い黒
                ],
                stops: [0.0, 0.3, 0.7, 1.0],
              ),
            ),
          ),
        ),
        
        // 🔧 修正：アーティスト名（影を削除）
        Positioned(
          left: 20,
          bottom: 20,
          right: 20,
          child: Text(
            widget.artistName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w900,
              fontFamily: 'Hiragino Sans',
              // 🔧 修正：shadowsプロパティを削除
            ),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildTaskRanking() {
  if (_isLoading) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: CircularProgressIndicator(
          color: Color(0xFF1DB954),
        ),
      ),
    );
  }

  // 🔧 追加：ランキングが空の場合の表示
  if (_taskRanking.isEmpty) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.music_note,
              size: 48,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Play tasks to see your ranking!',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 16,
                fontWeight: FontWeight.w500,
                fontFamily: 'Hiragino Sans',
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.only(left: 20, bottom: 12),
        child: Text(
          'Top Tasks',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            letterSpacing: -0.3,
            fontWeight: FontWeight.w900,
            fontFamily: 'Hiragino Sans',
          ),
        ),
      ),
      ..._taskRanking.asMap().entries.map((entry) {
        final index = entry.key;
        final data = entry.value;
        final task = data['task'] as TaskItem;
        final completions = data['completions'] as int;
        
        return _buildRankingItem(
          rank: index + 1,
          task: task,
          completions: completions,
        );
      }).toList(),
    ],
  );
}

  /// タスクが所属するアルバムのジャケット画像を取得
Widget _getAlbumCoverForTask(TaskItem task) {
  // シングルアルバムのタスクかチェック
  for (final album in widget.singleAlbums) {
    if (album.tasks.any((t) => t.id == task.id)) {
      if (album.albumCoverImage != null) {
        return Image.memory(
          album.albumCoverImage!,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
        );
      }
      break;
    }
  }
  
  // 🔧 修正：ライフドリームアルバムのジャケット画像
  if (widget.lifeDreamAlbumCoverImage != null) {
    return Image.memory(
      widget.lifeDreamAlbumCoverImage!,
      width: 48,
      height: 48,
      fit: BoxFit.cover,
    );
  }
  
  // デフォルト画像
  return Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF1DB954),
          Color(0xFF1ED760),
        ],
      ),
    ),
    child: const Center(
      child: Icon(
        Icons.album,
        color: Colors.white,
        size: 24,
      ),
    ),
  );
}

  Widget _buildRankingItem({
  required int rank,
  required TaskItem task,
  required int completions,
}) {
  return GestureDetector(
    onTap: () {
      // 🔧 修正：ライフドリームアルバムのタスクかチェック
      final lifeDreamTaskIndex = widget.tasks.indexWhere((t) => t.id == task.id);
      
      if (lifeDreamTaskIndex >= 0) {
        // ライフドリームアルバムのタスク
        if (widget.onPlayTask != null) {
          widget.onPlayTask!(lifeDreamTaskIndex);
        }
      } else {
        // 🔧 修正：シングルアルバムのタスク → PlayerScreenに移動
        for (final album in widget.singleAlbums) {
          final taskIndex = album.tasks.indexWhere((t) => t.id == task.id);
          if (taskIndex >= 0) {
            if (widget.onPlaySingleAlbumTask != null) {
              widget.onPlaySingleAlbumTask!(album, taskIndex);
            }
            break;
          }
        }
      }
    },
    child: Padding(
      padding: const EdgeInsets.only(left: 16, right: 20, top: 6, bottom: 6),
      child: Row(
        children: [
          // ランク番号（固定幅で揃える）
          SizedBox(
            width: 16,
            child: Text(
              rank.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'SF Pro Text',
              ),
              textAlign: TextAlign.left,
            ),
          ),
          const SizedBox(width: 16),
          
          // 所属アルバムのジャケット画像
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: _getAlbumCoverForTask(task),
            ),
          ),
          const SizedBox(width: 12),
          
          // タスク名（左寄せ）
          Expanded(
            child: Text(
              task.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                fontFamily: 'Hiragino Sans',
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          const SizedBox(width: 12),
          
          // 完了回数
          Text(
            '$completions',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
              fontWeight: FontWeight.w500,
              fontFamily: 'SF Pro Text',
            ),
          ),
        ],
      ),
    ),
  );
}


  Widget _buildAlbumList() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.only(left: 20, bottom: 12),
        child: Text(
          'Albums',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            letterSpacing: -0.3,
            fontWeight: FontWeight.w900,
            fontFamily: 'Hiragino Sans',
          ),
        ),
      ),
      
      // 🔧 修正：ライフドリームアルバム
      GestureDetector(
        onTap: () {
          // 🔧 修正：ライフドリームアルバム詳細に移動
          if (widget.onNavigateToLifeDreamAlbumDetail != null) {
            widget.onNavigateToLifeDreamAlbumDetail!();
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: widget.lifeDreamAlbumCoverImage != null
                      ? Image.memory(
                          widget.lifeDreamAlbumCoverImage!,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF1DB954),
                                Color(0xFF1ED760),
                              ],
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.album,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Life Dream Album',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        fontFamily: 'Hiragino Sans',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.tasks.length} Tasks',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        fontFamily: 'Hiragino Sans',
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.white.withOpacity(0.4),
                size: 20,
              ),
            ],
          ),
        ),
      ),
      
      // シングルアルバム一覧
      ...widget.singleAlbums.map((album) {
        return GestureDetector(
          onTap: () {
            if (widget.onNavigateToAlbumDetail != null) {
              widget.onNavigateToAlbumDetail!(album);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: album.albumCoverImage != null
                        ? Image.memory(
                            album.albumCoverImage!,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF8B5CF6),
                                  Color(0xFF06B6D4),
                                ],
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.music_note,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        album.albumName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          fontFamily: 'Hiragino Sans',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${album.tasks.length} Tasks',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          fontFamily: 'Hiragino Sans',
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Colors.white.withOpacity(0.4),
                  size: 20,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    ],
  );
}

  

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final profileHeight = screenHeight * 0.5;
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          // プロフィール画像部分（スクロール時に縮む）
          SliverAppBar(
  expandedHeight: profileHeight,
  pinned: false,
  floating: false,
  stretch: true,  // 🆕 これを追加
  backgroundColor: Colors.transparent,
  elevation: 0,
  automaticallyImplyLeading: false,
  flexibleSpace: FlexibleSpaceBar(
    stretchModes: const [  // 🆕 これを追加
      StretchMode.zoomBackground,
    ],
    background: _buildProfileImage(),
  ),
            leading: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                ),
                child: IconButton(
                    onPressed: widget.onClose ?? () => Navigator.pop(context),
                    padding: EdgeInsets.zero, // パディングを削除
                    alignment: Alignment.center, // 中央揃えを明示
                    icon: const Icon(
                    Icons.chevron_left,
                    color: Colors.white,
                    size: 28,
                    ),
                ),
            ),
          ),
          
          // スクロール可能なコンテンツ（画像に覆い被さる）
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  
                  // 総タスク数
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Total Tasks Completed: $_totalTasksCompleted',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        fontFamily: 'SF Pro Text',
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // タスクランキング
                  _buildTaskRanking(),
                  
                  const SizedBox(height: 40),
                  
                  // アルバム一覧
                  _buildAlbumList(),
                  
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}