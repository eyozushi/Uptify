import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';

class UpdateNotificationService {
  // 🔧 修正：既存リポジトリのURLに変更
  static const String _updateJsonUrl = 
      'https://raw.githubusercontent.com/eyozushi/Uptify/main/updates.json';
  
  static const String _keyDismissedNotifications = 'dismissed_update_notifications';
  static const String _keyLastCheckTime = 'last_update_check_time';
  
  /// アップデート通知をチェック
Future<UpdateNotification?> checkForUpdate() async {
  try {
    print('🔍 アップデートチェック開始: $_updateJsonUrl'); // 🆕 追加
    
    // 最後のチェックから1時間以内ならスキップ
    if (await _shouldSkipCheck()) {
      print('⏭️ アップデートチェックをスキップ（1時間以内に確認済み）');
      return null;
    }
    
    print('📡 JSONをダウンロード中...'); // 🆕 追加
    
    // JSONをダウンロード
    final response = await http.get(Uri.parse(_updateJsonUrl)).timeout(
      const Duration(seconds: 5),
    );
    
    print('📡 ステータスコード: ${response.statusCode}'); // 🆕 追加
    print('📡 レスポンス: ${response.body}'); // 🆕 追加
    
    if (response.statusCode != 200) {
      print('⚠️ アップデート情報の取得に失敗: ${response.statusCode}');
      return null;
    }
    
    final data = jsonDecode(response.body);
    
    print('🔍 show_banner: ${data['show_banner']}'); // 🆕 追加
      
      // 現在のアプリバージョンを取得
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      
      // バナー表示判定
      if (data['show_banner'] != true) {
        print('✅ バナー非表示設定');
        return null;
      }
      
      // 既に非表示にした通知かチェック
      final notificationId = 'update_${data['current_version']}';
      if (await _isNotificationDismissed(notificationId)) {
        print('✅ この通知は既に非表示済み');
        return null;
      }
      
      // チェック時刻を保存
      await _saveLastCheckTime();
      
      print('🔔 アップデート通知あり: ${data['current_version']}');
      
      return UpdateNotification(
        id: notificationId,
        title: data['banner_title'] ?? 'New Update Available',
        message: data['banner_message'] ?? '',
        buttonText: data['banner_button_text'] ?? 'Update Now',
        updateUrl: data['update_url_ios'] ?? '',
        dismissable: data['dismissable'] ?? true,
        priority: data['priority'] ?? 'normal',
      );
      
    } catch (e) {
      print('❌ アップデートチェックエラー: $e');
      return null; // エラーでもアプリは正常動作
    }
  }
  
  /// 通知を非表示にする
  Future<void> dismissNotification(String notificationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissed = prefs.getStringList(_keyDismissedNotifications) ?? [];
      
      if (!dismissed.contains(notificationId)) {
        dismissed.add(notificationId);
        await prefs.setStringList(_keyDismissedNotifications, dismissed);
        print('✅ 通知を非表示: $notificationId');
      }
    } catch (e) {
      print('❌ 通知非表示エラー: $e');
    }
  }
  
  /// 通知が既に非表示にされているかチェック
  Future<bool> _isNotificationDismissed(String notificationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissed = prefs.getStringList(_keyDismissedNotifications) ?? [];
      return dismissed.contains(notificationId);
    } catch (e) {
      return false;
    }
  }
  
  /// 最後のチェックから1時間以内かチェック
  Future<bool> _shouldSkipCheck() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheck = prefs.getInt(_keyLastCheckTime);
      
      if (lastCheck == null) return false;
      
      final now = DateTime.now().millisecondsSinceEpoch;
      final diff = now - lastCheck;
      
      // 1時間 = 3600000ミリ秒
      return diff < 3600000;
    } catch (e) {
      return false;
    }
  }
  
  /// 最後のチェック時刻を保存
  Future<void> _saveLastCheckTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyLastCheckTime, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      print('❌ チェック時刻保存エラー: $e');
    }
  }
}

/// アップデート通知モデル
class UpdateNotification {
  final String id;
  final String title;
  final String message;
  final String buttonText;
  final String updateUrl;
  final bool dismissable;
  final String priority; // "critical", "normal", "info"
  
  UpdateNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.buttonText,
    required this.updateUrl,
    required this.dismissable,
    required this.priority,
  });
}