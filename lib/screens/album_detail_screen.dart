// album_detail_screen.dart - タスク別プレイヤー移動対応版
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import 'dart:io';
import 'dart:typed_data';
import '../models/task_item.dart';


class AlbumDetailScreen extends StatefulWidget {
  final String albumImagePath;
  final String idealSelf;
  final String artistName;
  final List<TaskItem> tasks;
  final Uint8List? imageBytes;
  final VoidCallback? onPlayPressed;
  final Function(int)? onPlayTaskPressed;
  final VoidCallback? onClose;
  final VoidCallback? onNavigateToSettings;  // 🆕 追加

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
    this.onNavigateToSettings,  // 🆕 追加
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
    color: Colors.black,  // 🔧 追加：背景を黒に
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
                            onTap: () {
                              if (widget.onPlayTaskPressed != null) {
                                widget.onPlayTaskPressed!(-1);
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
      // 🎵 タップしたタスクのインデックスを指定してプレイヤーを開く
      onTap: () {
        if (widget.onPlayTaskPressed != null) {
          widget.onPlayTaskPressed!(index); // タスクのインデックスを渡す
        } else {
          widget.onPlayPressed?.call();
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(vertical: 12),
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

            // More Options (3点横、右詰め)
            GestureDetector(
              onTap: () => _showTrackOptions(task, index),
              child: Icon(
                Icons.more_horiz,
                color: Colors.white.withOpacity(0.6),
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
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