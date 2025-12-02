// album_detail_screen.dart - タスク別プレイヤー移動対応版
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import 'dart:io';
import 'dart:typed_data';
import '../models/task_item.dart';
import '../models/lyric_note_item.dart';
import '../widgets/lyric_notes/lyric_notes_editor_screen.dart';
import '../services/data_service.dart';


class AlbumDetailScreen extends StatefulWidget {
  final String albumImagePath;
  final String idealSelf;
  final String artistName;
  final List<TaskItem> tasks;
  final Uint8List? imageBytes;
  final VoidCallback? onPlayPressed;
  final Function(int)? onPlayTaskPressed;
  final VoidCallback? onClose;
  final VoidCallback? onNavigateToSettings;
  final String? albumId;           // 🆕 追加
  final bool isSingleAlbum;        // 🆕 追加

  const AlbumDetailScreen({
    super.key,
    required this.albumImagePath,
    required this.idealSelf,
    required this.artistName,
    required this.tasks,
    this.imageBytes,
    this.onPlayPressed,
    this.onPlayTaskPressed,
    this.onClose,
    this.onNavigateToSettings,
    this.albumId,                  // 🆕 追加
    this.isSingleAlbum = false,    // 🆕 追加
  });

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  File? _albumImage;


  // 🆕 追加：背景色用のフィールド
  Color _dominantColor = const Color(0xFF2D1B69);
  Color _accentColor = const Color(0xFF1A1A2E);
  bool _isExtractingColors = false;

  @override
  void initState() {
    super.initState();
    
    if (widget.albumImagePath.isNotEmpty && File(widget.albumImagePath).existsSync()) {
      _albumImage = File(widget.albumImagePath);
    }
    
    // 🆕 追加：色抽出を開始
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _extractColorsFromImage();
    });
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
    if (widget.imageBytes != null) {
      imageProvider = MemoryImage(widget.imageBytes!);
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
        Color selectedColor = const Color(0xFF2D1B69);
        
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
    score += 150; // 多い色は加点
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
  
  print('🎨 AlbumDetail色スコア: $color - sat:${saturation.toStringAsFixed(2)}, lum:${luminance.toStringAsFixed(2)}, pop:$population, hue:${hue.toStringAsFixed(0)}, score:${score.toStringAsFixed(1)}');
  
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



  Widget _buildAlbumCover({double size = 280}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: widget.imageBytes != null
            ? Image.memory(
                widget.imageBytes!,
                width: size,
                height: size,
                fit: BoxFit.cover,
              )
            : _albumImage != null
                ? Image.file(
                    _albumImage!,
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
                          Color(0xFF17A2B8),
                        ],
                      ),
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.album,
                            size: 80,
                            color: Colors.white,
                          ),
                          SizedBox(height: 16),
                          Text(
                            '理想像',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w300,
                              fontFamily: 'Hiragino Sans',
                            ),
                          ),
                        ],
                      ),
                    ),
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

  String _formatDuration(int minutes) {
    return '${minutes}:00';
  }

  // album_detail_screen.dart

@override
Widget build(BuildContext context) {
  return Container(
    color: Colors.black,
    child: Container(
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
      ),
      child: Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top,
        ),
        child: Column(
          children: [
            // Back Button
            Padding(
              padding: const EdgeInsets.only(left: 20, top: 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: widget.onClose ?? () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: const Icon(
                        Icons.chevron_left,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // スクロール可能なコンテンツ
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      Center(child: _buildAlbumCover()),
                      const SizedBox(height: 20),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.idealSelf,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Hiragino Sans',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.artistName,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              fontFamily: 'Hiragino Sans',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          GestureDetector(
                            onTap: widget.onNavigateToSettings,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                Icons.settings,
                                color: Colors.white.withOpacity(0.7),
                                size: 24,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          GestureDetector(
                            // 🔧 修正: 理想像ページから再生する場合
                            onTap: () {
                              if (widget.onPlayTaskPressed != null) {
                                widget.onPlayTaskPressed!(-1); // 🔧 理想像ページから開始
                              } else {
                                widget.onPlayPressed?.call();
                              }
                            },
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: const BoxDecoration(
                                color: Color(0xFF1DB954),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.play_arrow,
                                color: Colors.black,
                                size: 32,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      _buildTrackList(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildTrackList() {
    return Column(
      children: [
        ...widget.tasks.asMap().entries.map((entry) {
          final index = entry.key;
          final task = entry.value;
          return _buildTrackItem(task, index);
        }).toList(),
      ],
    );
  }

  Widget _buildTrackItem(TaskItem task, int index) {
  return GestureDetector(
    onTap: () {
      print('🎵 タスクタップ: ${task.title} (index: $index)');
      
      if (widget.onPlayTaskPressed != null) {
        widget.onPlayTaskPressed!(index);
      } else if (widget.onPlayPressed != null) {
        widget.onPlayPressed!();
      }
    },
    child: Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Track Info (左詰め)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title.isEmpty ? 'タスク${index + 1}' : task.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Hiragino Sans',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (task.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    task.description,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w300,
                      fontFamily: 'Hiragino Sans',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // Duration (タスクの設定時間を表示)
          Text(
            _formatDuration(task.duration),
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
              fontWeight: FontWeight.w300,
              fontFamily: 'SF Pro Text',
            ),
          ),

          const SizedBox(width: 16),

          // 🔧 修正：鉛筆アイコンに変更
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              _openLyricNotesEditor(task, index);
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.edit_outlined, // 🔧 鉛筆アイコン
                color: Colors.white.withOpacity(0.6),
                size: 24,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// 🆕 新規追加：Lyric Notes エディタを開く
void _openLyricNotesEditor(TaskItem task, int index) async {
  // 🔧 修正：await で結果を待つ
  await Navigator.of(context).push(
    PageRouteBuilder(
      fullscreenDialog: true,
      opaque: true,
      pageBuilder: (context, animation, secondaryAnimation) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          )),
          child: LyricNotesEditorScreen(
            taskTitle: task.title.isEmpty ? 'タスク${index + 1}' : task.title,
            initialNotes: task.lyricNotes ?? [],
            backgroundColor: Colors.black,
            onSave: (notes) async {
              await _saveLyricNotes(task.id, notes);
            },
            onClose: () => Navigator.of(context).pop(),
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    ),
  );
  
  // 🔧 修正：エディタから戻った後、PlayerScreenを開く
  if (widget.onPlayTaskPressed != null) {
    widget.onPlayTaskPressed!(index);
  }
}

/// 🆕 新規追加：Lyric Notes を保存
Future<void> _saveLyricNotes(String taskId, List<LyricNoteItem> notes) async {
  try {
    final dataService = DataService();
    
    // 🔧 修正：シングルアルバムかライフドリームアルバムかで分岐
    if (widget.isSingleAlbum && widget.albumId != null) {
      // シングルアルバムの場合
      await dataService.updateSingleAlbumTaskLyricNotes(
        albumId: widget.albumId!,
        taskId: taskId,
        notes: notes,
      );
      print('✅ シングルアルバムのLyric Notes保存完了: $taskId (${notes.length}行)');
    } else {
      // ライフドリームアルバムの場合
      await dataService.updateTaskLyricNotes(taskId, notes);
      print('✅ ライフドリームアルバムのLyric Notes保存完了: $taskId (${notes.length}行)');
    }
    
    // タスクリストを更新
    setState(() {
      final taskIndex = widget.tasks.indexWhere((t) => t.id == taskId);
      if (taskIndex != -1) {
        widget.tasks[taskIndex] = widget.tasks[taskIndex].copyWith(
          lyricNotes: notes,
        );
      }
    });
    
  } catch (e) {
    print('❌ Lyric Notes保存エラー: $e');
  }
}

  void _showTrackOptions(TaskItem task, int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Track Info
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: task.color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getTaskIcon(index),
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title.isEmpty ? 'タスク${index + 1}' : task.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Hiragino Sans',
                          ),
                        ),
                        Text(
                          widget.artistName,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                            fontWeight: FontWeight.w300,
                            fontFamily: 'Hiragino Sans',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // Options
              _buildOptionItem(Icons.play_arrow, '再生', () {
                Navigator.pop(context);
                // 🎵 このタスクから再生開始
                if (widget.onPlayTaskPressed != null) {
                  widget.onPlayTaskPressed!(index);
                } else {
                  widget.onPlayPressed?.call();
                }
              }),
              _buildOptionItem(Icons.playlist_add, 'プレイリストに追加', () {
                Navigator.pop(context);
              }),
              _buildOptionItem(Icons.share, '共有', () {
                Navigator.pop(context);
              }),
              _buildOptionItem(Icons.info_outline, '詳細を表示', () {
                Navigator.pop(context);
              }),

              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOptionItem(IconData icon, String title, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 20),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w400,
                fontFamily: 'Hiragino Sans',
              ),
            ),
          ],
        ),
      ),
    );
  }
}