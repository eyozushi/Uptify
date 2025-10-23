// models/fan_entrance_data.dart
class FanEntranceData {
  final int currentAudience;      // 現在の観客数
  final int stockedFans;          // ストックされたファン数
  final int totalCompletedTasks;  // 完了タスク数
  
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

// services/fan_entrance_service.dart
import 'dart:async';
import '../models/fan_entrance_data.dart';
import 'charts_service.dart';

class FanEntranceService {
  final ChartsService _chartsService = ChartsService();
  
  // ストリーム用のコントローラー
  final _fanDataController = StreamController<FanEntranceData>.broadcast();
  Stream<FanEntranceData> get fanDataStream => _fanDataController.stream;
  
  // 現在の状態
  FanEntranceData _currentData = const FanEntranceData(
    currentAudience: 0,
    stockedFans: 0,
    totalCompletedTasks: 0,
  );
  
  FanEntranceData get currentData => _currentData;
  
  // 初期データの読み込み
  Future<void> initialize() async {
    try {
      final concertData = await _chartsService.getConcertData();
      
      // 初期状態では全てのファンが既に入場済みと仮定
      _currentData = FanEntranceData(
        currentAudience: concertData.audienceCount,
        stockedFans: 0,
        totalCompletedTasks: concertData.totalCompletedTasks,
      );
      
      _fanDataController.add(_currentData);
    } catch (e) {
      print('ファンデータ初期化エラー: $e');
    }
  }
  
  // 新しいタスク完了でファンをストック
  Future<void> addNewFans(int newTaskCount) async {
    final newFans = newTaskCount; // 1タスク = 1ファン
    
    _currentData = _currentData.copyWith(
      stockedFans: _currentData.stockedFans + newFans,
      totalCompletedTasks: _currentData.totalCompletedTasks + newTaskCount,
    );
    
    _fanDataController.add(_currentData);
    print('新しいファン ${newFans}人 がストックされました');
  }
  
  // ファン入場処理
  Future<void> enterFans() async {
    if (_currentData.stockedFans <= 0) {
      print('入場待ちのファンがいません');
      return;
    }
    
    final enteringFans = _currentData.stockedFans;
    
    // ストックをクリアして観客に追加
    _currentData = _currentData.copyWith(
      currentAudience: _currentData.currentAudience + enteringFans,
      stockedFans: 0,
    );
    
    _fanDataController.add(_currentData);
    print('${enteringFans}人のファンが入場しました！');
  }
  
  // データの手動更新（デバッグ用）
  Future<void> refreshData() async {
    await initialize();
  }
  
  void dispose() {
    _fanDataController.close();
  }
}