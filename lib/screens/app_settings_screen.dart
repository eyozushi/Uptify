// screens/app_settings_screen.dart
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart'; 
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
  int _selectedInterval = 30;  // 15, 30, 60のいずれか

  // 🆕 カスタム間隔設定用
  bool _isCustomInterval = false;
  late TextEditingController _customIntervalController;


  // 🆕 睡眠スケジュール設定
bool _isSleepScheduleEnabled = true;
int _bedtimeHour = 10;
int _bedtimeMinute = 0;
String _bedtimePeriod = 'PM';
int _wakeUpHour = 6;
int _wakeUpMinute = 0;
String _wakeUpPeriod = 'AM';

// 🆕 曜日別スケジュール設定（1=Sunday, 7=Saturday）
Set<int> _enabledDays = {1, 2, 3, 4, 5, 6, 7};

// 🆕 バリデーションエラー
String? _timeValidationError;
  
  // UI状態
  bool _isLoading = true;
  bool _isSaving = false;
  String _appVersion = 'v1.2.0';

  @override
  void initState() {
    super.initState();
    _artistNameController = TextEditingController();
    _customIntervalController = TextEditingController();  
    _loadCurrentSettings();
  }

  @override
  void dispose() {
    _artistNameController.dispose();
    _customIntervalController.dispose();
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
    _selectedInterval = notifConfig.habitBreakerInterval;
    
    // 🆕 カスタム間隔チェック
    if (_selectedInterval != 30 && _selectedInterval != 60) {
      _isCustomInterval = true;
      _customIntervalController.text = _selectedInterval.toString();
    } else {
      _isCustomInterval = false;
    }
    
    // 睡眠スケジュール設定を取得
    _isSleepScheduleEnabled = notifConfig.sleepScheduleEnabled;
    _bedtimeHour = notifConfig.bedtimeHour;
    _bedtimeMinute = notifConfig.bedtimeMinute;
    _bedtimePeriod = notifConfig.bedtimePeriod;
    _wakeUpHour = notifConfig.wakeUpHour;
    _wakeUpMinute = notifConfig.wakeUpMinute;
    _wakeUpPeriod = notifConfig.wakeUpPeriod;
    
    // 曜日別スケジュール設定を取得
    _enabledDays = Set<int>.from(notifConfig.enabledDays);
    
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

  
  Future<void> _saveAllSettings() async {
  // バリデーションチェック
  if (_isSleepScheduleEnabled && _isSameTime()) {
    setState(() {
      _timeValidationError = 'Bedtime and wake-up time cannot be the same';
    });
    _showMessage('Invalid time settings', isSuccess: false);
    return;
  }
  
  // 全曜日無効チェック
  if (_enabledDays.isEmpty) {
    _showMessage('Please enable at least one day', isSuccess: false);
    return;
  }
  
  // 🆕 カスタム間隔のバリデーション
  int finalInterval = _selectedInterval;
  if (_isCustomInterval) {
    final customValue = int.tryParse(_customIntervalController.text);
    if (customValue == null || customValue < 1 || customValue > 1440) {
      _showMessage('Please enter a valid interval (1-1440 minutes)', isSuccess: false);
      return;
    }
    finalInterval = customValue;
  }
  
  setState(() {
    _isSaving = true;
    _timeValidationError = null;
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
      habitBreakerInterval: finalInterval,  // 🔧 修正: カスタム値を使用
      sleepScheduleEnabled: _isSleepScheduleEnabled,
      bedtimeHour: _bedtimeHour,
      bedtimeMinute: _bedtimeMinute,
      bedtimePeriod: _bedtimePeriod,
      wakeUpHour: _wakeUpHour,
      wakeUpMinute: _wakeUpMinute,
      wakeUpPeriod: _wakeUpPeriod,
      enabledDays: _enabledDays,
    );
    await _habitBreakerService.updateSettings(newConfig);
    
    if (mounted) {
      _showMessage('Settings saved', isSuccess: true);
      
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
      _showMessage('Failed to save', isSuccess: false);
    }
  } finally {
    if (mounted) {
      setState(() {
        _isSaving = false;
      });
    }
  }
}

/// 就寝時刻と起床時刻が同じかチェック
bool _isSameTime() {
  final bedtime24 = _convertTo24Hour(_bedtimeHour, _bedtimePeriod);
  final wakeUp24 = _convertTo24Hour(_wakeUpHour, _wakeUpPeriod);
  return bedtime24 == wakeUp24 && _bedtimeMinute == _wakeUpMinute;
}

/// 12時間形式を24時間形式に変換
int _convertTo24Hour(int hour, String period) {
  if (period == 'AM') {
    return hour == 12 ? 0 : hour;
  } else {
    return hour == 12 ? 12 : hour + 12;
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
        _showMessage('Photo selected', isSuccess: true);
      }
    } catch (e) {
      _showMessage('Failed to select photo', isSuccess: false);
    }
  }

  Future<ImageSource?> _showImageSourceDialog() async {
    return await showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF282828),
          title: const Text(
            'Select Photo',
            style: TextStyle(color: Colors.white, fontFamily: kFontFamily),
          ),
          content: const Text(
            'Choose how to get photo',
            style: TextStyle(color: Colors.white70, fontFamily: kFontFamily),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
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
                  Text('Camera', style: TextStyle(color: kAccentColor)),
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
                  Text('Gallery', style: TextStyle(color: kAccentColor)),
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
      bottom: false,  // 🔧 追加: 下部のSafeAreaを無効化
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
            letterSpacing: -0.3,
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
                        'Save',
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
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),  // 🔧 下部パディングを40に増加
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        
        // Profile Settings（元のまま保持）
        _buildProfileSection(),
        
        const SizedBox(height: 30),
        
        // Notifications（統合版）
        _buildUnifiedNotificationSection(),
        
        const SizedBox(height: 30),
        
        // Version（元のまま保持）
        _buildVersionSection(),
        
        const SizedBox(height: 40),  // 🔧 最後の余白を40に変更
      ],
    ),
  );
}

  Widget _buildProfileSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // 🆕 追加：セクションヘッダー（枠の外）
      Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: kAccentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Profile Settings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              letterSpacing: -0.2,
              fontWeight: FontWeight.w600,
              fontFamily: kFontFamily,
            ),
          ),
        ],
      ),
      
      const SizedBox(height: 16),
      
      // コンテンツ（既存の枠）
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kSectionBackgroundColor,
          borderRadius: BorderRadius.circular(kSectionBorderRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🗑️ 削除：セクションタイトルを削除（上に移動したため）
            
            // アイコン画像
            Center(
              child: GestureDetector(
                onTap: _selectImageFromGallery,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: const BoxDecoration(
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
                  'Change Photo',
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
              'Artist Name',
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
                hintText: 'Enter your name',
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
      ),
    ],
  );
}

  Widget _buildUnifiedNotificationSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // 🔧 修正：縦棒を追加
      Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: kAccentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Notifications',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              letterSpacing: -0.2,
              fontWeight: FontWeight.w600,
              fontFamily: kFontFamily,
            ),
          ),
        ],
      ),
      
      const SizedBox(height: 16),
      
      // 統合コンテナ
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kSectionBackgroundColor,
          borderRadius: BorderRadius.circular(kSectionBorderRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Notification Interval
            _buildNotificationIntervalSettings(),
            
            const SizedBox(height: 24),
            
            Divider(
              color: Colors.white.withOpacity(0.1),
              height: 1,
            ),
            
            const SizedBox(height: 24),
            
            // 2. Active Days（一番上から2番目に移動）
            _buildActiveDaysInline(),
            
            const SizedBox(height: 24),
            
            Divider(
              color: Colors.white.withOpacity(0.1),
              height: 1,
            ),
            
            const SizedBox(height: 24),
            
            // 3. Sleep Schedule（一番下に移動）
            _buildSleepScheduleInline(),
          ],
        ),
      ),
    ],
  );
}




Widget _buildNotificationIntervalSettings() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Header with switch
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Notification Interval',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: kFontFamily,
            ),
          ),
          Switch(
            value: _isNotificationEnabled,
            activeColor: kAccentColor,
            onChanged: (value) {
              setState(() {
                _isNotificationEnabled = value;
              });
            },
          ),
        ],
      ),
      
      const SizedBox(height: 8),
      
      Text(
        'How often should we remind you?',
        style: TextStyle(
          color: Colors.white.withOpacity(0.6),
          fontSize: 14,
          fontFamily: kFontFamily,
        ),
      ),
      
      // Only show interval buttons when enabled
      if (_isNotificationEnabled) ...[
        const SizedBox(height: 16),
        
        // Interval buttons - 均等配置に変更
        Row(
          children: [
            Expanded(child: _buildIntervalButton(label: '30 min', minutes: 30)),
            const SizedBox(width: 8),
            Expanded(child: _buildIntervalButton(label: '1 hour', minutes: 60)),
            const SizedBox(width: 8),
            Expanded(child: _buildCustomIntervalButton()),
          ],
        ),
        
        // Custom interval input
        if (_isCustomInterval) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customIntervalController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontFamily: kFontFamily,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter minutes (1-1440)',
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
              ),
              const SizedBox(width: 8),
              Text(
                'minutes',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 14,
                  fontFamily: kFontFamily,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Recommended: 30-60 minutes for best results',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 12,
              fontFamily: kFontFamily,
            ),
          ),
        ],
      ] else ...[
        // Disabled message
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Notifications are disabled',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 12,
              fontFamily: kFontFamily,
            ),
          ),
        ),
      ],
    ],
  );
}

Widget _buildSleepScheduleInline() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Header with switch
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Sleep Schedule',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: kFontFamily,
            ),
          ),
          Switch(
            value: _isSleepScheduleEnabled,
            activeColor: kAccentColor,
            onChanged: (value) {
              setState(() {
                _isSleepScheduleEnabled = value;
              });
            },
          ),
        ],
      ),
      
      const SizedBox(height: 8),
      
      Text(
        'Pause notifications during sleep hours',
        style: TextStyle(
          color: Colors.white.withOpacity(0.6),
          fontSize: 14,
          fontFamily: kFontFamily,
        ),
      ),
      
      if (_isSleepScheduleEnabled) ...[
        const SizedBox(height: 16),
        
        // Bedtime
        _buildTimePickerRow(
          label: 'Bedtime',
          icon: Icons.bedtime,
          hour: _bedtimeHour,
          minute: _bedtimeMinute,
          period: _bedtimePeriod,
          onHourChanged: (value) => setState(() => _bedtimeHour = value),
          onMinuteChanged: (value) => setState(() => _bedtimeMinute = value),
          onPeriodChanged: (value) => setState(() => _bedtimePeriod = value),
        ),
        
        const SizedBox(height: 12),
        
        // Wake Up
        _buildTimePickerRow(
          label: 'Wake Up',
          icon: Icons.wb_sunny,
          hour: _wakeUpHour,
          minute: _wakeUpMinute,
          period: _wakeUpPeriod,
          onHourChanged: (value) => setState(() => _wakeUpHour = value),
          onMinuteChanged: (value) => setState(() => _wakeUpMinute = value),
          onPeriodChanged: (value) => setState(() => _wakeUpPeriod = value),
        ),
        
        // Validation error
        if (_timeValidationError != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _timeValidationError!,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
                fontFamily: kFontFamily,
              ),
            ),
          ),
        ],
      ],
    ],
  );
}

Widget _buildActiveDaysInline() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Active Days',
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          fontFamily: kFontFamily,
        ),
      ),
      
      const SizedBox(height: 8),
      
      Text(
        'Select days to receive notifications',
        style: TextStyle(
          color: Colors.white.withOpacity(0.6),
          fontSize: 14,
          fontFamily: kFontFamily,
        ),
      ),
      
      const SizedBox(height: 16),
      
      // Day buttons
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildDayButton(label: 'S', dayIndex: 1),
          _buildDayButton(label: 'M', dayIndex: 2),
          _buildDayButton(label: 'T', dayIndex: 3),
          _buildDayButton(label: 'W', dayIndex: 4),
          _buildDayButton(label: 'T', dayIndex: 5),
          _buildDayButton(label: 'F', dayIndex: 6),
          _buildDayButton(label: 'S', dayIndex: 7),
        ],
      ),
      
      // Warning if all days disabled
      if (_enabledDays.isEmpty) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'All days are disabled. Notifications will not be sent.',
            style: TextStyle(
              color: Colors.orange,
              fontSize: 12,
              fontFamily: kFontFamily,
            ),
          ),
        ),
      ],
    ],
  );
}



  Widget _buildIntervalButton({required String label, required int minutes}) {
  final isSelected = !_isCustomInterval && _selectedInterval == minutes;
  
  return GestureDetector(
    onTap: () {
      setState(() {
        _isCustomInterval = false;
        _selectedInterval = minutes;
      });
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isSelected 
            ? const Color(0xFF1DB954) 
            : const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          fontFamily: kFontFamily,
        ),
      ),
    ),
  );
}

Widget _buildCustomIntervalButton() {
  return GestureDetector(
    onTap: () {
      setState(() {
        _isCustomInterval = true;
        if (_customIntervalController.text.isEmpty) {
          _customIntervalController.text = '45';
        }
      });
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: _isCustomInterval 
            ? const Color(0xFF1DB954) 
            : const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Custom',
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: _isCustomInterval ? FontWeight.w600 : FontWeight.w400,
          fontFamily: kFontFamily,
        ),
      ),
    ),
  );
}


/// 時刻ピッカー行
Widget _buildTimePickerRow({
  required String label,
  required IconData icon,
  required int hour,
  required int minute,
  required String period,
  required ValueChanged<int> onHourChanged,
  required ValueChanged<int> onMinuteChanged,
  required ValueChanged<String> onPeriodChanged,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Label with icon
      Row(
        children: [
          Icon(
            icon,
            color: const Color(0xFF1DB954),
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
              fontWeight: FontWeight.w500,
              fontFamily: 'Hiragino Sans',
            ),
          ),
        ],
      ),
      
      const SizedBox(height: 8),
      
      // Time picker controls
      Row(
        children: [
          // Hour dropdown
          Expanded(
            flex: 2,
            child: _buildTimeDropdown(
              value: hour,
              items: List.generate(12, (i) => i + 1),
              onChanged: onHourChanged,
            ),
          ),
          
          const SizedBox(width: 4),
          
          // Colon
          const Text(
            ':',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          
          const SizedBox(width: 4),
          
          // Minute dropdown
          Expanded(
            flex: 2,
            child: _buildTimeDropdown(
              value: minute,
              items: [0, 15, 30, 45],
              onChanged: onMinuteChanged,
            ),
          ),
          
          const SizedBox(width: 8),
          
          // AM/PM toggle
          Expanded(
            flex: 2,
            child: _buildPeriodToggle(
              period: period,
              onChanged: onPeriodChanged,
            ),
          ),
        ],
      ),
    ],
  );
}
/// 時刻ドロップダウン
Widget _buildTimeDropdown({
  required int value,
  required List<int> items,
  required ValueChanged<int> onChanged,
}) {
  return Container(
    height: 44,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    decoration: BoxDecoration(
      color: const Color(0xFF2A2A2A),
      borderRadius: BorderRadius.circular(8),

    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<int>(
        value: value,
        isExpanded: true,
        dropdownColor: const Color(0xFF2A2A2A),
        icon: Icon(
          Icons.arrow_drop_down,
          color: Colors.white.withOpacity(0.6),
        ),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontFamily: 'SF Pro Text',
        ),
        items: items.map((int item) {
          return DropdownMenuItem<int>(
            value: item,
            child: Center(
              child: Text(
                item.toString().padLeft(2, '0'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontFamily: 'SF Pro Text',
                ),
              ),
            ),
          );
        }).toList(),
        onChanged: (int? newValue) {
          if (newValue != null) {
            onChanged(newValue);
          }
        },
      ),
    ),
  );
}

/// AM/PMトグル
Widget _buildPeriodToggle({
  required String period,
  required ValueChanged<String> onChanged,
}) {
  return Container(
    height: 44,
    decoration: BoxDecoration(
      color: const Color(0xFF2A2A2A),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Expanded(
          child: _buildPeriodButton(
            label: 'AM',
            isSelected: period == 'AM',
            onTap: () => onChanged('AM'),
            isLeft: true,
          ),
        ),
        Expanded(
          child: _buildPeriodButton(
            label: 'PM',
            isSelected: period == 'PM',
            onTap: () => onChanged('PM'),
            isLeft: false,
          ),
        ),
      ],
    ),
  );
}

/// AM/PMボタン
Widget _buildPeriodButton({
  required String label,
  required bool isSelected,
  required VoidCallback onTap,
  bool isLeft = false,  // この引数は使われていないが、呼び出し元から渡されているので残す
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: 45,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? kAccentColor : Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.5),
          fontSize: 13,
          fontWeight: FontWeight.w600,
          fontFamily: kFontFamily,
        ),
      ),
    ),
  );
}

Widget _buildDayButton({required String label, required int dayIndex}) {
  final isEnabled = _enabledDays.contains(dayIndex);
  
  return GestureDetector(
    onTap: () {
      setState(() {
        if (isEnabled) {
          _enabledDays.remove(dayIndex);
        } else {
          _enabledDays.add(dayIndex);
        }
      });
    },
    child: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: isEnabled ? const Color(0xFF1DB954) : const Color(0xFF404040),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: 'SF Pro Text',
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

  /// 🆕 新規追加：App Storeを開く
Future<void> _openAppStore() async {
  const appStoreUrl = 'https://apps.apple.com/us/app/uptify-be-your-fan/id6756293416';
  
  final uri = Uri.parse(appStoreUrl);
  
  try {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        _showMessage('Failed to open App Store', isSuccess: false);
      }
    }
  } catch (e) {
    print('❌ App Store起動エラー: $e');
    if (mounted) {
      _showMessage('Failed to open App Store', isSuccess: false);
    }
  }
}


  Widget _buildVersionSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // バージョン情報カード
      Container(
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
                'Version',
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
      ),
      
      const SizedBox(height: 12),
      
      // App Storeリンクボタン
      GestureDetector(
        onTap: _openAppStore,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kSectionBackgroundColor,
            borderRadius: BorderRadius.circular(kSectionBorderRadius),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.store,
                color: kAccentColor,
                size: 24,
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'View in App Store',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    fontFamily: kFontFamily,
                  ),
                ),
              ),
              Icon(
                Icons.open_in_new,
                color: Colors.white.withOpacity(0.5),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    ],
  ); // 🔧 この閉じカッコと return の確認
}
}