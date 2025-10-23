// artist_screen.dart - スクロール覆い被さり修正版
import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../models/task_item.dart';
import '../models/single_album.dart';
import '../services/data_service.dart';
import '../services/task_completion_service.dart';

class ArtistScreen extends StatefulWidget {
  final String artistName;
  final Uint8List? profileImageBytes;
  final List<TaskItem> tasks;
  final List<SingleAlbum> singleAlbums;
  final VoidCallback? onClose;
  final Function(int taskIndex)? onPlayTask;
  final Function(SingleAlbum album)? onNavigateToAlbumDetail;

  const ArtistScreen({
    super.key,
    required this.artistName,
    this.profileImageBytes,
    required this.tasks,
    required this.singleAlbums,
    this.onClose,
    this.onPlayTask,
    this.onNavigateToAlbumDetail,
  });

  @override
  State<ArtistScreen> createState() => _ArtistScreenState();
}

class _ArtistScreenState extends State<ArtistScreen> {
  final DataService _dataService = DataService();
  final TaskCompletionService _taskCompletionService = TaskCompletionService();
  
  int _totalTasksCompleted = 0;
  List<Map<String, dynamic>> _taskRanking = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadArtistData();
  }

  Future<void> _loadArtistData() async {
    try {
      // 総完了回数を計算
      int totalCompleted = 0;
      List<Map<String, dynamic>> taskStats = [];
      
      for (final task in widget.tasks) {
        final completions = await _taskCompletionService.getTodayTaskSuccesses(task.id);
        totalCompleted += completions;
        
        taskStats.add({
          'task': task,
          'completions': completions,
        });
      }
      
      // 完了回数でソートしてランキング作成
      taskStats.sort((a, b) => (b['completions'] as int).compareTo(a['completions'] as int));
      
      setState(() {
        _totalTasksCompleted = totalCompleted;
        _taskRanking = taskStats.take(5).toList(); // 上位5位まで
        _isLoading = false;
      });
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
          
          // アーティスト名（プロフィール画像の下部に配置）
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
                shadows: [
                  Shadow(
                    color: Colors.black54,
                    offset: Offset(2, 2),
                    blurRadius: 4,
                  ),
                ],
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 20, bottom: 12),
          child: Text(
            'トップタスク',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
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

  Widget _buildRankingItem({
    required int rank,
    required TaskItem task,
    required int completions,
  }) {
    return GestureDetector(
      onTap: () {
        final taskIndex = widget.tasks.indexOf(task);
        if (taskIndex >= 0 && widget.onPlayTask != null) {
          widget.onPlayTask!(taskIndex);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: Row(
          children: [
            // ランク番号（シンプルな白文字）
            SizedBox(
              width: 20,
              child: Text(
                rank.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  fontFamily: 'SF Pro Text',
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 16),
            
            // タスクアイコン
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: task.color,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Icon(
                  _getTaskIcon(rank - 1),
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            // タスク名
            Expanded(
              child: Text(
                task.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  fontFamily: 'Hiragino Sans',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            
            // 完了回数
            Text(
              '$completions回',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 13,
                fontWeight: FontWeight.w400,
                fontFamily: 'SF Pro Text',
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getTaskIcon(int index) {
    switch (index) {
      case 0:
        return Icons.star_rounded;
      case 1:
        return Icons.local_fire_department_rounded;
      case 2:
        return Icons.trending_up_rounded;
      case 3:
        return Icons.bolt_rounded;
      default:
        return Icons.task_alt_rounded;
    }
  }

  Widget _buildAlbumList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 20, bottom: 12),
          child: Text(
            'アルバム',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              fontFamily: 'Hiragino Sans',
            ),
          ),
        ),
        
        // ライフドリームアルバム
        GestureDetector(
          onTap: () {
            // ライフドリームアルバム詳細に移動（実装は後で）
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
                    gradient: const LinearGradient(
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
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ライフドリームアルバム',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          fontFamily: 'Hiragino Sans',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.tasks.length} タスク',
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
                          '${album.tasks.length} タスク',
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

  Widget _buildAboutSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 20, bottom: 12),
          child: Text(
            'About the Artist',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              fontFamily: 'SF Pro Text',
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'あなたの人生という音楽の主人公。毎日新しい楽曲を作り続ける唯一無二のアーティスト。時には激しく、時には優しく、常に成長を続けている。今日もまた新しいメロディーを奏でている。',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 15,
              height: 1.6,
              fontWeight: FontWeight.w400,
              fontFamily: 'Hiragino Sans',
            ),
          ),
        ),
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
            backgroundColor: Colors.transparent,
            elevation: 0,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
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
                      '総タスク完了数: $_totalTasksCompleted',
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
                  
                  const SizedBox(height: 40),
                  
                  // About the Artist
                  _buildAboutSection(),
                  
                  // 下部の余白（ミニプレイヤー + ページセレクター分）
                  const SizedBox(height: 160),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}