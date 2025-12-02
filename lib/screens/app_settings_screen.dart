// screens/app_settings_screen.dart
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import '../services/data_service.dart';
import '../services/habit_breaker_service.dart';
import '../models/notification_config.dart';

class AppSettingsScreen extends StatefulWidget {
  final VoidCallback? onClose;

  const AppSettingsScreen({
    super.key,
    this.onClose,
  });

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  final DataService _dataService = DataService();
  final HabitBreakerService _habitBreakerService = HabitBreakerService();
  
  // スタイル定数（home_screen.dartと統一）
  static const Color kSectionBackgroundColor = Color(0xFF1E1E1E);
  static const double kSectionBorderRadius = 12.0;
  static const String kFontFamily = 'Hiragino Sans';
  static const Color kAccentColor = Color(0xFF1DB954);
  
  // プロフィール設定
  late TextEditingController _artistNameController;
  Uint8List? _artistImageBytes;
  bool _hasImageChanged = false;
  
  // 通知設定
  bool _isNotificationEnabled = false;
  int _selectedInterval = 15;  // 15, 30, 60のいずれか
  
  // UI状態
  bool _isLoading = true;
  bool _isSaving = false;
  String _appVersion = 'v1.0.0';

  @override
  void initState() {
    super.initState();
    _artistNameController = TextEditingController();
    _loadCurrentSettings();
  }

  @override
  void dispose() {
    _artistNameController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // アーティスト名を取得
      final userData = await _dataService.loadUserData();
      _artistNameController.text = userData['artistName'] ?? 'You';
      
      // アーティスト画像を取得
      _artistImageBytes = await _dataService.loadIdealImageBytes();
      
      // 通知設定を取得
      final notifConfig = await _habitBreakerService.getCurrentConfig();
      _isNotificationEnabled = notifConfig.isHabitBreakerEnabled;
      _selectedInterval = _normalizeInterval(notifConfig.habitBreakerInterval);
      
      // アプリバージョンを取得
      _appVersion = await _dataService.getAppVersion();
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('❌ 設定読み込みエラー: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  int _normalizeInterval(int interval) {
    if (interval <= 15) return 15;
    if (interval <= 30) return 30;
    return 60;
  }

  Future<void> _saveAllSettings() async {
    setState(() {
      _isSaving = true;
    });

    try {
      // 1. アーティスト名を保存
      final userData = await _dataService.loadUserData();
      userData['artistName'] = _artistNameController.text.trim().isEmpty 
          ? 'You' 
          : _artistNameController.text.trim();
      await _dataService.saveUserData(userData);
      
      // 2. アーティスト画像を保存（変更があれば）
      if (_hasImageChanged && _artistImageBytes != null) {
        await _dataService.saveIdealImageBytes(_artistImageBytes!);
      }
      
      // 3. 通知設定を保存
      final currentConfig = await _habitBreakerService.getCurrentConfig();
      final newConfig = currentConfig.copyWith(
        isHabitBreakerEnabled: _isNotificationEnabled,
        habitBreakerInterval: _selectedInterval,
      );
      await _habitBreakerService.updateSettings(newConfig);
      
      if (mounted) {
        _showMessage('設定を保存しました', isSuccess: true);
        
        // 画面を閉じる
        if (widget.onClose != null) {
          widget.onClose!();
        } else {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      print('❌ 設定保存エラー: $e');
      if (mounted) {
        _showMessage('保存に失敗しました', isSuccess: false);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _selectImageFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      
      final source = await _showImageSourceDialog();
      if (source == null) return;
      
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
      );
      
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _artistImageBytes = bytes;
          _hasImageChanged = true;
        });
        _showMessage('写真を選択しました', isSuccess: true);
      }
    } catch (e) {
      _showMessage('写真の選択に失敗しました', isSuccess: false);
    }
  }

  Future<ImageSource?> _showImageSourceDialog() async {
    return await showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Text(
            '写真を選択',
            style: TextStyle(color: Colors.white, fontFamily: kFontFamily),
          ),
          content: const Text(
            '写真の取得方法を選択してください',
            style: TextStyle(color: Colors.white70, fontFamily: kFontFamily),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'キャンセル',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(ImageSource.camera),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.camera_alt, color: kAccentColor, size: 20),
                  SizedBox(width: 8),
                  Text('カメラ', style: TextStyle(color: kAccentColor)),
                ],
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(ImageSource.gallery),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.photo_library, color: kAccentColor, size: 20),
                  SizedBox(width: 8),
                  Text('ギャラリー', style: TextStyle(color: kAccentColor)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(String message, {required bool isSuccess}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontFamily: kFontFamily),
              ),
            ),
          ],
        ),
        backgroundColor: isSuccess ? kAccentColor : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: kAccentColor,
                      ),
                    )
                  : _buildSettingsContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 中央のタイトル
          const Center(
            child: Text(
              'Settings',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                fontFamily: kFontFamily,
              ),
            ),
          ),
          
          // 左側の戻るボタン
          Positioned(
            left: 0,
            child: GestureDetector(
              onTap: widget.onClose ?? () => Navigator.pop(context),
              child: const Icon(
                Icons.chevron_left,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
          
          // 右側の保存ボタン
          Positioned(
            right: 0,
            child: GestureDetector(
              onTap: _isSaving ? null : _saveAllSettings,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _isSaving 
                      ? Colors.white.withOpacity(0.1)
                      : kAccentColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        '保存',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          fontFamily: kFontFamily,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildProfileSection(),
          const SizedBox(height: 20),
          _buildNotificationSection(),
          const SizedBox(height: 20),
          _buildLinkSection(
            icon: Icons.help_outline,
            title: 'ヘルプとフィードバック',
            onTap: () {
              _showMessage('準備中です', isSuccess: false);
            },
          ),
          const SizedBox(height: 12),
          _buildLinkSection(
            icon: Icons.privacy_tip_outlined,
            title: 'プライバシーポリシー',
            onTap: () {
              _showMessage('準備中です', isSuccess: false);
            },
          ),
          const SizedBox(height: 12),
          _buildLinkSection(
            icon: Icons.description_outlined,
            title: '利用規約',
            onTap: () {
              _showMessage('準備中です', isSuccess: false);
            },
          ),
          const SizedBox(height: 20),
          _buildVersionSection(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildProfileSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kSectionBackgroundColor,
        borderRadius: BorderRadius.circular(kSectionBorderRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'プロフィール設定',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              fontFamily: kFontFamily,
            ),
          ),
          const SizedBox(height: 20),
          
          // アイコン画像
          Center(
  child: GestureDetector(
    onTap: _selectImageFromGallery,
    child: Container(
      width: 100,
      height: 100,
      decoration: const BoxDecoration(  // 🔧 枠線削除、constに変更
        shape: BoxShape.circle,
      ),
      child: ClipOval(
                  child: _artistImageBytes != null
                      ? Image.memory(
                          _artistImageBytes!,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF8B5CF6),
                                Color(0xFF06B6D4),
                              ],
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 50,
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          Center(
            child: TextButton.icon(
              onPressed: _selectImageFromGallery,
              icon: const Icon(
                Icons.photo_library,
                color: kAccentColor,
                size: 18,
              ),
              label: const Text(
                '写真を変更',
                style: TextStyle(
                  color: kAccentColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  fontFamily: kFontFamily,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // アーティスト名
          const Text(
            'アーティスト名',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              fontFamily: kFontFamily,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _artistNameController,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontFamily: kFontFamily,
            ),
            decoration: InputDecoration(
              hintText: 'あなたの名前を入力',
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontFamily: kFontFamily,
              ),
              filled: true,
              fillColor: Colors.black.withOpacity(0.3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: kAccentColor,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kSectionBackgroundColor,
        borderRadius: BorderRadius.circular(kSectionBorderRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '通知設定',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              fontFamily: kFontFamily,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '定期的に行動を意識させる通知を送信します',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
              fontFamily: kFontFamily,
            ),
          ),
          const SizedBox(height: 20),
          
          // ON/OFFスイッチ
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '通知を有効にする',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  fontFamily: kFontFamily,
                ),
              ),
              Switch(
                value: _isNotificationEnabled,
                onChanged: (value) {
                  setState(() {
                    _isNotificationEnabled = value;
                  });
                },
                activeColor: kAccentColor,
                activeTrackColor: kAccentColor.withOpacity(0.3),
              ),
            ],
          ),
          
          if (_isNotificationEnabled) ...[
            const SizedBox(height: 20),
            
            // 通知間隔選択
            const Text(
              '通知間隔',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                fontFamily: kFontFamily,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildIntervalButton(15),
                const SizedBox(width: 12),
                _buildIntervalButton(30),
                const SizedBox(width: 12),
                _buildIntervalButton(60),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIntervalButton(int minutes) {
    final isSelected = _selectedInterval == minutes;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedInterval = minutes;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? kAccentColor : Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${minutes}分',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFamily: kFontFamily,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLinkSection({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kSectionBackgroundColor,
          borderRadius: BorderRadius.circular(kSectionBorderRadius),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  fontFamily: kFontFamily,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.white.withOpacity(0.5),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVersionSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSectionBackgroundColor,
        borderRadius: BorderRadius.circular(kSectionBorderRadius),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'バージョン情報',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                fontFamily: kFontFamily,
              ),
            ),
          ),
          Text(
            _appVersion,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
              fontFamily: kFontFamily,
            ),
          ),
        ],
      ),
    );
  }
}