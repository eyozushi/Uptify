// services/reality_remaster_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../models/reality_remaster_photo.dart';

class RealityRemasterService {
  static const String _keyPrefix = 'reality_remaster_';
  
  // 🆕 写真を保存
  Future<void> savePhoto(RealityRemasterPhoto photo) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _keyPrefix + photo.taskId;
      final jsonString = jsonEncode(photo.toJson());
      await prefs.setString(key, jsonString);
      print('✅ Reality Remaster写真保存: ${photo.taskId}');
    } catch (e) {
      print('❌ Reality Remaster写真保存エラー: $e');
      rethrow;
    }
  }
  
  // 🆕 特定タスクの写真を取得
  Future<RealityRemasterPhoto?> getPhoto(String taskId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _keyPrefix + taskId;
      final jsonString = prefs.getString(key);
      
      if (jsonString == null) return null;
      
      final photo = RealityRemasterPhoto.fromJson(jsonDecode(jsonString));
      
      // 日付チェック: 今日以外の写真は削除
      if (!_isToday(photo.capturedAt)) {
        await deletePhoto(taskId);
        return null;
      }
      
      return photo;
    } catch (e) {
      print('❌ Reality Remaster写真取得エラー: $e');
      return null;
    }
  }
  
  // 🆕 写真を削除（理想に戻す）
  Future<void> deletePhoto(String taskId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _keyPrefix + taskId;
      await prefs.remove(key);
      print('✅ Reality Remaster写真削除: $taskId');
    } catch (e) {
      print('❌ Reality Remaster写真削除エラー: $e');
    }
  }
  
  // 🔧 修正: 全ての古い写真を削除（日付変更時）
  Future<void> cleanupOldPhotos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => key.startsWith(_keyPrefix));
      
      int deletedCount = 0;
      
      for (final key in keys) {
        final jsonString = prefs.getString(key);
        if (jsonString != null) {
          try {
            final photo = RealityRemasterPhoto.fromJson(jsonDecode(jsonString));
            if (!_isToday(photo.capturedAt)) {
              await prefs.remove(key);
              deletedCount++;
              print('🗑️ 古い写真を削除: $key (撮影日: ${photo.capturedAt})');
            }
          } catch (e) {
            // JSONパースエラーの場合も削除
            await prefs.remove(key);
            deletedCount++;
            print('🗑️ 破損データを削除: $key');
          }
        }
      }
      
      if (deletedCount > 0) {
        print('✅ Reality Remaster自動クリーンアップ完了: ${deletedCount}件削除');
      } else {
        print('✅ Reality Remaster自動クリーンアップ: 削除対象なし');
      }
    } catch (e) {
      print('❌ 古い写真クリーンアップエラー: $e');
    }
  }
  
  // 🆕 IDを生成
  String generatePhotoId() {
    return 'remaster_${DateTime.now().millisecondsSinceEpoch}';
  }
  
  // 🆕 今日かどうか判定
  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
           date.month == now.month &&
           date.day == now.day;
  }
}