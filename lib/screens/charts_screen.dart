// charts_screen.dart - シンプル化版
import 'package:flutter/material.dart';
import 'dart:async';
import '../services/charts_service.dart';
import '../services/task_completion_service.dart';
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
  FanEntranceData? _fanData;
  bool _isLoading = true;
  String _errorMessage = '';
  bool _isEntering = false;
  int _lastKnownTaskCount = 0;

  @override
  void initState() {
    super.initState();
    _chartsService = ChartsService();
    _taskCompletionService = TaskCompletionService();
    _loadConcertData();
    _startTaskMonitoring();
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

  // データ読み込み（シンプル版）
  Future<void> _loadConcertData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final data = await _chartsService.getConcertData();
      
      if (mounted) {
        // 待機ファン = 累計タスク - 現在観客
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
          _errorMessage = 'データの読み込みに失敗しました';
          _isLoading = false;
        });
      }
      print('コンサートデータ読み込みエラー: $e');
    }
  }

  // ファン入場処理（シンプル版）
  Future<void> _handleFanEntrance() async {
    if (_fanData?.stockedFans == 0 || _isEntering) return;
    
    setState(() {
      _isEntering = true;
    });
    
    final enteringFans = _fanData!.stockedFans;
    
    // 観客を入場させる
    await _chartsService.addAudienceMembers(enteringFans);
    
    setState(() {
      _fanData = _fanData!.copyWith(
        currentAudience: _fanData!.currentAudience + enteringFans,
        stockedFans: 0, // 待機ファンを完全にリセット
      );
      _isEntering = false;
    });
    
    print('${enteringFans}人が入場完了 → 待機ファンリセット');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ヘッダー
            Container(
              height: 60,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'あなたのコンサート',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
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
            
            const SizedBox(height: 20),
            
            // コンサート会場表示（適切なサイズに調整）
            Container(
              width: double.infinity,
              height: 475, 
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: _buildStageContent(),
            ),
            
            const SizedBox(height: 12),
            
            // 3つの情報をコンパクトな横並びで表示
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              
              ),
              child: Row(
                children: [
                  // 新規ファン数
                  _buildCompactInfo(
                    icon: Icons.group_add,
                    label: '新規',
                    value: '${_fanData?.stockedFans ?? 0}',
                    color: const Color(0xFF1DB954),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // 入場ボタン
                  Expanded(
                    child: _buildCompactEntranceButton(),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // 会場の人数
                  _buildCompactInfo(
                    icon: Icons.people,
                    label: '会場',
                    value: _isLoading 
                      ? '...' 
                      : '${_fanData?.currentAudience ?? 0}',
                    color: const Color(0xFF1DB954),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: MediaQuery.of(context).padding.bottom + 5),
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
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.black,
          ),
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
                videoAssetPath: 'assets/videos/concert_video.mp4',
              ),
            ),
            Positioned.fill(
              child: AudienceGrid(
                audienceCount: audienceCount,
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                stageHeight: stageTop + stageHeight + (totalHeight * 0.03),
              ),
            ),
            Positioned(
              top: performerY - 10,
              left: constraints.maxWidth * 0.48,
              child: const PerformerWidget(
                size: 20,
                color: Colors.white,
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
                    width: 16,
                    height: 16,
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
                  ? '入場中...'
                  : hasStockedFans 
                    ? 'ファン入場！'
                    : 'タスク完了で入場可能',
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