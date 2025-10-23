// services/data_service.dart - 理想像画像保存機能追加版
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../models/task_item.dart';
import '../models/single_album.dart'; // 🎵 追加
import '../models/notification_config.dart';
import '../models/task_completion.dart';
import '../models/achievement_record.dart';
import '../services/achievement_service.dart';

class DataService {
  static const String _keyUserData = 'user_data';
  static const String _keyFirstLaunch = 'first_launch';
  static const String _keyOnboardingCompleted = 'onboarding_completed';
  static const String _keyImageBytes = 'saved_image_bytes'; // 理想像画像（メイン表示用）
  static const String _keyIdealImageBytes = 'ideal_image_bytes'; // 顔写真（プロフィール画像）
  static const String _keySingleAlbums = 'single_albums'; // 🎵 追加
  static const String _keyNotificationConfig = 'notification_config';

  // 🔔 新機能: AchievementServiceのインスタンス
  final AchievementService _achievementService = AchievementService();
  
  // 保存された画像データを一時的に保持
  Uint8List? _savedImageBytes; // 理想像画像（メイン表示用）
  Uint8List? _savedIdealImageBytes; // 顔写真（プロフィール画像）

  // ==================== 画像保存関連メソッド ====================
  
  // 理想像画像（メイン表示用）を保存
  Future<void> saveImageBytes(Uint8List imageBytes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Uint8ListをBase64文字列に変換して保存
      final base64String = base64Encode(imageBytes);
      await prefs.setString(_keyImageBytes, base64String);
      
      // メモリにも保存
      _savedImageBytes = imageBytes;
      
      print('✓ 理想像画像データを保存しました: ${imageBytes.length} bytes');
    } catch (e) {
      print('❌ 理想像画像データ保存エラー: $e');
      rethrow;
    }
  }

  // 顔写真（プロフィール画像）を保存
  Future<void> saveIdealImageBytes(Uint8List imageBytes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Uint8ListをBase64文字列に変換して保存
      final base64String = base64Encode(imageBytes);
      await prefs.setString(_keyIdealImageBytes, base64String);
      
      // メモリにも保存
      _savedIdealImageBytes = imageBytes;
      
      print('✓ 顔写真データを保存しました: ${imageBytes.length} bytes');
    } catch (e) {
      print('❌ 顔写真データ保存エラー: $e');
      rethrow;
    }
  }

  // 保存された理想像画像データを取得（メイン表示用）
  Future<Uint8List?> loadImageBytes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final base64String = prefs.getString(_keyImageBytes);
      
      if (base64String != null) {
        // Base64文字列をUint8Listに変換
        final imageBytes = base64Decode(base64String);
        _savedImageBytes = imageBytes;
        return imageBytes;
      }
      
      return null;
    } catch (e) {
      print('❌ 理想像画像データ読み込みエラー: $e');
      return null;
    }
  }

  // 保存された顔写真データを取得（プロフィール画像）
  Future<Uint8List?> loadIdealImageBytes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final base64String = prefs.getString(_keyIdealImageBytes);
      
      if (base64String != null) {
        // Base64文字列をUint8Listに変換
        final imageBytes = base64Decode(base64String);
        _savedIdealImageBytes = imageBytes;
        return imageBytes;
      }
      
      return null;
    } catch (e) {
      print('❌ 顔写真データ読み込みエラー: $e');
      return null;
    }
  }

  // 保存された理想像画像データを取得（メモリから）
  Uint8List? getSavedImageBytes() {
    return _savedImageBytes;
  }

  // 保存された顔写真データを取得（メモリから）
  Uint8List? getSavedIdealImageBytes() {
    return _savedIdealImageBytes;
  }

  // 理想像画像データを削除
  Future<void> removeImageBytes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyImageBytes);
      _savedImageBytes = null;
      print('✓ 理想像画像データを削除しました');
    } catch (e) {
      print('❌ 理想像画像データ削除エラー: $e');
    }
  }

  // 顔写真データを削除
  Future<void> removeIdealImageBytes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyIdealImageBytes);
      _savedIdealImageBytes = null;
      print('✓ 顔写真データを削除しました');
    } catch (e) {
      print('❌ 顔写真データ削除エラー: $e');
    }
  }

  // ==================== 既存のメソッド（変更なし） ====================

  // 🎵 シングルアルバム関連のメソッド
  
  // シングルアルバムを保存
  Future<void> saveSingleAlbum(SingleAlbum album) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 既存のアルバムリストを取得
      final albums = await loadSingleAlbums();
      
      // 新しいアルバムを追加（既存の同じIDがあれば更新）
      final existingIndex = albums.indexWhere((a) => a.id == album.id);
      if (existingIndex >= 0) {
        albums[existingIndex] = album;
      } else {
        albums.add(album);
      }
      
      // JSON形式で保存
      final albumsJson = albums.map((album) => album.toJson()).toList();
      final jsonString = jsonEncode(albumsJson);
      await prefs.setString(_keySingleAlbums, jsonString);
      
      print('✓ シングルアルバムを保存しました: ${album.albumName}');
    } catch (e) {
      print('❌ シングルアルバム保存エラー: $e');
      rethrow;
    }
  }
  
  // 全てのシングルアルバムを読み込み
  Future<List<SingleAlbum>> loadSingleAlbums() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_keySingleAlbums);
      
      if (jsonString != null) {
        final List<dynamic> albumsJson = jsonDecode(jsonString);
        return albumsJson
            .map((albumJson) => SingleAlbum.fromJson(albumJson))
            .toList();
      }
      
      return [];
    } catch (e) {
      print('❌ シングルアルバム読み込みエラー: $e');
      return [];
    }
  }
  
  // 特定のシングルアルバムを取得
  Future<SingleAlbum?> getSingleAlbum(String id) async {
    try {
      final albums = await loadSingleAlbums();
      return albums.firstWhere(
        (album) => album.id == id,
        orElse: () => throw StateError('Album not found'),
      );
    } catch (e) {
      print('❌ シングルアルバム取得エラー: $e');
      return null;
    }
  }
  
  // シングルアルバムを削除
  Future<void> deleteSingleAlbum(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final albums = await loadSingleAlbums();
      
      // 指定されたIDのアルバムを削除
      albums.removeWhere((album) => album.id == id);
      
      // 更新されたリストを保存
      final albumsJson = albums.map((album) => album.toJson()).toList();
      final jsonString = jsonEncode(albumsJson);
      await prefs.setString(_keySingleAlbums, jsonString);
      
      print('✓ シングルアルバムを削除しました: $id');
    } catch (e) {
      print('❌ シングルアルバム削除エラー: $e');
      rethrow;
    }
  }
  
  // シングルアルバムのユニークIDを生成
  String generateAlbumId() {
    return 'album_${DateTime.now().millisecondsSinceEpoch}';
  }

  // 既存のメソッドはそのまま維持

  // 初回起動かどうかをチェック
  Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final hasLaunched = prefs.getBool(_keyFirstLaunch) ?? false;
    
    if (!hasLaunched) {
      // 初回起動後、フラグを設定
      await prefs.setBool(_keyFirstLaunch, true);
      return true;
    }
    
    return false;
  }

  // オンボーディング完了状態をチェック
  Future<bool> isOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyOnboardingCompleted) ?? false;
  }

  // オンボーディング完了をマーク
  Future<void> markOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboardingCompleted, true);
  }

  // ユーザーデータを保存
  Future<void> saveUserData(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(data);
      await prefs.setString(_keyUserData, jsonString);
      
      // オンボーディング完了フラグも保存
      if (data['onboardingCompleted'] == true) {
        await prefs.setBool(_keyOnboardingCompleted, true);
      }
      
      print('✓ ユーザーデータを保存しました');
    } catch (e) {
      print('❌ ユーザーデータ保存エラー: $e');
      rethrow;
    }
  }

  // ユーザーデータを読み込み
  Future<Map<String, dynamic>> loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_keyUserData);
      
      if (jsonString != null) {
        final data = jsonDecode(jsonString) as Map<String, dynamic>;
        
        // 保存された画像データも読み込み
        await loadImageBytes();
        await loadIdealImageBytes();
        
        return data;
      }
      
      // デフォルトデータを返す
      return _getDefaultUserData();
    } catch (e) {
      print('❌ ユーザーデータ読み込みエラー: $e');
      return _getDefaultUserData();
    }
  }

  // デフォルトユーザーデータ
  Map<String, dynamic> _getDefaultUserData() {
    return {
      'idealSelf': '理想の自分',
      'artistName': 'You',
      'todayLyrics': '今日という日を大切に生きよう\n一歩ずつ理想の自分に近づいていく\n昨日の自分を超えていこう\n今この瞬間を輝かせよう',
      'aboutArtist': 'あなたの人生という音楽の主人公。毎日新しい楽曲を作り続ける唯一無二のアーティスト。',
      'albumImagePath': '',
      'tasks': getDefaultTasks().map((task) => task.toJson()).toList(),
      'onboardingCompleted': false,
    };
  }

  // デフォルトタスクを生成
  List<TaskItem> getDefaultTasks() {
    return [
      TaskItem(
        title: '理想の自分を意識する',
        description: '今日一日、理想の自分でいることを意識して行動する',
        color: const Color(0xFF1DB954),
        duration: 3, // 3分
      ),
      TaskItem(
        title: '成長のための行動をする',
        description: '理想に近づくための具体的な行動を1つ実行する',
        color: const Color(0xFF8B5CF6),
        duration: 3, // 3分
      ),
      TaskItem(
        title: '振り返りと感謝',
        description: '今日の成長を振り返り、感謝の気持ちを持つ',
        color: const Color(0xFFEF4444),
        duration: 3, // 3分
      ),
      TaskItem(
        title: '明日への準備',
        description: '明日の理想の自分に向けて準備をする',
        color: const Color(0xFF06B6D4),
        duration: 3, // 3分
      ),
    ];
  }

  // データをリセット
  Future<void> resetAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      _savedImageBytes = null;
      _savedIdealImageBytes = null;
      print('✓ すべてのデータをリセットしました');
    } catch (e) {
      print('❌ データリセットエラー: $e');
    }
  }

  // データの存在確認
  Future<bool> hasUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_keyUserData);
    } catch (e) {
      print('❌ データ存在確認エラー: $e');
      return false;
    }
  }

  Future<void> saveNotificationConfig(NotificationConfig config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(config.toJson());
      await prefs.setString(_keyNotificationConfig, jsonString);
      print('✅ 通知設定を保存しました');
    } catch (e) {
      print('❌ 通知設定保存エラー: $e');
      rethrow;
    }
  }
  // 🔔 通知設定を読み込み
  Future<NotificationConfig> loadNotificationConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_keyNotificationConfig);
      
      if (jsonString != null) {
        final data = jsonDecode(jsonString) as Map<String, dynamic>;
        return NotificationConfig.fromJson(data);
      }
      
      // デフォルト設定を返す
      return const NotificationConfig();
    } catch (e) {
      print('❌ 通知設定読み込みエラー: $e');
      return const NotificationConfig();
    }
  }

  // 🔔 通知設定を削除
  Future<void> removeNotificationConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyNotificationConfig);
      print('✅ 通知設定を削除しました');
    } catch (e) {
      print('❌ 通知設定削除エラー: $e');
    }
  }


  // 🔔 新機能: タスク完了記録を保存
  Future<void> saveTaskCompletion(TaskCompletion completion) async {
    try {
      await _achievementService.saveTaskCompletion(completion);
      print('✅ DataService: タスク完了記録を保存しました');
    } catch (e) {
      print('❌ DataService: タスク完了記録保存エラー: $e');
      rethrow;
    }
  }

  // 🔔 新機能: タスク完了記録を読み込み
  Future<List<TaskCompletion>> loadTaskCompletions() async {
    try {
      return await _achievementService.loadTaskCompletions();
    } catch (e) {
      print('❌ DataService: タスク完了記録読み込みエラー: $e');
      return [];
    }
  }

  // 🔔 新機能: 特定日のタスク完了記録を取得
  Future<List<TaskCompletion>> getTaskCompletionsByDate(DateTime date) async {
    try {
      return await _achievementService.getTaskCompletionsByDate(date);
    } catch (e) {
      print('❌ DataService: 日別タスク完了記録取得エラー: $e');
      return [];
    }
  }

  // 🔔 新機能: 達成記録を保存
  Future<void> saveAchievementRecord(AchievementRecord record) async {
    try {
      await _achievementService.saveAchievementRecord(record);
      print('✅ DataService: 達成記録を保存しました');
    } catch (e) {
      print('❌ DataService: 達成記録保存エラー: $e');
      rethrow;
    }
  }

  // 🔔 新機能: 達成記録を読み込み
  Future<List<AchievementRecord>> loadAchievementRecords() async {
    try {
      return await _achievementService.loadAchievementRecords();
    } catch (e) {
      print('❌ DataService: 達成記録読み込みエラー: $e');
      return [];
    }
  }

  // 🔔 新機能: 特定日の達成記録を取得
  Future<AchievementRecord?> getAchievementRecord(DateTime date) async {
    try {
      return await _achievementService.getAchievementRecord(date);
    } catch (e) {
      print('❌ DataService: 日別達成記録取得エラー: $e');
      return null;
    }
  }

  // 🔔 新機能: タスク統計を取得
  Future<Map<String, dynamic>> getTaskStatistics() async {
    try {
      return await _achievementService.getTaskStatistics();
    } catch (e) {
      print('❌ DataService: タスク統計取得エラー: $e');
      return {};
    }
  }

  // 🔔 新機能: 完了記録のユニークIDを生成
  String generateCompletionId() {
    return _achievementService.generateCompletionId();
  }

  // 🔔 新機能: タスクに完了記録を追加してユーザーデータを更新
  Future<void> addTaskCompletionToUserData(String taskId, DateTime completionTime) async {
    try {
      // 現在のユーザーデータを読み込み
      final userData = await loadUserData();
      
      // タスクリストを取得
      List<TaskItem> tasks = [];
      if (userData['tasks'] != null) {
        if (userData['tasks'] is List<TaskItem>) {
          tasks = List<TaskItem>.from(userData['tasks']);
        } else if (userData['tasks'] is List) {
          tasks = (userData['tasks'] as List)
              .map((taskJson) => TaskItem.fromJson(taskJson))
              .toList();
        }
      }
      
      // 指定されたタスクを見つけて完了記録を追加
      final updatedTasks = tasks.map((task) {
        if (task.id == taskId) {
          return task.addCompletion(completionTime);
        }
        return task;
      }).toList();
      
      // 更新されたタスクリストでユーザーデータを保存
      final updatedUserData = Map<String, dynamic>.from(userData);
      updatedUserData['tasks'] = updatedTasks.map((task) => task.toJson()).toList();
      
      await saveUserData(updatedUserData);
      
      print('✅ DataService: タスク完了記録をユーザーデータに追加しました');
    } catch (e) {
      print('❌ DataService: タスク完了記録追加エラー: $e');
      rethrow;
    }
  }

  // 🔔 新機能: 達成データをクリア（デバッグ用）
  Future<void> clearAchievementData() async {
    try {
      await _achievementService.clearAllData();
      print('✅ DataService: 達成データをクリアしました');
    } catch (e) {
      print('❌ DataService: 達成データクリアエラー: $e');
    }
  }

  // 🔔 新機能: 今日の達成サマリーを取得
  Future<Map<String, dynamic>> getTodayAchievementSummary() async {
    try {
      final today = DateTime.now();
      final todayCompletions = await getTaskCompletionsByDate(today);
      final todayRecord = await getAchievementRecord(today);
      
      final totalAttempts = todayCompletions.length;
      final totalSuccesses = todayCompletions.where((c) => c.wasSuccessful).length;
      final achievementRate = totalAttempts > 0 ? totalSuccesses / totalAttempts : 0.0;
      
      return {
        'date': today,
        'totalAttempts': totalAttempts,
        'totalSuccesses': totalSuccesses,
        'achievementRate': achievementRate,
        'completions': todayCompletions,
        'record': todayRecord,
      };
    } catch (e) {
      print('❌ DataService: 今日の達成サマリー取得エラー: $e');
      return {
        'date': DateTime.now(),
        'totalAttempts': 0,
        'totalSuccesses': 0,
        'achievementRate': 0.0,
        'completions': <TaskCompletion>[],
        'record': null,
      };
    }
  }


// 🆕 修正版: Lyric Noteを更新して自動保存
Future<void> updateTaskLyricNote(String taskId, String note) async {
  try {
    // ユーザーデータを読み込み
    final userData = await loadUserData();
    
    // タスクリストを取得
    List<TaskItem> tasks = [];
    if (userData['tasks'] != null) {
      if (userData['tasks'] is List<TaskItem>) {
        tasks = List<TaskItem>.from(userData['tasks']);
      } else if (userData['tasks'] is List) {
        tasks = (userData['tasks'] as List)
            .map((taskJson) => TaskItem.fromJson(taskJson))
            .toList();
      }
    }
    
    // 該当タスクのLyric Noteを更新
    final updatedTasks = tasks.map((task) {
      if (task.id == taskId) {
        return task.copyWith(lyricNote: note);
      }
      return task;
    }).toList();
    
    // ユーザーデータに保存
    userData['tasks'] = updatedTasks.map((task) => task.toJson()).toList();
    await saveUserData(userData);
    
    print('✅ Lyric Note保存完了: $taskId');
  } catch (e) {
    print('❌ Lyric Note更新エラー: $e');
    rethrow;
  }
}
/// シングルアルバムのタスクのLyric Noteを更新
Future<void> updateSingleAlbumTaskLyricNote({
  required String albumId,
  required String taskId,
  required String note,
}) async {
  try {
    // 全シングルアルバムを読み込み
    final albums = await loadSingleAlbums();
    
    // 該当アルバムを探す
    final albumIndex = albums.indexWhere((album) => album.id == albumId);
    if (albumIndex == -1) {
      print('⚠️ アルバムが見つかりません: $albumId');
      return;
    }
    
    final album = albums[albumIndex];
    
    // タスクリストを更新
    final updatedTasks = album.tasks.map((task) {
      if (task.id == taskId) {
        return task.copyWith(lyricNote: note);
      }
      return task;
    }).toList();
    
    // アルバムを更新
    final updatedAlbum = album.copyWith(tasks: updatedTasks);
    albums[albumIndex] = updatedAlbum;
    
    // 保存
    final prefs = await SharedPreferences.getInstance();
    final albumsJson = albums.map((album) => album.toJson()).toList();
    final jsonString = jsonEncode(albumsJson);
    await prefs.setString(_keySingleAlbums, jsonString);
    
    print('✅ シングルアルバムのLyric Note保存完了: $albumId / $taskId');
  } catch (e) {
    print('❌ シングルアルバムのLyric Note更新エラー: $e');
    rethrow;
  }
}

}