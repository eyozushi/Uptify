// player_screen.dart - タイマー削除版（MainWrapper中心設計）
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/task_item.dart';
import '../models/lyric_note_item.dart';  // 🔧 追加：この行を追加
import '../services/data_service.dart';
import '../services/task_completion_service.dart';
import '../services/audio_service.dart';
import '../widgets/completion_dialog.dart';
import 'settings_screen.dart';
import 'album_detail_screen.dart';
import 'package:palette_generator/palette_generator.dart';
import '../widgets/lyric_notes_widget.dart';

// カスタムの太いプラスアイコンを描画するクラス
class ThickPlusPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final lineLength = size.width * 0.6;

    // 水平線
    canvas.drawLine(
      Offset(center.dx - lineLength / 2, center.dy),
      Offset(center.dx + lineLength / 2, center.dy),
      paint,
    );

    // 垂直線
    canvas.drawLine(
      Offset(center.dx, center.dy - lineLength / 2),
      Offset(center.dx, center.dy + lineLength / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}



// 🔧 新規追加：下スクロールのみ許可するカスタムPhysics
class DownOnlyScrollPhysics extends ScrollPhysics {
  const DownOnlyScrollPhysics({super.parent});

  @override
  DownOnlyScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return DownOnlyScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    // 上にスクロールしようとした時（上の余白が伸びる）を防ぐ
    if (value < position.pixels && position.pixels <= position.minScrollExtent) {
      return value - position.pixels;
    }
    // 下スクロールは許可
    if (position.maxScrollExtent <= position.pixels && position.pixels < value) {
      return value - position.pixels;
    }
    if (value < position.minScrollExtent && position.minScrollExtent < position.pixels) {
      return value - position.minScrollExtent;
    }
    if (position.pixels < position.maxScrollExtent && position.maxScrollExtent < value) {
      return value - position.maxScrollExtent;
    }
    return 0.0;
  }
}

class PlayerScreen extends StatefulWidget {
  final String idealSelf;
  final String artistName;
  final List<TaskItem> tasks;
  final String albumImagePath;
  final Uint8List? albumCoverImage;
  final bool isPlayingSingleAlbum;
  final String? playingSingleAlbumId;  // 🆕 追加：再生中のシングルアルバムID
  final VoidCallback? onDataChanged;
  final int? initialTaskIndex;
  final bool? initialIsPlaying;
  final int? initialElapsedSeconds;
  final double? initialProgress;
  final bool? initialAutoPlayEnabled;
  final Map<String, int>? todayTaskCompletions;
  final int? forcePageIndex;
  final Function({
    int? currentTaskIndex, 
    bool? isPlaying, 
    double? progress, 
    int? elapsedSeconds,
    bool? isAutoPlayEnabled,
    int? forcePageChange,
  })? onStateChanged;
  final VoidCallback? onClose;
  final VoidCallback? onNavigateToSettings;
  final VoidCallback? onNavigateToAlbumDetail;
  final Function(TaskItem task, bool wasSuccessful)? onTaskCompleted;
  final Function(Map<String, int>)? onCompletionCountsChanged;

  const PlayerScreen({
    super.key,
    required this.idealSelf,
    required this.artistName,
    required this.tasks,
    required this.albumImagePath,
    this.albumCoverImage,
    this.isPlayingSingleAlbum = false,
    this.playingSingleAlbumId,  // 🆕 追加
    this.onDataChanged,
    this.initialTaskIndex,
    this.initialIsPlaying,
    this.initialElapsedSeconds,
    this.initialProgress,
    this.initialAutoPlayEnabled,
    this.forcePageIndex,
    this.todayTaskCompletions,
    this.onStateChanged,
    this.onClose,
    this.onNavigateToSettings,
    this.onNavigateToAlbumDetail,
    this.onTaskCompleted,
    this.onCompletionCountsChanged,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();

  static bool isAtTopOfScroll(GlobalKey key) {
    final state = key.currentState as _PlayerScreenState?;
    if (state == null) return true;
    return state.isAtTop();
  }
}

class _PlayerScreenState extends State<PlayerScreen> with TickerProviderStateMixin {
  bool _isPlaying = false;
  File? _albumImage;
  Uint8List? _imageBytes;
  String _idealSelf = '';
  String _artistName = '';
  String _todayLyrics = '';
  String _aboutArtist = '';
  List<TaskItem> _tasks = [];
  bool _isForcePageChange = false;

  bool _isScrollAtTop = true; 

  bool _shouldPassGestureToParent = false; // 🔧 追加


  
  late AnimationController _swipeController;
late Animation<double> _swipeAnimation;
double _dragDistance = 0.0;
bool _isDragging = false;


  int _currentIndex = 0;
  
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  bool _isAutoPlayEnabled = false;
  late AnimationController _autoPlayController;
  late Animation<double> _autoPlaySlideAnimation;
  late Animation<Color?> _autoPlayColorAnimation;

  final DataService _dataService = DataService();
  final TaskCompletionService _taskCompletionService = TaskCompletionService();
  final AudioService _audioService = AudioService();
  
  int _elapsedSeconds = 0;
  double _currentProgress = 0.0;
  
  bool _isInitializationComplete = false;
  Map<String, int> _todayTaskCompletions = {};

  final ScrollController _contentScrollController = ScrollController(); // 🔧 追加

  bool isAtTop() {
  return _isScrollAtTop;
}
  
  // 🆕 追加：グラデーション用の色
  Color _dominantColor = const Color(0xFF2D1B69);
  Color _accentColor = const Color(0xFF1A1A2E);
  bool _isExtractingColors = false;


// 既存のフィールド定義の後に追加
Map<String, List<LyricNoteItem>> _taskLyricNotes = {};  // 🔧 変更: String → List<LyricNoteItem>

  @override
void initState() {
  super.initState();
  _initializeData();
  _setupAnimations();

  _loadTaskLyricNotes();
  
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _extractColorsFromImage();
  });
  
  if (widget.initialAutoPlayEnabled != null) {
    _isAutoPlayEnabled = widget.initialAutoPlayEnabled!;
    if (_isAutoPlayEnabled) {
      _autoPlayController.forward();
    }
  }
  
  if (widget.todayTaskCompletions != null) {
    _todayTaskCompletions = Map.from(widget.todayTaskCompletions!);
  } else {
    _loadTodayCompletions();
  }
  
  if (widget.initialElapsedSeconds != null) {
    _elapsedSeconds = widget.initialElapsedSeconds!;
  }
  
  if (widget.initialProgress != null) {
    _currentProgress = widget.initialProgress!;
  }
  
  if (widget.initialIsPlaying != null) {
    _isPlaying = widget.initialIsPlaying!;
  }
  
  // 初期タスクインデックス設定
  if (widget.initialTaskIndex != null) {
    if (widget.isPlayingSingleAlbum) {
      _currentIndex = widget.initialTaskIndex!;
    } else {
      if (widget.initialTaskIndex! == -1) {
        _currentIndex = 0;
      } else {
        _currentIndex = widget.initialTaskIndex! + 1;
      }
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _isInitializationComplete = true;
      });
    });
  } else {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _isInitializationComplete = true;
      });
    });
  }
}

/// タスクのLyric Notesを読み込み
/// 🔧 修正: 階層構造対応
Future<void> _loadTaskLyricNotes() async {
  try {
    print('📖 Lyric Notes読み込み開始'); // 🔧 追加
    
    List<TaskItem> tasks = [];
    
    // 🔧 修正: シングルアルバムかライフドリームアルバムかで分岐
    if (widget.isPlayingSingleAlbum && widget.playingSingleAlbumId != null) {
      // シングルアルバムの場合
      final album = await _dataService.getSingleAlbum(widget.playingSingleAlbumId!);
      if (album != null) {
        tasks = album.tasks;
        print('🎵 シングルアルバムのタスク読み込み: ${tasks.length}個');
      }
    } else {
      // ライフドリームアルバムの場合
      final userData = await _dataService.loadUserData();
      
      if (userData['tasks'] != null) {
        if (userData['tasks'] is List<TaskItem>) {
          tasks = List<TaskItem>.from(userData['tasks']);
        } else if (userData['tasks'] is List) {
          tasks = (userData['tasks'] as List)
              .map((taskJson) => TaskItem.fromJson(taskJson))
              .toList();
        }
      }
      print('📖 ライフドリームアルバムのタスク読み込み: ${tasks.length}個');
    }
    
    // 🔧 修正: Lyric Notesをマップに保存（階層構造対応）
    final notes = <String, List<LyricNoteItem>>{};
    for (final task in tasks) {
      if (task.lyricNotes != null && task.lyricNotes!.isNotEmpty) {
        notes[task.id] = task.lyricNotes!;
        print('  ✓ タスク "${task.title}" (ID: ${task.id}): ${task.lyricNotes!.length}行読み込み'); // 🔧 追加
      } else {
        print('  - タスク "${task.title}" (ID: ${task.id}): メモなし'); // 🔧 追加
      }
    }
    
    if (mounted) {
      setState(() {
        _taskLyricNotes = notes;
      });
    }
    
    print('✅ Lyric Notes読み込み完了: ${notes.length}件 (シングル: ${widget.isPlayingSingleAlbum})');
  } catch (e) {
    print('❌ Lyric Notes読み込みエラー: $e');
  }
}
  @override
void didUpdateWidget(PlayerScreen oldWidget) {
  super.didUpdateWidget(oldWidget);

  if (widget.albumCoverImage != oldWidget.albumCoverImage ||
      widget.albumImagePath != oldWidget.albumImagePath) {
    _extractColorsFromImage();
  }

  // 強制ページ変更の処理
  if (widget.forcePageIndex != null && 
      widget.forcePageIndex != oldWidget.forcePageIndex) {
    final newPageIndex = widget.forcePageIndex!;
    
    _isForcePageChange = true;
    _isInitializationComplete = false;
    
    setState(() {
      _currentIndex = newPageIndex;
      _dragDistance = 0.0; // 🔧 追加
    });
    
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _isForcePageChange = false;
        _isInitializationComplete = true;
      }
    });
  }
    
  bool needsUpdate = false;
  
  if (widget.todayTaskCompletions != null && 
      widget.todayTaskCompletions != oldWidget.todayTaskCompletions) {
    needsUpdate = true;
  }
  
  if (widget.initialAutoPlayEnabled != null && 
      widget.initialAutoPlayEnabled != oldWidget.initialAutoPlayEnabled) {
    needsUpdate = true;
  }
  
  if (widget.initialIsPlaying != null && 
      widget.initialIsPlaying != oldWidget.initialIsPlaying) {
    needsUpdate = true;
  }
  
  if (widget.initialProgress != null && 
      widget.initialProgress != oldWidget.initialProgress) {
    needsUpdate = true;
  }
  
  if (widget.initialElapsedSeconds != null && 
      widget.initialElapsedSeconds != oldWidget.initialElapsedSeconds) {
    needsUpdate = true;
  }
  
  if (needsUpdate) {
    setState(() {
      if (widget.todayTaskCompletions != null && 
          widget.todayTaskCompletions != oldWidget.todayTaskCompletions) {
        _todayTaskCompletions = Map.from(widget.todayTaskCompletions!);
      }
      
      if (widget.initialAutoPlayEnabled != null && 
          widget.initialAutoPlayEnabled != oldWidget.initialAutoPlayEnabled) {
        _isAutoPlayEnabled = widget.initialAutoPlayEnabled!;
      }
      
      if (widget.initialIsPlaying != null && 
          widget.initialIsPlaying != oldWidget.initialIsPlaying) {
        _isPlaying = widget.initialIsPlaying!;
      }
      
      if (widget.initialProgress != null && 
          widget.initialProgress != oldWidget.initialProgress) {
        _currentProgress = widget.initialProgress!;
      }
      
      if (widget.initialElapsedSeconds != null && 
          widget.initialElapsedSeconds != oldWidget.initialElapsedSeconds) {
        _elapsedSeconds = widget.initialElapsedSeconds!;
      }
    });
    
    if (widget.initialAutoPlayEnabled != null && 
        widget.initialAutoPlayEnabled != oldWidget.initialAutoPlayEnabled) {
      if (_isAutoPlayEnabled) {
        _autoPlayController.forward();
      } else {
        _autoPlayController.reverse();
      }
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }
}

void _handleSwipeStart(DragStartDetails details) {
  _isDragging = true;
  _swipeController.stop();
}

void _handleSwipeUpdate(DragUpdateDetails details) {
  if (!_isDragging) return;
  
  final totalCount = widget.isPlayingSingleAlbum ? _tasks.length : _tasks.length + 1;
  
  setState(() {
    // 🔧 追加：最初のページで右スワイプを制限
    if (_currentIndex == 0 && _dragDistance + details.delta.dx > 0) {
      _dragDistance += details.delta.dx * 0.3; // 抵抗感を出す
    } 
    // 🔧 追加：最後のページで左スワイプを制限
    else if (_currentIndex == totalCount - 1 && _dragDistance + details.delta.dx < 0) {
      _dragDistance += details.delta.dx * 0.3; // 抵抗感を出す
    } 
    else {
      _dragDistance += details.delta.dx;
    }
  });
}

void _handleSwipeEnd(DragEndDetails details) {
  if (!_isDragging) return;
  _isDragging = false;
  
  final screenWidth = MediaQuery.of(context).size.width;
  final threshold = screenWidth * 0.3;
  
  final totalCount = widget.isPlayingSingleAlbum ? _tasks.length : _tasks.length + 1; // 🔧 追加
  
  if (_dragDistance > threshold && _currentIndex > 0) {
    // 前のページへ
    _animateToPage(_currentIndex - 1);
  } else if (_dragDistance < -threshold && _currentIndex < totalCount - 1) { // 🔧 修正：範囲チェック追加
    // 次のページへ
    _animateToPage(_currentIndex + 1);
  } else {
    // 🔧 修正：位置をリセット（中央に戻す）
    _resetPosition();
  }
}

void _animateToPage(int newIndex) {
  final screenWidth = MediaQuery.of(context).size.width;
  final coverSize = screenWidth - 60;
  
  final targetDistance = (newIndex - _currentIndex) * -(coverSize + 40);
  
  _swipeAnimation = Tween<double>(
    begin: _dragDistance,
    end: targetDistance,
  ).animate(CurvedAnimation(
    parent: _swipeController,
    curve: Curves.easeOut,
  ));
  
  // 🔧 追加：アニメーション開始前に即座に状態を更新
  setState(() {
    _currentIndex = newIndex;
    _dragDistance = 0.0;
  });
  
  // 🔧 追加：即座に MainWrapper に通知
  if (_isInitializationComplete && !_isForcePageChange) {
    if (_isAutoPlayEnabled) {
      setState(() {
        _isAutoPlayEnabled = false;
      });
      _autoPlayController.reverse();
      
      if (widget.onStateChanged != null) {
        widget.onStateChanged!(
          isAutoPlayEnabled: false,
        );
      }
    }
    
    if (widget.onStateChanged != null) {
      final taskIndex = widget.isPlayingSingleAlbum ? newIndex : (newIndex > 0 ? newIndex - 1 : -1);
      
      // 🔧 重要：アニメーション開始前に通知
      widget.onStateChanged!(
        currentTaskIndex: taskIndex,
        progress: 0.0,
        elapsedSeconds: 0,
      );
      
      print('🔧 PlayerScreen: ページ切り替え通知（即座） → taskIndex=$taskIndex');
    }
  }
  
  // 🔧 修正：アニメーション完了後はアニメーションのリセットのみ
  _swipeController.forward(from: 0.0).then((_) {
    // 🔧 追加：アニメーションをリセット
    _swipeController.reset();
    _swipeAnimation = Tween<double>(
      begin: 0.0,
      end: 0.0,
    ).animate(_swipeController);
  });
}
void _resetPosition() {
  _swipeAnimation = Tween<double>(
    begin: _dragDistance,
    end: 0.0,
  ).animate(CurvedAnimation(
    parent: _swipeController,
    curve: Curves.easeOut,
  ));
  
  _swipeController.forward(from: 0.0).then((_) {
    setState(() {
      _dragDistance = 0.0;
    });
    
    // 🔧 追加：アニメーションをリセット
    _swipeController.reset();
    _swipeAnimation = Tween<double>(
      begin: 0.0,
      end: 0.0,
    ).animate(_swipeController);
  });
}


  void _initializeData() {
    _idealSelf = widget.idealSelf;
    _artistName = widget.artistName;
    _tasks = List.from(widget.tasks);
    
    if (widget.albumCoverImage != null) {
      _imageBytes = widget.albumCoverImage;
    }
    
    if (!widget.isPlayingSingleAlbum) {
      _loadAdditionalData();
    }
  }

  void _setupAnimations() {
  _slideController = AnimationController(
    duration: const Duration(milliseconds: 300),
    vsync: this,
  );
  
  _slideAnimation = Tween<Offset>(
    begin: const Offset(0, 1),
    end: Offset.zero,
  ).animate(CurvedAnimation(
    parent: _slideController,
    curve: Curves.easeInOut,
  ));

  // 自動再生ボタンのアニメーション設定
  _autoPlayController = AnimationController(
    duration: const Duration(milliseconds: 300),
    vsync: this,
  );

  _autoPlaySlideAnimation = Tween<double>(
    begin: 0.0,
    end: 1.0,
  ).animate(CurvedAnimation(
    parent: _autoPlayController,
    curve: Curves.easeInOut,
  ));

  _autoPlayColorAnimation = ColorTween(
    begin: Colors.white,
    end: const Color(0xFF1DB954),
  ).animate(CurvedAnimation(
    parent: _autoPlayController,
    curve: Curves.easeInOut,
  ));
  
  // 🔧 追加：スワイプアニメーション
  _swipeController = AnimationController(
    duration: const Duration(milliseconds: 300),
    vsync: this,
  );
  
  _swipeAnimation = Tween<double>(
    begin: 0.0,
    end: 0.0,
  ).animate(CurvedAnimation(
    parent: _swipeController,
    curve: Curves.easeOut,
  ))..addListener(() {
    setState(() {});
  });
}



  Future<void> _loadAdditionalData() async {
    final data = await _dataService.loadUserData();
    setState(() {
      _todayLyrics = data['todayLyrics'] ?? '今日という日を大切に生きよう\\n一歩ずつ理想の自分に近づいていく\\n昨日の自分を超えていこう\\n今この瞬間を輝かせよう';
      _aboutArtist = data['aboutArtist'] ?? 'あなたの人生という音楽の主人公。毎日新しい楽曲を作り続ける唯一無二のアーティスト。時には激しく、時には優しく、常に成長を続けている。今日もまた新しいメロディーを奏でている。';
      
      if (!widget.isPlayingSingleAlbum && widget.albumCoverImage == null) {
        final savedImageBytes = _dataService.getSavedImageBytes();
        if (savedImageBytes != null) {
          _imageBytes = savedImageBytes;
        }
      }
    });
  }

  Future<void> _loadTodayCompletions() async {
    if (widget.todayTaskCompletions != null) {
      setState(() {
        _todayTaskCompletions = Map.from(widget.todayTaskCompletions!);
      });
      return;
    }
    
    try {
      final completions = <String, int>{};
      for (final task in _tasks) {
        final count = await _taskCompletionService.getTodayTaskSuccesses(task.id);
        completions[task.id] = count;
      }
      setState(() {
        _todayTaskCompletions = completions;
      });
    } catch (e) {
      print('❌ 今日の完了回数読み込みエラー: $e');
    }
  }

  Future<void> _extractColorsFromImage() async {
  if (_isExtractingColors) return;
  
  setState(() {
    _isExtractingColors = true;
  });
  
  try {
    ImageProvider? imageProvider;
    
    if (widget.isPlayingSingleAlbum && widget.albumCoverImage != null) {
      imageProvider = MemoryImage(widget.albumCoverImage!);
    } else if (_imageBytes != null) {
      imageProvider = MemoryImage(_imageBytes!);
    } else if (widget.albumImagePath.isNotEmpty && File(widget.albumImagePath).existsSync()) {
      imageProvider = FileImage(File(widget.albumImagePath));
    }
    
    if (imageProvider != null) {
      final PaletteGenerator paletteGenerator = await PaletteGenerator.fromImageProvider(
        imageProvider,
        size: const Size(200, 200),
        maximumColorCount: 16,
      );
      
      if (mounted) {
        Color selectedColor = const Color(0xFF2D1B69); // フォールバック
        
        // 🔧 新規：彩度（saturation）をチェックする関数
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
  final population = paletteColor.population; // 出現頻度
  final saturation = getSaturation(color); // 彩度
  final luminance = color.computeLuminance(); // 明度
  
  double score = 0;
  
  // 🔧 修正1: 出現頻度のベーススコア（より柔軟に）
  if (population < 100) {
    score -= 500; // 極端に少ない色は除外
  } else if (population < 500) {
    score -= 100; // やや少ない色は減点
  } else if (population > 2000) {
    score += 150; // 多い色は加点（ただし後で彩度チェック）
  } else {
    score += 50; // 適度な出現頻度
  }
  
  // 🔧 修正2: 彩度を最重視（Spotifyスタイル）
  if (saturation > 0.4) {
    score += 300; // 高彩度の色を大幅優遇
  } else if (saturation > 0.25) {
    score += 150; // 中程度の彩度も評価
  } else if (saturation < 0.15) {
    score -= 400; // 無彩色（白・グレー・黒）を大幅減点
  }
  
  // 🔧 修正3: 明度の評価（暗すぎず明るすぎず）
  if (luminance < 0.1) {
    score -= 200; // 真っ黒に近い色は減点
  } else if (luminance > 0.85) {
    score -= 300; // 真っ白に近い色は大幅減点
  } else if (luminance >= 0.2 && luminance <= 0.6) {
    score += 100; // 適度な明度は加点
  }
  
  // 🔧 修正4: 彩度と出現頻度の組み合わせボーナス
  if (saturation > 0.3 && population > 1000) {
    score += 200; // 特徴的で目立つ色にボーナス
  }
  
  // 🔧 修正5: 極端な色相の調整（オレンジ・赤・青・紫を優遇）
  final hue = HSLColor.fromColor(color).hue;
  if ((hue >= 0 && hue <= 30) ||     // 赤
      (hue >= 180 && hue <= 240) ||  // 青
      (hue >= 270 && hue <= 330)) {  // 紫・マゼンタ
    score += 50; // 視覚的に印象的な色相にボーナス
  }
  
  print('🎨 色スコア: $color - sat:${saturation.toStringAsFixed(2)}, lum:${luminance.toStringAsFixed(2)}, pop:$population, hue:${hue.toStringAsFixed(0)}, score:${score.toStringAsFixed(1)}');
  
  return score;
}
        
        // 🔧 変更：全ての色をスコアリングして最適な色を選択
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
          // スコアが最も高い色を選択
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
          print('🎨 最終選択色: $selectedColor (score: ${bestScore.toStringAsFixed(1)})');
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

  @override
void dispose() {
  _slideController.dispose();
  _autoPlayController.dispose();
  _swipeController.dispose();
  _contentScrollController.dispose(); // 🔧 追加
  _audioService.dispose();
  super.dispose();
}

  // 自動再生ボタンの処理（ユーザー操作のみ通知）
void _toggleAutoPlay() {
  setState(() {
    _isAutoPlayEnabled = !_isAutoPlayEnabled;
  });

  if (_isAutoPlayEnabled) {
    _autoPlayController.forward();
    print('🔄 PlayerScreen: ユーザーが自動再生を有効化');
  } else {
    _autoPlayController.reverse();
    print('⏸️ PlayerScreen: ユーザーが自動再生を無効化');
  }
  
  // ユーザーの直接操作なので通知
  if (widget.onStateChanged != null) {
    widget.onStateChanged!(
      isAutoPlayEnabled: _isAutoPlayEnabled,
    );
  }
}

  void _togglePlayPause() {
  // 🔧 修正：理想像ページでは何もしない
  if (_currentIndex == 0 && !widget.isPlayingSingleAlbum) {
    print('🔧 PlayerScreen: 理想像ページでは再生/一時停止できません');
    return;
  }
  
  // より広範囲の保護
  if (_isForcePageChange) {
    print('🔧 PlayerScreen: 強制ページ変更中のため_togglePlayPause()を無視');
    return;
  }
  
  // バックグラウンド復帰直後の保護（2秒間）
  if (!_isInitializationComplete) {
    print('🔧 PlayerScreen: 初期化未完了のため_togglePlayPause()を無視');
    return;
  }
  
  print('🔧 PlayerScreen: _togglePlayPause() が呼ばれました - 現在の状態: $_isPlaying');
  
  setState(() {
    _isPlaying = !_isPlaying;
  });
  
  if (widget.onStateChanged != null) {
    widget.onStateChanged!(
      isPlaying: _isPlaying,
    );
  }
  
  print('🔧 PlayerScreen: ユーザー操作による再生状態変更: $_isPlaying');
}

  // 🔧 修正: タスク完了ボタンタップ処理（簡略化）
  Future<void> _onTaskCompletionTap() async {
    if (_currentIndex == 0 && !widget.isPlayingSingleAlbum) {
      return;
    }
    
    final actualTaskIndex = widget.isPlayingSingleAlbum ? _currentIndex : _currentIndex - 1;
    if (actualTaskIndex < 0 || actualTaskIndex >= _tasks.length) {
      return;
    }
    
    final currentTask = _tasks[actualTaskIndex];
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CompletionDialog(
        task: currentTask,
        albumName: _idealSelf,
        elapsedSeconds: _elapsedSeconds,
        onYes: () async {
          Navigator.of(context).pop();
          await _recordTaskCompletion(currentTask, true);
          _resetProgressOnly();
        },
        onNo: () async {
          Navigator.of(context).pop();
          await _recordTaskCompletion(currentTask, false);
          _resetProgressOnly();
        },
        onCancel: () {
          Navigator.of(context).pop();
          _resetProgressOnly();
        },
      ),
    );
  }

  // 🔧 修正: 進捗リセット処理（MainWrapperに通知）
  void _resetProgressOnly() {
  setState(() {
    _elapsedSeconds = 0;
    _currentProgress = 0.0;
    _isPlaying = false;
    _isAutoPlayEnabled = false; // 🔧 修正：自動再生もリセット
  });
  
  // 🔧 修正：自動再生アニメーションもリセット
  _autoPlayController.reverse();
  
  // MainWrapperに状態リセットを通知
  if (widget.onStateChanged != null) {
    widget.onStateChanged!(
      isPlaying: false,
      progress: 0.0,
      elapsedSeconds: 0,
      isAutoPlayEnabled: false, // 🔧 修正：自動再生リセットも通知
    );
  }
  
  print('🔧 PlayerScreen: 進捗リセットをMainWrapperに通知');
}

  Future<void> _recordTaskCompletion(TaskItem task, bool wasSuccessful) async {
  try {
    if (wasSuccessful) {
      await _audioService.playAchievementSound();
    } else {
      await _audioService.playNotificationSound();
    }

    int oldCount = 0;
    if (wasSuccessful) {
      oldCount = _todayTaskCompletions[task.id] ?? 0;
      setState(() {
        _todayTaskCompletions[task.id] = oldCount + 1;
      });
      print('🔔 即座にカウント更新: ${task.title} ${oldCount} → ${oldCount + 1}');
      
      // 新規追加：新しく完了したタスクをSharedPreferencesに記録
      await _recordNewTaskCompletion();
    }

    if (widget.onTaskCompleted != null) {
      await widget.onTaskCompleted!(task, wasSuccessful);
      
      if (wasSuccessful) {
        widget.onCompletionCountsChanged?.call(_todayTaskCompletions);
      }
    } else {
      await _taskCompletionService.recordTaskCompletion(
        taskId: task.id,
        taskTitle: task.title,
        wasSuccessful: wasSuccessful,
        elapsedSeconds: _elapsedSeconds,
        albumType: widget.isPlayingSingleAlbum ? 'single' : 'life_dream',
        albumName: _idealSelf,
        albumId: widget.isPlayingSingleAlbum ? 'single_album_id' : null,
      );
      
      if (wasSuccessful) {
        widget.onCompletionCountsChanged?.call(_todayTaskCompletions);
      }
      
      await _loadTodayCompletions();
    }
    
    widget.onDataChanged?.call();
    
    /*
    if (wasSuccessful) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ 「${task.title}」の達成を記録しました！'),
          backgroundColor: const Color(0xFF1DB954),
          duration: const Duration(seconds: 2),
        ),
      );
    }
    */

  } catch (e) {
    if (wasSuccessful) {
      setState(() {
        _todayTaskCompletions[task.id] = (_todayTaskCompletions[task.id] ?? 1) - 1;
      });
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ 記録の保存に失敗しました'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// 新規追加メソッド
Future<void> _recordNewTaskCompletion() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final currentCount = prefs.getInt('new_completed_tasks') ?? 0;
    await prefs.setInt('new_completed_tasks', currentCount + 1);
    print('新規完了タスクを記録: ${currentCount + 1}個目');
  } catch (e) {
    print('新規完了タスク記録エラー: $e');
  }
}

  Future<void> _navigateToSettings() async {
    if (widget.onNavigateToSettings != null) {
      widget.onNavigateToSettings!();
    }
  }

  void _navigateToAlbumDetail() {
    if (widget.onNavigateToAlbumDetail != null) {
      widget.onNavigateToAlbumDetail!();
    }
  }

  String _getCurrentTitle() {
    if (_currentIndex == 0) {
      if (widget.isPlayingSingleAlbum) {
        return _tasks.isNotEmpty ? _tasks[0].title : _idealSelf;
      }
      return _idealSelf;
    } else {
      final taskIndex = widget.isPlayingSingleAlbum ? _currentIndex : _currentIndex - 1;
      if (taskIndex < _tasks.length) {
        return _tasks[taskIndex].title;
      }
      return '';
    }
  }

  String _getCurrentDescription() {
    if (_currentIndex == 0) {
      if (widget.isPlayingSingleAlbum) {
        return _tasks.isNotEmpty ? _tasks[0].description : '';
      }
      return _todayLyrics;
    } else {
      final taskIndex = widget.isPlayingSingleAlbum ? _currentIndex : _currentIndex - 1;
      if (taskIndex < _tasks.length) {
        return _tasks[taskIndex].description;
      }
      return '';
    }
  }

  double _getCurrentTimeProgress() {
  if (_currentIndex == 0 && !widget.isPlayingSingleAlbum) {
    final now = DateTime.now();
    final totalMinutes = now.hour * 60 + now.minute;
    const totalMinutesInDay = 24 * 60;
    return (totalMinutes / totalMinutesInDay).clamp(0.0, 1.0);
  } else {
    // 🔧 修正: 常に最新値を使用し、ログ出力で確認
    final progress = widget.initialProgress ?? _currentProgress;
    final finalProgress = progress.clamp(0.0, 1.0);
    print('🔧 PlayerScreen進捗計算: widget=${widget.initialProgress}, local=$_currentProgress, final=$finalProgress');
    return finalProgress;
  }
}

// 既存のメソッドを以下に変更
String _getCurrentTime() {
  if (_currentIndex == 0 && !widget.isPlayingSingleAlbum) {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  } else {
    // 🔧 修正: MainWrapperからの最新値を常に使用
    final elapsedSeconds = widget.initialElapsedSeconds ?? _elapsedSeconds;
    final minutes = elapsedSeconds ~/ 60;
    final seconds = elapsedSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

  String _getTotalTime() {
    if (_currentIndex == 0 && !widget.isPlayingSingleAlbum) {
      return '24:00';
    } else {
      TaskItem? currentTask;
      
      if (widget.isPlayingSingleAlbum) {
        if (_currentIndex >= 0 && _currentIndex < _tasks.length) {
          currentTask = _tasks[_currentIndex];
        }
      } else {
        if (_currentIndex > 0 && _currentIndex - 1 < _tasks.length) {
          currentTask = _tasks[_currentIndex - 1];
        }
      }
      
      if (currentTask != null) {
        return '${currentTask.duration.toString().padLeft(2, '0')}:00';
      }
      return '00:00';
    }
  }

  @override
Widget build(BuildContext context) {
  final screenWidth = MediaQuery.of(context).size.width;
  final horizontalPadding = 20.0;
  final albumMargin = 10.0;
  final albumLeftPosition = horizontalPadding + albumMargin;
  final coverSize = screenWidth - 60;
  
  return NotificationListener<ScrollNotification>(
    onNotification: (notification) {
      if (notification is ScrollUpdateNotification) {
        setState(() {
          _isScrollAtTop = _contentScrollController.position.pixels <= 0;
        });
      }
      return false;
    },
    child: Container(
      height: MediaQuery.of(context).size.height,
      width: MediaQuery.of(context).size.width,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(_dominantColor, Colors.black, 0.3)!,
            Color.lerp(_dominantColor, Colors.black, 0.5)!,
            Colors.black,
          ],
          stops: const [0.0, 0.6, 1.0],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top + 10),
          
          Expanded(
            child: Listener(
              onPointerDown: (event) {
                _shouldPassGestureToParent = false;
              },
              onPointerMove: (event) {
                if (_isScrollAtTop && event.delta.dy > 0 && !_shouldPassGestureToParent) {
                  setState(() {
                    _shouldPassGestureToParent = true;
                  });
                }
              },
              onPointerUp: (event) {
                setState(() {
                  _shouldPassGestureToParent = false;
                });
              },
              onPointerCancel: (event) {
                setState(() {
                  _shouldPassGestureToParent = false;
                });
              },
              child: SingleChildScrollView(
                controller: _contentScrollController,
                physics: _shouldPassGestureToParent 
                    ? const NeverScrollableScrollPhysics()
                    : const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                      child: Column(
                        children: [
                          const SizedBox(height: 10),
                          _buildHeader(),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                    
                    _buildSwipeableAlbumCovers(screenWidth),
                    
                    const SizedBox(height: 20),
                    
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPageIndicator(),
                          
                          const SizedBox(height: 30),
                          
                          Padding(
                            padding: EdgeInsets.only(left: albumLeftPosition - horizontalPadding),
                            child: _buildSongInfoWithCompletionButton(),
                          ),
                          
                          const SizedBox(height: 30),
                          
                          Center(
                            child: SizedBox(
                              width: coverSize,
                              child: _buildProgressBar(),
                            ),
                          ),
                          
                          const SizedBox(height: 10),
                          
                          _buildControls(),
                          
                          const SizedBox(height: 30),
                          
                          // 🆕 新規追加: Lyric Notesウィジェット
                          if (_shouldShowLyricNotes())
                            Center(
                              child: _buildLyricNotes(coverSize),
                            ),
                          
                          // 🗑️ 削除: _buildCurrentContent() の呼び出しを削除
                          // 🗑️ 削除: _buildAboutArtistSection() の呼び出しを削除
                          
                          SizedBox(height: MediaQuery.of(context).padding.bottom + 30),
                        ],
                      ),
                    ),
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
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      GestureDetector(
        onTap: widget.onClose ?? () => Navigator.pop(context),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: const Icon(
            Icons.keyboard_arrow_down,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
      Text(
        _idealSelf, // 🔧 変更：'Uptify' → _idealSelf
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
          fontFamily: 'SF Pro Text',
        ),
      ),
      GestureDetector(
        onTap: _navigateToSettings,
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
  );
}

  Widget _buildSwipeableAlbumCovers(double screenWidth) {
  final scrollHeight = screenWidth - 60;
  final scrollWidth = scrollHeight;
  final coverSize = scrollHeight;
  final itemSpacing = 20.0;
  
  return Center(
    child: SizedBox(
      width: scrollWidth,
      height: scrollHeight,
      child: GestureDetector(
        onHorizontalDragStart: _handleSwipeStart,
        onHorizontalDragUpdate: _handleSwipeUpdate,
        onHorizontalDragEnd: _handleSwipeEnd,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 前のジャケット（画面外）
            if (_currentIndex > 0)
              _buildPositionedJacket(
                index: _currentIndex - 1,
                offset: (_isDragging ? _dragDistance : _swipeAnimation.value) - coverSize - 40,
                coverSize: coverSize,
              ),
            
            // 現在のジャケット
            _buildPositionedJacket(
              index: _currentIndex,
              offset: _isDragging ? _dragDistance : _swipeAnimation.value,
              coverSize: coverSize,
            ),
            
            // 次のジャケット（画面外）
            if (_currentIndex < (widget.isPlayingSingleAlbum ? _tasks.length : _tasks.length + 1) - 1)
              _buildPositionedJacket(
                index: _currentIndex + 1,
                offset: (_isDragging ? _dragDistance : _swipeAnimation.value) + coverSize + 40,
                coverSize: coverSize,
              ),
          ],
        ),
      ),
    ),
  );
}
Widget _buildPositionedJacket({
  required int index,
  required double offset,
  required double coverSize,
}) {
  return Positioned(
    left: offset,
    child: Container(
      width: coverSize,
      height: coverSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        // 🔧 影を削除（boxShadowなし）
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _buildAlbumCover(index, coverSize),
      ),
    ),
  );
}
Widget _buildAlbumCover(int index, double size) {
  Widget imageWidget;
  
  if (widget.isPlayingSingleAlbum) {
    if (widget.albumCoverImage != null) {
      imageWidget = Image.memory(
        widget.albumCoverImage!,
        width: size,
        height: size,
        fit: BoxFit.cover, // 🔧 正方形内で画像を表示
      );
    } else {
      imageWidget = _buildDefaultAlbumCover(size, isSingle: true);
    }
  } else {
    if (_imageBytes != null) {
      imageWidget = Image.memory(
        _imageBytes!,
        width: size,
        height: size,
        fit: BoxFit.cover,
      );
    } else if (widget.albumImagePath.isNotEmpty && File(widget.albumImagePath).existsSync()) {
      imageWidget = Image.file(
        File(widget.albumImagePath),
        width: size,
        height: size,
        fit: BoxFit.cover,
      );
    } else {
      imageWidget = _buildDefaultAlbumCover(size, isSingle: false);
    }
  }
  
  // 🔧 確実に正方形を保証
  return SizedBox(
    width: size,
    height: size,
    child: imageWidget,
  );
}

Widget _buildDefaultAlbumCover(double size, {required bool isSingle}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isSingle
            ? [
                const Color(0xFF8B5CF6),
                const Color(0xFF06B6D4),
              ]
            : [
                const Color(0xFF1DB954),
                const Color(0xFF1ED760),
                const Color(0xFF17A2B8),
              ],
      ),
    ),
    child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSingle ? Icons.music_note : Icons.album,
            size: 80,
            color: Colors.white,
          ),
          const SizedBox(height: 16),
          Text(
            isSingle ? 'アルバム' : '理想像',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w300,
              fontFamily: 'Hiragino Sans',
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildPageIndicator() {
    final totalPages = widget.isPlayingSingleAlbum ? _tasks.length : _tasks.length + 1;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalPages, (index) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: _currentIndex == index ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: _currentIndex == index 
                ? Colors.white 
                : Colors.white.withOpacity(0.3),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  Widget _buildSongInfoWithCompletionButton() {
  final showCompletionButton = !(_currentIndex == 0 && !widget.isPlayingSingleAlbum);
  
  int completionCount = 0;
  if (showCompletionButton) {
    final actualTaskIndex = widget.isPlayingSingleAlbum ? _currentIndex : _currentIndex - 1;
    if (actualTaskIndex >= 0 && actualTaskIndex < _tasks.length) {
      final currentTask = _tasks[actualTaskIndex];
      completionCount = _todayTaskCompletions[currentTask.id] ?? 0;
    }
  }
  
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: _navigateToAlbumDetail,
              child: Text(
                _getCurrentTitle(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Hiragino Sans',
                ),
              ),
            ),
            GestureDetector(
              onTap: _navigateToAlbumDetail,
              child: Text(
                _artistName,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 16,
                  fontWeight: FontWeight.w300,
                  fontFamily: 'Hiragino Sans',
                ),
              ),
            ),
          ],
        ),
      ),
      
      if (showCompletionButton) ...[
        const SizedBox(width: 8), // 🔧 修正: 16 → 8（間隔を狭める）
        Column(
          children: [
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _onTaskCompletionTap,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: completionCount > 0
                    ? Text(
                        completionCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'SF Pro Text',
                        ),
                      )
                    : SizedBox(
                        width: 20,
                        height: 20,
                        child: CustomPaint(
                          painter: ThickPlusPainter(),
                        ),
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 10), // 🆕 追加: 右側に余白を追加してジャケットの右端より内側に
      ],
    ],
  );
}

  Widget _buildProgressBar() {
  return Column(
    children: [
      SliderTheme(
        data: SliderTheme.of(context).copyWith(
          activeTrackColor: Colors.white,
          inactiveTrackColor: Colors.white.withOpacity(0.3),
          thumbColor: Colors.white,
          thumbShape: const RoundSliderThumbShape(
            enabledThumbRadius: 6,
          ),
          overlayShape: const RoundSliderOverlayShape(
            overlayRadius: 12,
          ),
          trackHeight: 4,
          trackShape: const RoundedRectSliderTrackShape(),
          overlayColor: Colors.transparent,
          padding: EdgeInsets.zero, // 🔧 パディングを0に
        ),
        child: Slider(
          value: _getCurrentTimeProgress().clamp(0.0, 1.0),
          onChanged: (value) {},
        ),
      ),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _getCurrentTime(),
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              fontFamily: 'SF Pro Text',
            ),
          ),
          Text(
            _getTotalTime(),
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
              fontWeight: FontWeight.w300,
              fontFamily: 'SF Pro Text',
            ),
          ),
        ],
      ),
    ],
  );
}
 Widget _buildControls() {
    final screenWidth = MediaQuery.of(context).size.width;
    final coverSize = screenWidth - 60;
    
    // 🔧 現在のタスクを取得
    TaskItem? currentTask;
    if (_currentIndex > 0 || widget.isPlayingSingleAlbum) {
      final actualTaskIndex = widget.isPlayingSingleAlbum ? _currentIndex : _currentIndex - 1;
      if (actualTaskIndex >= 0 && actualTaskIndex < _tasks.length) {
        currentTask = _tasks[actualTaskIndex];
      }
    }
    
    // 🔧 アシストボタンが有効かチェック
    final bool isAssistButtonEnabled = currentTask?.assistUrl != null && 
                                       currentTask!.assistUrl!.isNotEmpty;
    
    return SizedBox(
      width: screenWidth,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 🔧 左右のボタン配置（ジャケット幅に合わせる）
          Center(
            child: SizedBox(
              width: coverSize,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 左端：シャッフルボタン → アシストボタンに変更
                  _buildAssistButton(
                    isEnabled: isAssistButtonEnabled,
                    onTap: isAssistButtonEnabled
                        ? () => _launchAssistUrl(currentTask!.assistUrl!)
                        : null,
                  ),
                  
                  const Spacer(),
                  
                  // 右端：自動再生ボタン
                  _buildAutoPlayButton(),
                ],
              ),
            ),
          ),
          
          // 🔧 中央：再生ボタンとその左右のスキップ・戻るボタン
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 戻るボタン（再生ボタンの左）
              _buildControlButton(
                icon: Icons.skip_previous,
                onTap: () {
                  if (_currentIndex > 0) {
                    _animateToPage(_currentIndex - 1);
                  }
                },
                size: 34,
                color: Colors.white,
              ),
              
              const SizedBox(width: 24),
              
              // 再生ボタン（中央）
GestureDetector(
  onTap: _togglePlayPause,
  child: Container(
    width: 64,
    height: 64,
    decoration: const BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
    ),
    alignment: Alignment.center,
    child: Icon(
      // 🔧 修正：シングルアルバムとライフドリームアルバムで分岐
      _getPlayPauseIcon(),
      color: Colors.black,
      size: 38,
    ),
  ),
),
              
              const SizedBox(width: 24),
              
              // スキップボタン（再生ボタンの右）
              _buildControlButton(
                icon: Icons.skip_next,
                onTap: () {
                  final maxIndex = widget.isPlayingSingleAlbum ? _tasks.length - 1 : _tasks.length;
                  if (_currentIndex < maxIndex) {
                    _animateToPage(_currentIndex + 1);
                  }
                },
                size: 34,
                color: Colors.white,
              ),
            ],
          ),
        ],
      ),
    );
  }

// 🔧 修正版: アシストURLを起動
  Future<void> _launchAssistUrl(String url) async {
    try {
      // 🆕 URLの正規化（https:// を自動追加）
      String normalizedUrl = url.trim();
      
      // プロトコルがない場合は https:// を追加
      if (!normalizedUrl.startsWith('http://') && 
          !normalizedUrl.startsWith('https://')) {
        normalizedUrl = 'https://$normalizedUrl';
      }
      
      print('🔗 URL起動試行: $normalizedUrl (元: $url)');
      
      final Uri uri = Uri.parse(normalizedUrl);
      
      // URLが起動可能かチェック
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication, // 外部ブラウザ/アプリで開く
        );
        print('✅ アシストURL起動成功: $normalizedUrl');
      } else {
        // 起動できない場合のエラー処理
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'URLを開けませんでした: $normalizedUrl',
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
              duration: const Duration(seconds: 3),
            ),
          );
        }
        print('❌ URL起動失敗: $normalizedUrl');
      }
    } catch (e) {
      print('❌ URL起動エラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'URL起動時にエラーが発生しました',
                    style: TextStyle(fontFamily: 'Hiragino Sans'),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Widget _buildAutoPlayButton() {
    return GestureDetector(
      onTap: _toggleAutoPlay,
      child: AnimatedBuilder(
        animation: _autoPlayController,
        builder: (context, child) {
          return Container(
            width: 48,
            height: 28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: _autoPlayColorAnimation.value ?? Colors.white,
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
              boxShadow: _isAutoPlayEnabled ? [
                BoxShadow(
                  color: const Color(0xFF1DB954).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ] : null,
            ),
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  left: _isAutoPlayEnabled ? 22 : 2,
                  top: 2,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isAutoPlayEnabled ? Colors.white : Colors.grey[600],
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          _isAutoPlayEnabled ? Icons.play_arrow : Icons.stop,
                          key: ValueKey(_isAutoPlayEnabled),
                          size: 14,
                          color: _isAutoPlayEnabled ? const Color(0xFF1DB954) : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // 🆕 新規メソッド: アシストボタンの構築
  Widget _buildAssistButton({
    required bool isEnabled,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: Icon(
        Icons.open_in_new,
        color: isEnabled 
            ? Colors.white 
            : Colors.white.withOpacity(0.3),
        size: 26,
      ),
    );
  }

  Widget _buildControlButton({
  required IconData icon,
  required VoidCallback onTap,
  required double size,
  Color? color, // 🔧 追加：色指定
}) {
  return GestureDetector(
    onTap: onTap,
    child: Icon(
      icon,
      color: color ?? Colors.white.withOpacity(0.7), // 🔧 デフォルトは半透明白
      size: size,
    ),
  );
}

  

  // 🆕 新規追加メソッド1: Lyric Notesを表示すべきか判定
bool _shouldShowLyricNotes() {
  // 最初のページ（理想の自分）では表示しない
  if (_currentIndex == 0 && !widget.isPlayingSingleAlbum) {
    return false;
  }
  
  // タスクが存在するか確認
  final task = _getCurrentTask();
  return task != null;
}


/// 🔧 修正: 現在のタスクを取得（Lyric Note付き）
TaskItem? _getCurrentTask() {
  TaskItem? task;
  
  if (widget.isPlayingSingleAlbum) {
    if (_currentIndex >= 0 && _currentIndex < _tasks.length) {
      task = _tasks[_currentIndex];
    }
  } else {
    if (_currentIndex > 0 && _currentIndex - 1 < _tasks.length) {
      task = _tasks[_currentIndex - 1];
    }
  }
  
  if (task == null) return null;
  
  // 🔧 修正: 保存されたLyric Notes（階層構造）を反映
  if (_taskLyricNotes.containsKey(task.id)) {
    final notesFromMap = _taskLyricNotes[task.id]!;
    print('📝 タスク "${task.title}" のメモ取得: ${notesFromMap.length}行 (taskId: ${task.id})'); // 🔧 追加
    return task.copyWith(lyricNotes: notesFromMap);
  }
  
  print('📝 タスク "${task.title}" のメモなし (taskId: ${task.id})'); // 🔧 追加
  return task;
}


Widget _buildLyricNotes(double coverSize) {
  final task = _getCurrentTask();
  if (task == null) {
    return const SizedBox.shrink();
  }
  
  print('🎨 LyricNotesWidget構築: タスク="${task.title}", ID=${task.id}, メモ数=${task.lyricNotes?.length ?? 0}'); // 🔧 追加
  
  return LyricNotesWidget(
    task: task,
    albumWidth: coverSize,
    albumColor: _dominantColor,
    albumId: widget.playingSingleAlbumId,
    isSingleAlbum: widget.isPlayingSingleAlbum,
    onNoteSaved: (taskId, notes) async {
      print('💾 onNoteSaved呼び出し: taskId=$taskId, notes=${notes.length}行'); // 🔧 追加
      
      // 🔧 修正: まずローカル変数を更新
      setState(() {
        _taskLyricNotes[taskId] = notes;
        
        // 🆕 追加: _tasksリストも更新
        final taskIndex = _tasks.indexWhere((t) => t.id == taskId);
        if (taskIndex != -1) {
          _tasks[taskIndex] = _tasks[taskIndex].copyWith(lyricNotes: notes);
          print('✅ _tasksリスト更新: index=$taskIndex, notes=${notes.length}行'); // 🔧 追加
        }
      });
      
      print('✅ PlayerScreen: Lyric Notes更新完了 (${notes.length}行)');
    },
  );
}

/// 🆕 再生/一時停止アイコンを取得
IconData _getPlayPauseIcon() {
  // ライフドリームアルバムの理想像ページ（index=0）は常に一時停止アイコン
  if (_currentIndex == 0 && !widget.isPlayingSingleAlbum) {
    return Icons.pause;
  }
  
  // シングルアルバムの場合：_isPlayingの値で判定
  if (widget.isPlayingSingleAlbum) {
    return _isPlaying ? Icons.pause : Icons.play_arrow;
  }
  
  // ライフドリームアルバムのタスク（index≥1）：_isPlayingの値で判定
  return _isPlaying ? Icons.pause : Icons.play_arrow;
}
}
