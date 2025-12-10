// charts_screen.dart - シンプル化版
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart'; 
import 'dart:async';
import 'dart:typed_data';  // 新規追加
import '../services/charts_service.dart';
import '../services/task_completion_service.dart';
import '../services/data_service.dart';  // 新規追加
import '../models/concert_data.dart';
import '../widgets/concert_stage.dart';
import '../widgets/performer_widget.dart';
import '../widgets/audience_grid.dart';



// ファン入場データモデル
class FanEntranceData {
  final int currentAudience;
  final int stockedFans;
  final int totalCompletedTasks;
  
  const FanEntranceData({
    required this.currentAudience,
    required this.stockedFans,
    required this.totalCompletedTasks,
  });
  
  FanEntranceData copyWith({
    int? currentAudience,
    int? stockedFans,
    int? totalCompletedTasks,
  }) {
    return FanEntranceData(
      currentAudience: currentAudience ?? this.currentAudience,
      stockedFans: stockedFans ?? this.stockedFans,
      totalCompletedTasks: totalCompletedTasks ?? this.totalCompletedTasks,
    );
  }
}

class ChartsScreen extends StatefulWidget {
  final VoidCallback? onClose;
  
  const ChartsScreen({
    super.key,
    this.onClose,
  });

  @override
  State<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends State<ChartsScreen> {
  late final ChartsService _chartsService;
  late final TaskCompletionService _taskCompletionService;
  late final AudioPlayer _audioPlayer;
  FanEntranceData? _fanData;
  bool _isLoading = true;
  String _errorMessage = '';
  bool _isEntering = false;
  int _lastKnownTaskCount = 0;
  Uint8List? _userImageBytes; 
  int _enteringFansCount = 0;
  

  @override
void initState() {
  super.initState();
  _chartsService = ChartsService();
  _taskCompletionService = TaskCompletionService();
  _audioPlayer = AudioPlayer();
  _loadConcertData();
  _startTaskMonitoring();
}

@override
void dispose() {
  _audioPlayer.dispose();
  super.dispose();
}

// ユーザーの顔写真を読み込み
Future<void> _loadUserImage() async {
  try {
    print('📸 ユーザー画像読み込み開始...');
    final dataService = DataService();
    final imageBytes = await dataService.loadIdealImageBytes();
    
    print('📸 読み込み結果: ${imageBytes != null ? "${imageBytes.length} bytes" : "null"}');
    
    if (mounted && imageBytes != null) {
      setState(() {
        _userImageBytes = imageBytes;
      });
      print('✅ ユーザー画像読み込み完了: ${imageBytes.length} bytes');
    } else {
      print('⚠️ ユーザー画像がありません');
    }
  } catch (e) {
    print('❌ ユーザー画像読み込みエラー: $e');
  }
}

  // シンプルなタスク監視
  void _startTaskMonitoring() {
    Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        _checkForNewTasks();
      } else {
        timer.cancel();
      }
    });
  }

  // 新規タスクチェック（シンプル版）
  Future<void> _checkForNewTasks() async {
    try {
      final currentTotalTasks = await _taskCompletionService.getTotalCompletedTasks();
      
      if (currentTotalTasks > _lastKnownTaskCount) {
        final newTasks = currentTotalTasks - _lastKnownTaskCount;
        
        if (mounted && _fanData != null) {
          setState(() {
            _fanData = _fanData!.copyWith(
              stockedFans: _fanData!.stockedFans + newTasks,
              totalCompletedTasks: currentTotalTasks,
            );
          });
          print('新規タスク${newTasks}個完了 → 待機ファン${_fanData!.stockedFans}人');
        }
        
        _lastKnownTaskCount = currentTotalTasks;
      }
    } catch (e) {
      print('タスク監視エラー: $e');
    }
  }

  Future<void> _loadConcertData() async {
  try {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    // 画像読み込みを先に実行
    await _loadUserImage();

    final data = await _chartsService.getConcertData();
    
    if (mounted) {
      final waitingFans = (data.totalCompletedTasks - data.audienceCount).clamp(0, data.totalCompletedTasks);
      
      setState(() {
        _fanData = FanEntranceData(
          currentAudience: data.audienceCount,
          stockedFans: waitingFans,
          totalCompletedTasks: data.totalCompletedTasks,
        );
        _lastKnownTaskCount = data.totalCompletedTasks;
        _isLoading = false;
      });
      
      print('初期データ読み込み完了 - 観客数: ${data.audienceCount}, 累計タスク: ${data.totalCompletedTasks}, 待機ファン: $waitingFans');
    }
  } catch (e) {
    if (mounted) {
      setState(() {
        _errorMessage = 'Failed to load data';
        _isLoading = false;
      });
    }
    print('コンサートデータ読み込みエラー: $e');
  }
}

  // ファン入場処理（修正版：アニメーション完了後にDB更新）
Future<void> _handleFanEntrance() async {
  if (_fanData?.stockedFans == 0 || _isEntering) return;
  
  final enteringFans = _fanData!.stockedFans;
  
  // 効果音を再生（追加）
  _audioPlayer.play(AssetSource('sounds/crowd_cheer.mp3'));
  
  setState(() {
    _isEntering = true;
    _enteringFansCount = enteringFans;
  });
  
  await Future.delayed(const Duration(milliseconds: 3200));
  
  await _chartsService.addAudienceMembers(enteringFans);
  
  if (mounted) {
    setState(() {
      _fanData = _fanData!.copyWith(
        currentAudience: _fanData!.currentAudience + enteringFans,
        stockedFans: 0,
      );
      _enteringFansCount = 0;
      _isEntering = false;
    });
  }
  
  print('${enteringFans}人が入場完了 → 最終観客数: ${_fanData!.currentAudience}人');
}

  @override
Widget build(BuildContext context) {
  if (_isLoading) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      ),
    );
  }

  if (_errorMessage.isNotEmpty) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontFamily: 'Hiragino Sans',
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadConcertData,
              child: const Text('再試行'),
            ),
          ],
        ),
      ),
    );
  }

  final audienceCount = _fanData?.currentAudience ?? 0;

  return Scaffold(
    backgroundColor: Colors.black,
    body: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          // 背景レイヤー: コンサートステージ全画面表示
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final totalHeight = constraints.maxHeight;
                final screenHeight = totalHeight * 0.25;
                final screenTop = totalHeight * 0.15;
                final stageTop = screenTop + screenHeight;
                final stageHeight = totalHeight * 0.04;
                final performerY = stageTop + (stageHeight / 2);
                
                return Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black,
                      ),
                    ),
                    Positioned.fill(
                      child: ConcertStage(
                        width: constraints.maxWidth,
                        height: totalHeight,
                        imageAssetPath: 'assets/images/artistpic.png',
                        userImageBytes: _userImageBytes,
                      ),
                    ),
                    Positioned.fill(
                      child: AudienceGrid(
                        audienceCount: audienceCount,
                        width: constraints.maxWidth,
                        height: totalHeight,
                        stageHeight: stageTop + stageHeight + (totalHeight * 0.03),
                        enteringFansCount: _enteringFansCount,
                      ),
                    ),
                    Positioned(
                      top: performerY - 15,
                      left: constraints.maxWidth * 0.47,
                      child: const PerformerWidget(
                        size: 20,
                        color: Color(0xFF1DB954),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          
          // 前面レイヤー: UI要素
          Column(
            children: [
              // ヘッダー
              Container(
                height: 60,
                margin: const EdgeInsets.only(top: 20),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Your Concert',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        letterSpacing: -0.5,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Hiragino Sans',
                      ),
                    ),
                    if (widget.onClose != null)
                      GestureDetector(
                        onTap: widget.onClose,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              // 下部の情報パネル
              Padding(
                padding: const EdgeInsets.all(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[800]!.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _buildCompactInfo(
                        icon: Icons.group_add,
                        label: 'New',
                        value: '${_fanData?.stockedFans ?? 0}',
                        color: const Color(0xFF1DB954),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildCompactEntranceButton(),
                      ),
                      const SizedBox(width: 16),
                      _buildCompactInfo(
                        icon: Icons.people,
                        label: 'Venue',
                        value: _isLoading 
                          ? '...' 
                          : '${_fanData?.currentAudience ?? 0}',
                        color: const Color(0xFF1DB954),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

  Widget _buildStageContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontFamily: 'Hiragino Sans',
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadConcertData,
              child: const Text('再試行'),
            ),
          ],
        ),
      );
    }

    final audienceCount = _fanData?.currentAudience ?? 0;

    return Stack(
      children: [
        // コンサート会場表示（適切なサイズに調整）
Container(
  width: double.infinity,
  height: 475,  // 🔧 修正: 475 → 600（固定値で大きく）
  decoration: BoxDecoration(
    color: Colors.white.withOpacity(0.1),
    borderRadius: BorderRadius.circular(16),
  ),
  child: _buildStageContent(),
),
        Positioned.fill(
          child: _buildConcertScene(audienceCount),
        ),
      ],
    );
  }

  Widget _buildConcertScene(int audienceCount) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final totalHeight = constraints.maxHeight;
      final screenHeight = totalHeight * 0.25;
      final screenTop = totalHeight * 0.05;
      final stageTop = screenTop + screenHeight;
      final stageHeight = totalHeight * 0.04;
      final performerY = stageTop + (stageHeight / 2);
      
      return Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: const Color(0xFF2E7D32),
            ),
          ),
          Positioned.fill(
            child: ConcertStage(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              imageAssetPath: 'assets/images/artistpic.png',
              userImageBytes: _userImageBytes,
            ),
          ),
          Positioned.fill(
            child: AudienceGrid(
              audienceCount: audienceCount,
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              stageHeight: stageTop + stageHeight + (totalHeight * 0.03),
              enteringFansCount: _enteringFansCount,  // 新規追加: 入場人数を渡す
            ),
          ),
         Positioned(
  top: performerY - 15,
  left: constraints.maxWidth * 0.47,
  child: const PerformerWidget(
    size: 20,
    color: Color(0xFF1DB954),  // 修正: Colors.white → Color(0xFF1DB954)
  ),
),
        ],
      );
    },
  );
}

  // コンパクトな情報表示ウィジェット
  Widget _buildCompactInfo({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: color,
          size: 18,
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 10,
                fontFamily: 'SF Pro Display',
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'SF Pro Display',
              ),
            ),
          ],
        ),
      ],
    );
  }

  // コンパクトな入場ボタン
  Widget _buildCompactEntranceButton() {
    final stockedFans = _fanData?.stockedFans ?? 0;
    final hasStockedFans = stockedFans > 0;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: hasStockedFans && !_isEntering ? _handleFanEntrance : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: hasStockedFans 
              ? const Color(0xFF1DB954)
              : Colors.grey[600],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              _isEntering
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(
                    Icons.directions_run,
                    color: Colors.white,
                    size: 16,
                  ),
              const SizedBox(width: 6),
              Text(
                _isEntering 
                  ? 'Entering...'
                  : hasStockedFans 
                    ? 'Fans Enter'
                    : 'Play your tasks\nand be your own fan.',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'SF Pro Display',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}