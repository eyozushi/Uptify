// widgets/playback/calendar_widget.dart
import 'package:flutter/material.dart';
import '../../models/calendar_day_data.dart';

/// 月間カレンダーウィジェット
class CalendarWidget extends StatelessWidget {
  /// 表示する年
  final int year;
  
  /// 表示する月
  final int month;
  
  /// カレンダーの日別データ
  final List<CalendarDayData> dayData;
  
  /// 日付タップ時のコールバック
  final Function(DateTime)? onDayTapped;
  
  const CalendarWidget({
    super.key,
    required this.year,
    required this.month,
    required this.dayData,
    this.onDayTapped,
  });

  @override
Widget build(BuildContext context) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // 月表示
      _buildMonthLabel(),
      
      const SizedBox(height: 8),
      
      // 曜日ヘッダー
      _buildWeekdayHeader(),
      
      const SizedBox(height: 4),
      
      // カレンダーグリッド
      _buildCalendarGrid(),
    ],
  );
}

  /// 【修正】月ラベルを構築（月名で表示）
Widget _buildMonthLabel() {
  // 月名のリスト
  const monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  
  return Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(
      monthNames[month - 1], // monthは1-12なので-1してインデックス化
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
            letterSpacing: -0.2,
        fontWeight: FontWeight.w600,
        fontFamily: 'Hiragino Sans',
      ),
    ),
  );
}

  /// 【修正】曜日ヘッダーを構築（間隔を詰める）
Widget _buildWeekdayHeader() {
  const weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: weekdays.map((day) {
        return Expanded(
          child: Center(
            child: Text(
              day,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 13,
                fontWeight: FontWeight.w400,
                fontFamily: 'Hiragino Sans',
              ),
            ),
          ),
        );
      }).toList(),
    ),
  );
}

  /// 【修正】カレンダーグリッドを構築
  /// 【修正】カレンダーグリッドを構築（余白を完全に削除）
Widget _buildCalendarGrid() {
  final firstDayOfMonth = DateTime(year, month, 1);
  final lastDayOfMonth = DateTime(year, month + 1, 0);
  final daysInMonth = lastDayOfMonth.day;
  
  // 月の最初の日の曜日（0=日曜, 6=土曜）
  final firstWeekday = firstDayOfMonth.weekday % 7;
  
  // グリッドの総セル数
  final totalCells = ((daysInMonth + firstWeekday) / 7).ceil() * 7;
  
  // GridViewの代わりにColumnとRowで構築
  final rows = <Widget>[];
  
  for (int week = 0; week < (totalCells / 7).ceil(); week++) {
    final weekCells = <Widget>[];
    
    for (int day = 0; day < 7; day++) {
      final index = week * 7 + day;
      
      if (index < firstWeekday || index - firstWeekday + 1 > daysInMonth) {
        weekCells.add(const SizedBox.shrink());
      } else {
        final dayNumber = index - firstWeekday + 1;
        final date = DateTime(year, month, dayNumber);
        final dayInfo = _getDayData(date);
        weekCells.add(_buildDayCell(date, dayInfo));
      }
    }
    
    rows.add(
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: weekCells.map((cell) => Expanded(child: cell)).toList(),
        ),
      ),
    );
  }
  
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: rows,
    ),
  );
}

  /// 【既存】指定日のデータを取得
  CalendarDayData _getDayData(DateTime date) {
    try {
      return dayData.firstWhere(
        (data) => 
            data.date.year == date.year &&
            data.date.month == date.month &&
            data.date.day == date.day,
        orElse: () => CalendarDayData.empty(date),
      );
    } catch (e) {
      return CalendarDayData.empty(date);
    }
  }

  /// 【修正】日付セルを構築（高さを最小化）
Widget _buildDayCell(DateTime date, CalendarDayData dayInfo) {
  final isToday = _isToday(date);
  final hasCompletion = dayInfo.completedTaskCount > 0;
  final isFullCompletion = dayInfo.isFullCompletion;
  
  return GestureDetector(
    onTap: () {
      if (onDayTapped != null && hasCompletion) {
        onDayTapped!(date);
      }
    },
    child: AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: isFullCompletion
              ? Border.all(
                  color: const Color(0xFF1DB954),
                  width: 2.5,
                )
              : null,
        ),
        child: Center(
          child: Text(
            '${date.day}',
            style: TextStyle(
              color: isToday
                  ? const Color(0xFF1DB954)
                  : Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'Hiragino Sans',
            ),
          ),
        ),
      ),
    ),
  );
}

  /// 【既存】今日かどうかを判定
  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
           date.month == now.month &&
           date.day == now.day;
  }
}