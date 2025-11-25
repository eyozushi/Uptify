// screens/playback_screen.dart
import 'package:flutter/material.dart';
import '../models/calendar_day_data.dart';
import '../models/playback_report.dart';
import '../services/playback_service.dart';
import '../widgets/playback/calendar_widget.dart';
import '../widgets/playback/daily_report_widget.dart';
import '../widgets/playback/weekly_report_widget.dart';
import '../widgets/playback/monthly_report_widget.dart';
import '../widgets/playback/annual_report_widget.dart';


class PlaybackScreen extends StatefulWidget {
  
  const PlaybackScreen({
    super.key,
  });

  @override
  State<PlaybackScreen> createState() => _PlaybackScreenState();
}

class _PlaybackScreenState extends State<PlaybackScreen> with AutomaticKeepAliveClientMixin {
  final PlaybackService _playbackService = PlaybackService();

  bool _hasLoadedAnnual = false;

  
  
  // 現在表示中の年月
  late int _currentYear;
  late int _currentMonth;
  
  // カレンダーデータ
  List<CalendarDayData> _calendarData = [];
  bool _isCalendarLoading = true;
  
  // レポートページ管理
  late PageController _reportPageController;
  int _currentReportIndex = 0;  // 0:デイリー, 1:ウィークリー, 2:マンスリー, 3:アニュアル
  
  // 各レポートデータ
  PlaybackReport? _dailyReport;
  PlaybackReport? _weeklyReport;
  PlaybackReport? _monthlyReport;
  PlaybackReport? _annualReport;
  bool _isReportLoading = true;

  @override
void initState() {
  super.initState();
  
  // 現在の年月を初期値に設定
  final now = DateTime.now();
  _currentYear = now.year;
  _currentMonth = now.month;
  
  // PageController初期化
  _reportPageController = PageController(initialPage: 0);
  
  // 🔧 変更：初回のみキャッシュクリアとデータ読み込み
  _playbackService.clearCache();
  _loadCalendarData();
  _loadAllReports(); // デイリー、ウィークリー、マンスリーのみ
}

void refreshData() {
  if (!mounted) return;
  
  final startTime = DateTime.now();
  print('🔄 PlaybackScreen: データ更新開始');
  
  _playbackService.clearCache();
  _loadCalendarData();
  _loadAllReports(); // 🔧 変更：アニュアル以外を更新
  
  final duration = DateTime.now().difference(startTime);
  print('✅ PlaybackScreen: データ更新完了 (${duration.inMilliseconds}ms)');
}

  @override
  void dispose() {
    _reportPageController.dispose();
    super.dispose();
  }

  Future<void> _loadCalendarData() async {
  final startTime = DateTime.now(); // 🆕 追加
  print('📅 カレンダーデータ読み込み開始...');
  
  setState(() {
    _isCalendarLoading = true;
  });
  
  try {
    final data = await _playbackService.getMonthCalendarData(
      _currentYear,
      _currentMonth,
    );
    
    if (mounted) {
      setState(() {
        _calendarData = data;
        _isCalendarLoading = false;
      });
    }
    
    final duration = DateTime.now().difference(startTime); // 🆕 追加
    print('✅ カレンダーデータ読み込み完了: ${duration.inMilliseconds}ms'); // 🆕 追加
  } catch (e) {
    print('カレンダーデータ読み込みエラー: $e');
    if (mounted) {
      setState(() {
        _isCalendarLoading = false;
      });
    }
  }
}



/// 【新規追加】AutomaticKeepAliveClientMixin用
@override
bool get wantKeepAlive => true;


  Future<void> _loadAllReports() async {
  final startTime = DateTime.now();
  print('📊 レポートデータ読み込み開始...');
  
  setState(() {
    _isReportLoading = true;
  });
  
  try {
    final now = DateTime.now();
    
    // デイリーレポート
    final dailyStart = DateTime.now();
    final daily = await _playbackService.getDailyReport(now);
    print('  - デイリー: ${DateTime.now().difference(dailyStart).inMilliseconds}ms');
    
    // ウィークリーレポート（今週の日曜日を計算）
    final weeklyStart = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday % 7));
    final weekly = await _playbackService.getWeeklyReport(weekStart);
    print('  - ウィークリー: ${DateTime.now().difference(weeklyStart).inMilliseconds}ms');
    
    // マンスリーレポート
    final monthlyStart = DateTime.now();
    final monthly = await _playbackService.getMonthlyReport(_currentYear, _currentMonth);
    print('  - マンスリー: ${DateTime.now().difference(monthlyStart).inMilliseconds}ms');
    
    // 🗑️ 削除：アニュアルレポートの読み込みを削除
    // final annualStart = DateTime.now();
    // final annual = await _playbackService.getAnnualReport(_currentYear);
    // print('  - アニュアル: ${DateTime.now().difference(annualStart).inMilliseconds}ms');
    
    if (mounted) {
      setState(() {
        _dailyReport = daily;
        _weeklyReport = weekly;
        _monthlyReport = monthly;
        // _annualReport = annual; // 🗑️ 削除
        _isReportLoading = false;
      });
    }
    
    final duration = DateTime.now().difference(startTime);
    print('✅ レポートデータ読み込み完了: ${duration.inMilliseconds}ms');
  } catch (e) {
    print('レポート読み込みエラー: $e');
    if (mounted) {
      setState(() {
        _isReportLoading = false;
      });
    }
  }
}

/// 【新規追加】アニュアルレポートを必要な時だけ読み込み
Future<void> _loadAnnualReportIfNeeded() async {
  if (_hasLoadedAnnual) return; // 既に読み込み済み
  
  final startTime = DateTime.now();
  print('📊 アニュアルレポート読み込み開始...');
  
  try {
    final annual = await _playbackService.getAnnualReport(_currentYear);
    
    if (mounted) {
      setState(() {
        _annualReport = annual;
        _hasLoadedAnnual = true;
      });
    }
    
    final duration = DateTime.now().difference(startTime);
    print('✅ アニュアルレポート読み込み完了: ${duration.inMilliseconds}ms');
  } catch (e) {
    print('❌ アニュアルレポート読み込みエラー: $e');
  }
}

  

  /// 【新規追加】特定日のデイリーレポートを読み込み
  Future<void> _loadDailyReportForDate(DateTime date) async {
    try {
      final report = await _playbackService.getDailyReport(date);
      
      if (mounted) {
        setState(() {
          _dailyReport = report;
        });
      }
    } catch (e) {
      print('特定日のデイリーレポート読み込みエラー: $e');
    }
  }

  /// 【新規追加】日付タップ時の処理
void _onDayTapped(DateTime date) {
  print('日付タップ: ${date.year}/${date.month}/${date.day}');
  
  // デイリーレポートに切り替え
  if (_currentReportIndex != 0) {
    _reportPageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }
  
  // その日のデイリーレポートを読み込み
  _loadDailyReportForDate(date);
}

  void _onReportPageChanged(int index) {
  setState(() {
    _currentReportIndex = index;
  });
  
  // 🆕 追加：アニュアルページ（index=3）に移動した時だけ読み込み
  if (index == 3) {
    _loadAnnualReportIfNeeded();
  }
}

  @override
Widget build(BuildContext context) {
  super.build(context); // AutomaticKeepAliveのため必要

  // 画面の高さを取得
  final screenHeight = MediaQuery.of(context).size.height;
  final topPadding = MediaQuery.of(context).padding.top;
  final bottomPadding = MediaQuery.of(context).padding.bottom;
  
  // 利用可能な高さを計算（ヘッダー + ボトムナビゲーション分を引く）
  final availableHeight = screenHeight - topPadding - bottomPadding - 80 - 60;
  
  return Scaffold(
    backgroundColor: Colors.transparent,
    body: SingleChildScrollView(
      child: Column(
        children: [
          // ヘッダー（固定）
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: _buildHeader(),
          ),
          
          // カレンダー
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
              ),
              child: _isCalendarLoading
                  ? const SizedBox(
                      height: 280,
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF1DB954),
                          ),
                        ),
                      ),
                    )
                  : CalendarWidget(
                      year: _currentYear,
                      month: _currentMonth,
                      dayData: _calendarData,
                      onDayTapped: _onDayTapped,
                    ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // レポート表示エリア（高さを画面に合わせて調整）
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: SizedBox(
              height: availableHeight,
              child: _buildReportArea(),
            ),
          ),
        ],
      ),
    ),
  );
}

  /// 【既存】ヘッダーを構築
  Widget _buildHeader() {
    return Container(
      height: 60,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'プレイバック',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              fontFamily: 'Hiragino Sans',
            ),
          ),
          Text(
            '${_currentYear}/${_currentMonth.toString().padLeft(2, '0')}/${DateTime.now().day.toString().padLeft(2, '0')}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              fontFamily: 'SF Pro Text',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportArea() {
  return Column(
    children: [
      _buildReportIndicator(),
      const SizedBox(height: 12),
      Expanded(
        child: _isReportLoading
            ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color(0xFF1DB954),
                  ),
                ),
              )
            : PageView(
                controller: _reportPageController,
                onPageChanged: _onReportPageChanged,
                children: [
                  _dailyReport != null
                      ? DailyReportWidget(report: _dailyReport!)
                      : _buildEmptyReport('デイリーレポート'),
                  _weeklyReport != null
                      ? WeeklyReportWidget(report: _weeklyReport!)
                      : _buildEmptyReport('ウィークリーレポート'),
                  _monthlyReport != null
                      ? MonthlyReportWidget(report: _monthlyReport!)
                      : _buildEmptyReport('マンスリーレポート'),
                  // 🔧 変更：アニュアルレポートは未読み込み時もローディング表示
                  _annualReport != null
                      ? AnnualReportWidget(report: _annualReport!)
                      : _hasLoadedAnnual
                          ? _buildEmptyReport('アニュアルレポート')
                          : Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF1DB954),
                                ),
                              ),
                            ),
                ],
              ),
      ),
    ],
  );
}

  /// 【修正】レポート切り替えインジケーターを構築
Widget _buildReportIndicator() {
  final labels = ['日', '週', '月', '年'];
  
  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: List.generate(4, (index) {
      final isSelected = _currentReportIndex == index;
      
      return GestureDetector(
        onTap: () {
          _reportPageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected 
                ? const Color(0xFF1DB954)
                : const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            labels[index],
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              fontFamily: 'Hiragino Sans',
            ),
          ),
        ),
      );
    }),
  );
}

  /// 【新規追加】空のレポートプレースホルダー
  Widget _buildEmptyReport(String reportName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),  // より暗いグレーに変更
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.analytics_outlined,
              color: Colors.white.withOpacity(0.3),
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              '$reportNameのデータがありません',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
                fontFamily: 'Hiragino Sans',
              ),
            ),
          ],
        ),
      ),
    );
  }
}