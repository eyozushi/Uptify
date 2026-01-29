// home_screen.dart - 時間帯別挨拶対応版
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'app_settings_screen.dart';
import '../models/record_gauge_state.dart';
import '../models/task_item.dart';
import '../models/single_album.dart';
import '../services/data_service.dart';
import '../services/habit_breaker_service.dart';
import '../services/task_completion_service.dart';
import '../services/update_notification_service.dart';
import '../services/record_gauge_service.dart';
import '../widgets/update_banner.dart';
import '../widgets/record_gauge_widget.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:palette_generator/palette_generator.dart'; // 🆕 追加

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

  final TaskCompletionService _taskCompletionService = TaskCompletionService();
  int _consecutiveDays = 0;
  
  String _idealSelf = '自分の理想像';
  String _artistName = '自分の名前';
  List<TaskItem> _tasks = [];
  String _albumImage = '';
  Uint8List? _imageBytes;
  List<SingleAlbum> _singleAlbums = [];

  // 🆕 Record Gauge関連
  final RecordGaugeService _recordGaugeService = RecordGaugeService();
  bool _hasShownCompletionMessage = false;
  
  // 🆕 キャッシュ用
  RecordGaugeState? _cachedRecordState;
  bool _isUpdating = false;

  // 🆕 追加：アップデート通知用
UpdateNotification? _updateNotification;
final UpdateNotificationService _updateNotificationService = UpdateNotificationService();

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
    
    _loadRecordStateAndCheckCompletion();
    _loadConsecutiveDays();
    _checkForUpdateNotification();
  }

  @override
void didUpdateWidget(covariant HomeScreen oldWidget) {
  super.didUpdateWidget(oldWidget);
  // 画面が再表示されたらデータをリロード
  _checkAndRefreshIfNeeded();
  _loadData();
  _loadConsecutiveDays(); // 🆕 追加：Task Streakも再読み込み
}

  Future<void> _checkAndRefreshIfNeeded() async {
    if (_isUpdating) return;
    
    _isUpdating = true;
    try {
      // 保存されたキャッシュを確認
      final savedState = await _recordGaugeService.loadSavedState();
      
      if (savedState == null) {
        // キャッシュが削除されている→最新データを取得
        print('🔄 キャッシュが削除されているため再読み込み');
        final latestState = await _recordGaugeService.getTodayRecordState();
        if (mounted) {
          setState(() {
            _cachedRecordState = latestState;
          });
          print('✅ Record Gauge更新完了: ${latestState.completedCount}/4');
        }
      } else if (_cachedRecordState == null || 
                 savedState.completedCount != _cachedRecordState!.completedCount) {
        // データが変わっている→更新
        if (mounted) {
          setState(() {
            _cachedRecordState = savedState;
          });
          print('✅ Record Gauge更新: ${savedState.completedCount}/4');
        }
      }
    } catch (e) {
      print('❌ Record Gauge更新エラー: $e');
    } finally {
      _isUpdating = false;
    }
  }

  Future<void> _silentRefreshRecordState() async {
    if (_isUpdating) return; // 更新中なら重複実行を防ぐ
    
    _isUpdating = true;
    try {
      print('🔄 Record Gauge サイレント更新開始');
      final latestState = await _recordGaugeService.getTodayRecordState();
      if (mounted) {
        setState(() {
          _cachedRecordState = latestState;
        });
        print('✅ Record Gauge更新完了: ${latestState.completedCount}/4');
      }
    } catch (e) {
      print('❌ Record Gauge更新エラー: $e');
    } finally {
      _isUpdating = false;
    }
  }

  // 🆕 強制的に最新データを取得
  Future<void> _refreshRecordState() async {
    try {
      print('🔄 Record Gauge強制更新開始');
      final latestState = await _recordGaugeService.getTodayRecordState();
      if (mounted) {
        setState(() {
          _cachedRecordState = latestState;
        });
        print('✅ Record Gauge更新完了: ${latestState.completedCount}/4');
      }
    } catch (e) {
      print('❌ Record Gauge更新エラー: $e');
    }
  }

  Future<void> _loadRecordStateAndCheckCompletion() async {
    try {
      // まず保存されたキャッシュを読み込んで即座に表示
      final savedState = await _recordGaugeService.loadSavedState();
      if (savedState != null && mounted) {
        setState(() {
          _cachedRecordState = savedState;
        });
      }
      
      // バックグラウンドで最新データを取得
      final latestState = await _recordGaugeService.getTodayRecordState();
      if (mounted) {
        setState(() {
          _cachedRecordState = latestState;
        });
      }
      
      // 完了メッセージチェック
      _checkAndShowCompletionMessage();
      
    } catch (e) {
      print('❌ Record State読み込みエラー: $e');
    }
  }

  Future<void> _loadConsecutiveDays() async {
    try {
      final days = await _taskCompletionService.getConsecutiveDays();
      if (mounted) {
        setState(() {
          _consecutiveDays = days;
        });
      }
    } catch (e) {
      print('❌ 連続日数読み込みエラー: $e');
    }
  }

  /// 🆕 新規追加：アップデート通知をチェック
Future<void> _checkForUpdateNotification() async {
  try {
    final notification = await _updateNotificationService.checkForUpdate();
    if (mounted && notification != null) {
      setState(() {
        _updateNotification = notification;
      });
      print('🔔 アップデート通知を表示: ${notification.title}');
    }
  } catch (e) {
    print('❌ アップデート通知チェックエラー: $e');
  }
}

/// 🆕 新規追加：通知を非表示にする
void _dismissUpdateNotification() {
  if (_updateNotification != null) {
    _updateNotificationService.dismissNotification(_updateNotification!.id);
    setState(() {
      _updateNotification = null;
    });
    print('✅ アップデート通知を非表示');
  }
}

  /// 🆕 新規追加：Task Streakを強制再読み込み
Future<void> _refreshConsecutiveDays() async {
  try {
    final days = await _taskCompletionService.getConsecutiveDays();
    if (mounted) {
      setState(() {
        _consecutiveDays = days;
      });
      print('✅ Task Streak更新: ${days}日連続');
    }
  } catch (e) {
    print('❌ Task Streak更新エラー: $e');
  }
}


  // 🌅 新機能: 時間帯に応じた挨拶を取得
  String _getGreeting() {
    final now = DateTime.now();
    final hour = now.hour;
    
    if (hour >= 5 && hour < 10) {
      return 'Good morning';
    } else if (hour >= 10 && hour < 17) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
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
                'Congratulations.\nYou moved closer to your ideal self today.',
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

  void _navigateToAlbumDetail() async { // async追加
  if (widget.onNavigateToAlbumDetail != null) {
    // 🆕 追加：色を事前抽出
    final extractedColor = await _extractColorFromAlbum(
      imageBytes: widget.imageBytes ?? _imageBytes,
      imagePath: _albumImage,
    );
    
    print('🎨 抽出完了: $extractedColor');
    
    widget.onNavigateToAlbumDetail!();
  }
}

  void _navigateToSingleAlbumDetail(SingleAlbum album) async { // async追加
  if (widget.onNavigateToSingleAlbumDetail != null) {
    // 🆕 追加：色を事前抽出
    final extractedColor = await _extractColorFromAlbum(
      imageBytes: album.albumCoverImage,
    );
    
    print('🎨 抽出完了: $extractedColor');
    
    widget.onNavigateToSingleAlbumDetail!(album);
  }
}

  void _navigateToAppSettings() async {  // 🔧 asyncを追加
  print('⚙️ 設定画面に移動します');
  await Navigator.push(  // 🔧 awaitを追加
    context,
    MaterialPageRoute(
      builder: (context) => AppSettingsScreen(
        onClose: () => Navigator.pop(context),
      ),
    ),
  );
  
  // 🔧 追加: 設定画面から戻ったらデータを再読み込み
  await _loadData();
  setState(() {});
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
    // 🔧 キャッシュがあれば常に表示（更新中でもローディングを出さない）
    if (_cachedRecordState != null) {
      return RecordGaugeWidget(
        state: _cachedRecordState!,
        albumCoverImage: widget.imageBytes ?? _imageBytes,
        size: 200.0,
      );
    }
    
    // 🔧 キャッシュがない初回のみFutureBuilder
    return FutureBuilder<RecordGaugeState>(
      future: _recordGaugeService.getTodayRecordState(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          // データを取得したらキャッシュに保存
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _cachedRecordState = snapshot.data;
              });
            }
          });
          
          return RecordGaugeWidget(
            state: snapshot.data!,
            albumCoverImage: widget.imageBytes ?? _imageBytes,
            size: 200.0,
          );
        }
        
        if (snapshot.hasError) {
          return RecordGaugeErrorWidget(
            errorMessage: 'Failed to load data',
          );
        }
        
        // 初回のみローディング表示
        return const RecordGaugeLoadingWidget();
      },
    );
  }

  /// 🔧 修正：連続タスク実行記録セクションを構築
Widget _buildConsecutiveDaysSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // 🆕 追加：セクションヘッダー（統一スタイル）
      const Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Task Streak',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            fontFamily: 'Hiragino Sans',
            letterSpacing: -1.0,
          ),
        ),
      ),
      
      const SizedBox(height: 20),
      
      // 日数表示カード
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '$_consecutiveDays',
              style: const TextStyle(
                color: Color(0xFF1DB954),
                fontSize: 48,
                fontWeight: FontWeight.w900,
                fontFamily: 'Hiragino Sans',
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'days',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w600,
                fontFamily: 'Hiragino Sans',
              ),
            ),
          ],
        ),
      ),
    ],
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

  /// 🆕 新規追加：アルバム画像から色を事前抽出
Future<Color> _extractColorFromAlbum({
  Uint8List? imageBytes,
  String? imagePath,
}) async {
  try {
    ImageProvider? imageProvider;
    
    if (imageBytes != null) {
      imageProvider = MemoryImage(imageBytes);
    } else if (imagePath != null && imagePath.isNotEmpty && File(imagePath).existsSync()) {
      imageProvider = FileImage(File(imagePath));
    }
    
    if (imageProvider == null) {
      return Colors.black;
    }
    
    final PaletteGenerator paletteGenerator = await PaletteGenerator.fromImageProvider(
      imageProvider,
      size: const Size(200, 200),
      maximumColorCount: 16,
    );
    
    double getSaturation(Color color) {
      final r = color.red / 255.0;
      final g = color.green / 255.0;
      final b = color.blue / 255.0;
      
      final max = [r, g, b].reduce((a, b) => a > b ? a : b);
      final min = [r, g, b].reduce((a, b) => a < b ? a : b);
      
      if (max == 0) return 0;
      return (max - min) / max;
    }
    
    double scoreColor(PaletteColor paletteColor) {
      final color = paletteColor.color;
      final population = paletteColor.population;
      final saturation = getSaturation(color);
      final luminance = color.computeLuminance();
      
      double score = 0;
      
      if (population < 100) {
        score -= 500;
      } else if (population < 500) {
        score -= 100;
      } else if (population > 2000) {
        score += 150;
      } else {
        score += 50;
      }
      
      if (saturation > 0.4) {
        score += 300;
      } else if (saturation > 0.25) {
        score += 150;
      } else if (saturation < 0.15) {
        score -= 400;
      }
      
      if (luminance < 0.1) {
        score -= 200;
      } else if (luminance > 0.85) {
        score -= 300;
      } else if (luminance >= 0.2 && luminance <= 0.6) {
        score += 100;
      }
      
      if (saturation > 0.3 && population > 1000) {
        score += 200;
      }
      
      final hue = HSLColor.fromColor(color).hue;
      if ((hue >= 0 && hue <= 30) ||
          (hue >= 180 && hue <= 240) ||
          (hue >= 270 && hue <= 330)) {
        score += 50;
      }
      
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
    
    if (allColors.isEmpty) {
      return Colors.black;
    }
    
    PaletteColor bestColor = allColors[0];
    double bestScore = scoreColor(bestColor);
    
    for (final paletteColor in allColors) {
      final score = scoreColor(paletteColor);
      if (score > bestScore) {
        bestScore = score;
        bestColor = paletteColor;
      }
    }
    
    return bestColor.color;
  } catch (e) {
    print('❌ 色抽出エラー: $e');
    return Colors.black;
  }
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  _getGreeting(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Hiragino Sans',
                    letterSpacing: -1.0,
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    print('⚙️ 設定画面に移動します！');
                    _navigateToAppSettings();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: const Icon(
                      Icons.settings,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // 🆕 追加：アップデート通知バナー
          if (_updateNotification != null)
            UpdateBanner(
              notification: _updateNotification!,
              onDismiss: _dismissUpdateNotification,
            ),

          // 既存のコンテンツ（そのまま）
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
                      letterSpacing: -0.5,
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
                              letterSpacing: -1.0, 
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

// 🔧 修正：Task Streak と Record Gauge の順序を入れ替え

// 連続タスク実行記録セクション（上に移動）
_buildConsecutiveDaysSection(),

const SizedBox(height: 20),

// Record Gauge セクション（下に移動）
_buildRecordGaugeSection(),

const SizedBox(height: 20),

Align(
  alignment: Alignment.centerLeft,
  child: const Text(
    'Your Albums',
    style: TextStyle(
      color: Colors.white,
      fontSize: 22,
      fontWeight: FontWeight.w900,
      fontFamily: 'Hiragino Sans',
      letterSpacing: -1.0, // 🆕 追加：文字間隔を詰める
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
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Hiragino Sans',
                              letterSpacing: -1.0,
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
                            '${_tasks.length} Tasks',
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
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Hiragino Sans',
                                letterSpacing: -1.0,

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
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Hiragino Sans',
                                
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${album.tasks.length} Tasks',
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