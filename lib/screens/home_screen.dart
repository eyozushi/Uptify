// home_screen.dart - 時間帯別挨拶対応版
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import '../widgets/record_gauge_widget.dart';
import '../services/record_gauge_service.dart';
import '../models/record_gauge_state.dart';
import '../models/task_item.dart';
import '../models/single_album.dart';
import '../services/data_service.dart';
import '../services/habit_breaker_service.dart';
import 'notification_settings_screen.dart';
import 'package:auto_size_text/auto_size_text.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onDataUpdated;
  final Uint8List? imageBytes;
  final String? albumImagePath;
  final VoidCallback? onNavigateToAlbumDetail;
  final VoidCallback? onNavigateToSettings;
  final VoidCallback? onNavigateToPlayer;
  final VoidCallback? onNavigateToIdealPage; // 🌟 新しいコールバック
  final VoidCallback? onNavigateToArtist; 
  final Function(SingleAlbum)? onNavigateToSingleAlbumDetail;
  
  const HomeScreen({
    super.key, 
    this.onDataUpdated,
    this.imageBytes,
    this.albumImagePath,
    this.onNavigateToAlbumDetail,
    this.onNavigateToSettings,
    this.onNavigateToPlayer,
    this.onNavigateToIdealPage, // 🌟 新しいコールバック
    this.onNavigateToArtist, 
    this.onNavigateToSingleAlbumDetail,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DataService _dataService = DataService();
  final HabitBreakerService _habitBreakerService = HabitBreakerService();
  
  String _idealSelf = '自分の理想像';
  String _artistName = '自分の名前';
  List<TaskItem> _tasks = [];
  String _albumImage = '';
  Uint8List? _imageBytes;
  List<SingleAlbum> _singleAlbums = [];

  // 🆕 Record Gauge関連
  final RecordGaugeService _recordGaugeService = RecordGaugeService();
  bool _hasShownCompletionMessage = false;

  @override
void initState() {
  super.initState();
  _loadData();
  _setupDefaultNotificationSettings();
  
  if (widget.imageBytes != null) {
    _imageBytes = widget.imageBytes;
  }
  if (widget.albumImagePath != null) {
    _albumImage = widget.albumImagePath!;
  }
  
  // 🆕 Record Gauge: 4タスク全完了メッセージチェック
  _checkAndShowCompletionMessage();
}

  // 🌅 新機能: 時間帯に応じた挨拶を取得
  String _getGreeting() {
    final now = DateTime.now();
    final hour = now.hour;
    
    if (hour >= 5 && hour < 10) {
      return 'おはよう';
    } else if (hour >= 10 && hour < 17) {
      return 'こんにちは';
    } else {
      return 'こんばんは';
    }
  }

  Future<void> _setupDefaultNotificationSettings() async {
    try {
      final config = await _dataService.loadNotificationConfig();
      
      if (!config.isHabitBreakerEnabled) {
        final defaultConfig = config.copyWith(
          isHabitBreakerEnabled: true,
          habitBreakerInterval: 1, // 1分間隔（テスト用）
        );
        
        await _habitBreakerService.updateSettings(defaultConfig);
        print('🔔 デフォルト通知設定を適用しました');
      }
    } catch (e) {
      print('❌ デフォルト通知設定エラー: $e');
    }
  }

  /// 🆕 4タスク全完了メッセージを表示すべきかチェック
  Future<void> _checkAndShowCompletionMessage() async {
    try {
      // 既にメッセージを表示済みの場合はスキップ
      if (_hasShownCompletionMessage) return;
      
      // メッセージ表示条件をチェック
      final shouldShow = await _recordGaugeService.shouldShowCompletionMessage();
      
      if (shouldShow && mounted) {
        // 少し遅延してメッセージ表示（UI構築完了後）
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            _showCompletionMessage();
          }
        });
      }
    } catch (e) {
      print('❌ 完了メッセージチェックエラー: $e');
    }
  }

  /// 🆕 4タスク全完了の達成メッセージを表示
  void _showCompletionMessage() {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(
              Icons.celebration,
              color: Colors.white,
              size: 24,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'おめでとう　今日も理想像に近づいた',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Hiragino Sans',
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1DB954),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.all(16),
      ),
    );
    
    // メッセージ表示済みフラグを設定
    _hasShownCompletionMessage = true;
    _recordGaugeService.markCompletionMessageShown();
    
    print('✅ 4タスク全完了メッセージを表示しました');
  }

  Future<void> _loadData() async {
    final data = await _dataService.loadUserData();
    final singleAlbums = await _dataService.loadSingleAlbums();
    
    setState(() {
      _idealSelf = data['idealSelf'] ?? '自分の理想像';
      _artistName = data['artistName'] ?? '自分の名前';
      _albumImage = data['albumImagePath'] ?? '';
      _singleAlbums = singleAlbums;
      
      _imageBytes = _dataService.getSavedImageBytes();
      
      if (data['tasks'] != null) {
        if (data['tasks'] is List<TaskItem>) {
          _tasks = data['tasks'] as List<TaskItem>;
        } else if (data['tasks'] is List) {
          _tasks = (data['tasks'] as List)
              .map((taskJson) => TaskItem.fromJson(taskJson))
              .take(4)
              .toList();
        }
      }
      
      if (_tasks.isEmpty) {
        _tasks = _dataService.getDefaultTasks();
      }
    });
  }

  // 🆕 新機能: 顔写真アイコンを構築
  Widget _buildProfileIcon({double size = 48}) { // 🔧 32→48に拡大
    final profileImageBytes = _dataService.getSavedIdealImageBytes();
    
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: profileImageBytes != null
            ? Image.memory(
                profileImageBytes,
                width: size,
                height: size,
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
                    size: size * 0.6,
                  ),
                ),
              ),
      ),
    );
  }

  void _navigateToSettings() {
    if (widget.onNavigateToSettings != null) {
      widget.onNavigateToSettings!();
    }
  }

  void _navigateToPlayer() {
    if (widget.onNavigateToPlayer != null) {
      widget.onNavigateToPlayer!();
    }
  }

  // 🌟 修正: 理想像ページ（インデックス0）に移動
  void _navigateToPlayerWithIdealPage() {
    if (widget.onNavigateToIdealPage != null) {
      widget.onNavigateToIdealPage!();
    }
  }

  // 🆕 新機能: アーティスト画面に移動
  void _navigateToArtist() {
    if (widget.onNavigateToArtist != null) {
      widget.onNavigateToArtist!();
    }
  }

  void _navigateToAlbumDetail() {
    if (widget.onNavigateToAlbumDetail != null) {
      widget.onNavigateToAlbumDetail!();
    }
  }

  void _navigateToSingleAlbumDetail(SingleAlbum album) {
    if (widget.onNavigateToSingleAlbumDetail != null) {
      widget.onNavigateToSingleAlbumDetail!(album);
    }
  }

  void _navigateToNotificationSettings() {
    print('🔔 通知設定画面に移動します');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NotificationSettingsScreen(),
      ),
    );
  }

  Widget _buildAlbumCover({double size = 60}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: 
        widget.imageBytes != null
            ? Image.memory(
                widget.imageBytes!,
                width: size,
                height: size,
                fit: BoxFit.cover,
              )
            : _imageBytes != null
                ? Image.memory(
                    _imageBytes!,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                  )
                : _albumImage.isNotEmpty && File(_albumImage).existsSync()
                    ? Image.file(
                        File(_albumImage),
                        width: size,
                        height: size,
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
                        child: Center(
                          child: Icon(
                            Icons.album,
                            color: Colors.white,
                            size: size * 0.5,
                          ),
                        ),
                      ),
      ),
    );
  }

  /// 🆕 Record Gaugeセクションを構築
  Widget _buildRecordGaugeSection() {
    return FutureBuilder<RecordGaugeState>(
      future: _recordGaugeService.getTodayRecordState(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // ローディング表示
          return const RecordGaugeLoadingWidget();
        }
        
        if (snapshot.hasError) {
          // エラー表示
          return RecordGaugeErrorWidget(
            errorMessage: 'データの読み込みに失敗しました',
          );
        }
        
        if (!snapshot.hasData) {
          // データなし
          return const RecordGaugeErrorWidget(
            errorMessage: 'データが見つかりません',
          );
        }
        
        // Record Gauge表示
        return RecordGaugeWidget(
          state: snapshot.data!,
          albumCoverImage: widget.imageBytes ?? _imageBytes,
          size: 200.0,
        );
      },
    );
  }

  Widget _buildSingleAlbumCover(SingleAlbum album, {double size = 60}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: album.albumCoverImage != null
            ? Image.memory(
                album.albumCoverImage!,
                width: size,
                height: size,
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
                    Icons.music_note,
                    color: Colors.white,
                    size: size * 0.5,
                  ),
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
  height: 60,
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        _getGreeting(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 32,
          fontWeight: FontWeight.bold,
          fontFamily: 'Hiragino Sans',
        ),
      ),
      Row(
        children: [
          // 🆕 設定アイコンのみ
          GestureDetector(
            onTap: () {
              print('⚙️ 設定ボタンがタップされました！');
              _navigateToSettings();
            },
            child: const Icon(
              Icons.settings,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 20),
          // 🆕 通知アイコンのみ
          GestureDetector(
            onTap: () {
              print('🔔 通知設定画面に移動します！');
              _navigateToNotificationSettings();
            },
            child: const Icon(
              Icons.notifications_outlined,
              color: Colors.white,
              size: 28,
            ),
          ),
        ],
      ),
    ],
  ),
),

            const SizedBox(height: 40),

            // 🆕 顔写真アイコンとアーティスト名
            Row(
              children: [
                GestureDetector( // 🆕 追加: 顔写真アイコンにタップイベント
                  onTap: () {
                    print('👤 アーティストアイコンがタップされました！');
                    _navigateToArtist();
                  },
                  child: _buildProfileIcon(),
                ),
                const SizedBox(width: 16),
                GestureDetector( // 🆕 追加: アーティスト名にタップイベント
                  onTap: () {
                    print('👤 アーティスト名がタップされました！');
                    _navigateToArtist();
                  },
                  child: Text(
                    _artistName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Hiragino Sans',
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            GestureDetector(
              onTap: () {
                print('🎵 ドリームアルバムがタップされました！');
                // 🔧 修正: 理想像ページ（インデックス-1）に移動
                _navigateToPlayerWithIdealPage();
              },
              child: Container(
                width: double.infinity,
                height: 120,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1DB954),
                      Color(0xFF1ED760),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  children: [
                    // アルバムジャケット（左側）
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: widget.imageBytes != null
                              ? Image.memory(
                                  widget.imageBytes!,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                )
                              : _imageBytes != null
                                  ? Image.memory(
                                      _imageBytes!,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                    )
                                  : _albumImage.isNotEmpty && File(_albumImage).existsSync()
                                      ? Image.file(
                                          File(_albumImage),
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                        )
                                      : Container(
                                          decoration: const BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                Color(0xFF2ECC71),
                                                Color(0xFF27AE60),
                                              ],
                                            ),
                                          ),
                                          child: const Center(
                                            child: Icon(
                                              Icons.album,
                                              color: Colors.white,
                                              size: 40,
                                            ),
                                          ),
                                        ),
                        ),
                      ),
                    ),
                    // アルバム名（右側）
                    Positioned(
                      left: 100,
                      top: 0,
                      bottom: 0,
                      right: 50,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AutoSizeText(
                            _idealSelf,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'Hiragino Sans',
                            ),
                            maxLines: 1,
                            minFontSize: 14,
                            maxFontSize: 22,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // 再生ボタン（右下）
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          color: Colors.black,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 🆕 Record Gauge セクション追加
            _buildRecordGaugeSection(),

            const SizedBox(height: 20),

Align(
  alignment: Alignment.centerLeft,
  child: const Text(
    'あなたのアルバム',
    style: TextStyle(
      color: Colors.white,
      fontSize: 22,
      fontWeight: FontWeight.w900,
      fontFamily: 'Hiragino Sans',
    ),
  ),
),

            const SizedBox(height: 20),

            InkWell(
              onTap: () {
                print('🎵 ライフドリームアルバムがタップされました！');
                _navigateToAlbumDetail();
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  
                ),
                child: Row(
                  children: [
                    _buildAlbumCover(),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _idealSelf,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Hiragino Sans',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _artistName,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              fontFamily: 'Hiragino Sans',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_tasks.length} タスク',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12,
                              fontWeight: FontWeight.w300,
                              fontFamily: 'Hiragino Sans',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: Colors.white70,
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),

            ..._singleAlbums.map((album) {
              return InkWell(
                onTap: () {
                  print('🎵 シングルアルバム「${album.albumName}」がタップされました！');
                  _navigateToSingleAlbumDetail(album);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    
                  ),
                  child: Row(
                    children: [
                      _buildSingleAlbumCover(album),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              album.albumName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Hiragino Sans',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _artistName,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                fontFamily: 'Hiragino Sans',
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${album.tasks.length} タスク',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 12,
                                fontWeight: FontWeight.w300,
                                fontFamily: 'Hiragino Sans',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: Colors.white70,
                        size: 24,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}