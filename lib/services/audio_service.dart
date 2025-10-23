// services/audio_service.dart - 安全な音声再生版
import 'package:audioplayers/audioplayers.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  AudioPlayer? _player;
  // または
  AudioPlayer? _taskCompletedPlayer;
  AudioPlayer? _achievementPlayer;
  AudioPlayer? _notificationPlayer;

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isEnabled = true;
  bool _hasAudioFiles = false; // 🔧 追加: 音声ファイル存在フラグ

  // 初期化時に音声ファイルの存在確認
  Future<void> initialize() async {
    await _checkAudioFiles();
  }

  // 🔧 追加: 音声ファイルの存在確認
  Future<void> _checkAudioFiles() async {
    try {
      // テスト再生で音声ファイルの存在を確認
      await _audioPlayer.setVolume(0.0); // 無音でテスト
      await _audioPlayer.play(AssetSource('sounds/task_completed.mp3'));
      await Future.delayed(const Duration(milliseconds: 100));
      await _audioPlayer.stop();
      
      _hasAudioFiles = true;
      await _audioPlayer.setVolume(1.0); // 音量を戻す
      print('✅ 音声ファイルの存在を確認しました');
    } catch (e) {
      _hasAudioFiles = false;
      print('⚠️ 音声ファイルが見つかりません（無音モードで動作）: $e');
    }
  }

  // 音声の有効/無効を設定
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    print('🔊 音声設定変更: ${enabled ? "有効" : "無効"}');
  }

  bool get isEnabled => _isEnabled;
  bool get hasAudioFiles => _hasAudioFiles;

  // 🔧 修正: 安全なタスク完了音再生
  Future<void> playTaskCompletedSound() async {
    if (!_isEnabled) {
      print('🔊 音声無効のためスキップ');
      return;
    }
    
    if (!_hasAudioFiles) {
      print('🔊 音声ファイル未検出のためスキップ');
      return;
    }
    
    try {
      await _audioPlayer.play(AssetSource('sounds/task_completed.mp3'));
      print('🔊 タスク完了音を再生しました');
    } catch (e) {
      print('❌ タスク完了音再生エラー（処理継続）: $e');
      _hasAudioFiles = false; // フラグを更新
    }
  }

  // 🔧 修正: 安全な達成音再生
  Future<void> playAchievementSound() async {
    if (!_isEnabled) {
      print('🔊 音声無効のためスキップ');
      return;
    }
    
    if (!_hasAudioFiles) {
      print('🔊 音声ファイル未検出のためスキップ');
      return;
    }
    
    try {
      await _audioPlayer.play(AssetSource('sounds/achievement.mp3'));
      print('🔊 達成音を再生しました');
    } catch (e) {
      print('❌ 達成音再生エラー（処理継続）: $e');
      _hasAudioFiles = false; // フラグを更新
    }
  }

  // 🔧 修正: 安全な通知音再生
  Future<void> playNotificationSound() async {
    if (!_isEnabled) {
      print('🔊 音声無効のためスキップ');
      return;
    }
    
    if (!_hasAudioFiles) {
      print('🔊 音声ファイル未検出のためスキップ');
      return;
    }
    
    try {
      await _audioPlayer.play(AssetSource('sounds/notification.mp3'));
      print('🔊 通知音を再生しました');
    } catch (e) {
      print('❌ 通知音再生エラー（処理継続）: $e');
      _hasAudioFiles = false; // フラグを更新
    }
  }

  // 🔧 修正: 安全な成功ファンファーレ再生
  Future<void> playSuccessFanfare() async {
    if (!_isEnabled || !_hasAudioFiles) {
      print('🔊 ファンファーレをスキップ（音声無効または未検出）');
      return;
    }
    
    try {
      // まず達成音を再生
      await playAchievementSound();
      
      // 少し間を開けてタスク完了音も再生
      await Future.delayed(const Duration(milliseconds: 300));
      await playTaskCompletedSound();
      
      print('🎉 成功ファンファーレを再生しました');
    } catch (e) {
      print('❌ 成功ファンファーレ再生エラー（処理継続）: $e');
    }
  }

  // カスタム音声を再生（将来の拡張用）
  Future<void> playCustomSound(String assetPath) async {
    if (!_isEnabled) return;
    
    try {
      await _audioPlayer.play(AssetSource(assetPath));
      print('🔊 カスタム音声を再生しました: $assetPath');
    } catch (e) {
      print('❌ カスタム音声再生エラー: $e');
    }
  }

  // 音量を設定（0.0 - 1.0）
  Future<void> setVolume(double volume) async {
    try {
      await _audioPlayer.setVolume(volume.clamp(0.0, 1.0));
      print('🔊 音量を設定しました: ${(volume * 100).toInt()}%');
    } catch (e) {
      print('❌ 音量設定エラー: $e');
    }
  }

  // 音声を停止
  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      print('❌ 音声停止エラー: $e');
    }
  }

  @override
void dispose() {
  try {
    // 🔧 修正：既に破棄されている可能性があるのでtry-catchで保護
    if (_taskCompletedPlayer != null) {
      _taskCompletedPlayer?.stop();
      _taskCompletedPlayer?.dispose();
      _taskCompletedPlayer = null;
    }
    
    if (_achievementPlayer != null) {
      _achievementPlayer?.stop();
      _achievementPlayer?.dispose();
      _achievementPlayer = null;
    }
    
    if (_notificationPlayer != null) {
      _notificationPlayer?.stop();
      _notificationPlayer?.dispose();
      _notificationPlayer = null;
    }
  } catch (e) {
    print('⚠️ AudioService dispose時のエラー（無視）: $e');
  }
}

  // 🔧 修正: 詳細な音声ファイルテスト
  Future<bool> testAudioFiles() async {
    try {
      print('🧪 音声ファイルのテストを開始します...');
      
      // 音量を下げてテスト
      await setVolume(0.3);
      
      // 各音声ファイルをテスト
      print('🧪 通知音テスト...');
      await playNotificationSound();
      await Future.delayed(const Duration(milliseconds: 500));
      
      print('🧪 タスク完了音テスト...');
      await playTaskCompletedSound();
      await Future.delayed(const Duration(milliseconds: 500));
      
      print('🧪 達成音テスト...');
      await playAchievementSound();
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 音量を戻す
      await setVolume(1.0);
      
      print('✅ 全ての音声ファイルのテストが完了しました');
      return _hasAudioFiles;
    } catch (e) {
      print('❌ 音声ファイルテストエラー: $e');
      return false;
    }
  }

  // 🔧 追加: 音声ファイル情報の取得
  Map<String, dynamic> getAudioStatus() {
    return {
      'isEnabled': _isEnabled,
      'hasAudioFiles': _hasAudioFiles,
      'canPlaySounds': _isEnabled && _hasAudioFiles,
    };
  }
}