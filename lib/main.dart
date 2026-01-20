// main.dart - 通知初期化対応版
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'main_wrapper.dart';
import 'services/main_wrapper_provider.dart';
import 'services/habit_breaker_service.dart';  // ✅ 追加
import 'services/notification_service.dart';   // ✅ 追加

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ✅ 通知システムの初期化（最優先）
  await _initializeNotificationSystem();
  
  // Spotify風のシステムUI設定
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF000000),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  
  // 画面の向きを縦向きに固定
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  runApp(const LifeTrackApp());
}

/// ✅ 新規追加：通知システム初期化
Future<void> _initializeNotificationSystem() async {
  try {
    print('🔔 通知システム初期化開始...');
    
    // 1. NotificationServiceを初期化
    final notificationService = NotificationService();
    final initialized = await notificationService.initialize();
    
    if (!initialized) {
      print('⚠️ NotificationService初期化失敗 - 通知機能は利用できません');
      return;
    }
    
    // 2. 通知チャンネルを作成（Android用）
    await notificationService.createNotificationChannels();
    
    // 3. HabitBreakerServiceを初期化＆自動起動
    final habitBreakerService = HabitBreakerService();
    await habitBreakerService.initialize();
    
    print('✅ 通知システム初期化完了');
  } catch (e) {
    print('❌ 通知システム初期化エラー: $e');
    // エラーがあってもアプリは起動させる
  }
}

class LifeTrackApp extends StatelessWidget {
  const LifeTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Uptify - 人生は音楽',
      debugShowCheckedModeBanner: false,
      theme: _buildSpotifyTheme(),
      home: MainWrapperProvider(
        controller: mainWrapperController,
        child: const MainWrapper(),
      ),
    );
  }

  ThemeData _buildSpotifyTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF000000),
      primarySwatch: Colors.green,
      primaryColor: const Color(0xFF1DB954),
      
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF1DB954),
        secondary: Color(0xFF1ED760),
        surface: Color(0xFF1A1A1A),
        background: Color(0xFF000000),
        onPrimary: Color(0xFF000000),
        onSecondary: Color(0xFF000000),
        onSurface: Color(0xFFFFFFFF),
        onBackground: Color(0xFFFFFFFF),
      ),
      
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 28,
          fontWeight: FontWeight.bold,
          fontFamily: 'Hiragino Sans',
        ),
        displayMedium: TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 22,
          fontWeight: FontWeight.w600,
          fontFamily: 'Hiragino Sans',
        ),
        headlineMedium: TextStyle(
          color: Color(0xFFB3B3B3),
          fontSize: 16,
          fontWeight: FontWeight.w400,
          fontFamily: 'Hiragino Sans',
        ),
        bodyLarge: TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 16,
          fontWeight: FontWeight.w400,
          fontFamily: 'Hiragino Sans',
        ),
        bodyMedium: TextStyle(
          color: Color(0xFFB3B3B3),
          fontSize: 14,
          fontWeight: FontWeight.w400,
          fontFamily: 'Hiragino Sans',
        ),
      ),
    );
  }
}