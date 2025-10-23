// screens/notification_settings_screen.dart
import 'package:flutter/material.dart';
import '../models/notification_config.dart';
import '../services/habit_breaker_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  final VoidCallback? onClose;

  const NotificationSettingsScreen({
    super.key,
    this.onClose,
  });

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final HabitBreakerService _habitBreakerService = HabitBreakerService();
  
  NotificationConfig _config = const NotificationConfig();
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final config = await _habitBreakerService.getCurrentConfig();
      setState(() {
        _config = config;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ 通知設定読み込みエラー: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    setState(() {
      _isSaving = true;
    });

    try {
      await _habitBreakerService.updateSettings(_config);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('通知設定を保存しました'),
            backgroundColor: const Color(0xFF1DB954),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ 通知設定保存エラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('設定の保存に失敗しました'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _sendTestNotification() async {
    try {
      await _habitBreakerService.sendTestNotification();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('テスト通知を送信しました'),
            backgroundColor: const Color(0xFF1DB954),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ テスト通知エラー: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF2D1B69),
              Color(0xFF1A1A2E),
              Color(0xFF000000),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ヘッダー
              _buildHeader(),
              
              // メインコンテンツ
              Expanded(
                child: _isLoading 
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF1DB954),
                        ),
                      )
                    : _buildSettingsContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          IconButton(
            onPressed: widget.onClose ?? () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            '通知設定',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              fontFamily: 'Hiragino Sans',
            ),
          ),
          const Spacer(),
          // 保存ボタン
          SizedBox(
            height: 36,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1DB954),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      '保存',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SNS中毒抑制通知セクション
          _buildSectionCard(
            title: 'SNS中毒抑制通知',
            description: '定期的に行動を意識させる通知を送信します',
            child: Column(
              children: [
                // ON/OFF切り替え
                _buildSwitchTile(
                  title: '通知を有効にする',
                  value: _config.isHabitBreakerEnabled,
                  onChanged: (value) {
                    setState(() {
                      _config = _config.copyWith(isHabitBreakerEnabled: value);
                    });
                  },
                ),
                
                if (_config.isHabitBreakerEnabled) ...[
                  const SizedBox(height: 20),
                  
                  // 通知間隔設定
                  _buildIntervalSetting(),
                  
                  const SizedBox(height: 20),
                  
                  // テスト通知ボタン
                  _buildTestNotificationButton(),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 通知メッセージセクション
          if (_config.isHabitBreakerEnabled) _buildMessageSection(),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String description,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              fontFamily: 'Hiragino Sans',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
              fontFamily: 'Hiragino Sans',
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            fontFamily: 'Hiragino Sans',
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF1DB954),
          activeTrackColor: const Color(0xFF1DB954).withOpacity(0.3),
        ),
      ],
    );
  }

  Widget _buildIntervalSetting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '通知間隔: ${_config.habitBreakerInterval}分',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            fontFamily: 'Hiragino Sans',
          ),
        ),
        const SizedBox(height: 12),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: const Color(0xFF1DB954),
            inactiveTrackColor: Colors.white.withOpacity(0.3),
            thumbColor: const Color(0xFF1DB954),
            overlayColor: const Color(0xFF1DB954).withOpacity(0.3),
            trackHeight: 4,
          ),
          child: Slider(
            value: _config.habitBreakerInterval.toDouble(),
            min: 1, // 1分から設定可能
            max: 60,
            divisions: 59, // 1分刻みで59個の選択肢
            onChanged: (value) {
              setState(() {
                _config = _config.copyWith(habitBreakerInterval: value.round());
              });
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '1分（テスト用）',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
            Text(
              '60分',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
        if (_config.habitBreakerInterval <= 5) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.orange.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_config.habitBreakerInterval}分間隔はテスト用です。実用では15分以上を推奨します。',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                      fontFamily: 'Hiragino Sans',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTestNotificationButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: _sendTestNotification,
        icon: const Icon(Icons.notifications_active, color: Colors.white),
        label: const Text(
          'テスト通知を送信',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontFamily: 'Hiragino Sans',
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withOpacity(0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(
            color: Colors.white.withOpacity(0.3),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageSection() {
    return _buildSectionCard(
      title: '通知メッセージ',
      description: '以下のメッセージがランダムに表示されます',
      child: Column(
        children: _config.habitBreakerMessages.asMap().entries.map((entry) {
          final index = entry.key;
          final message = entry.value;
          
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
              ),
            ),
            child: Text(
              '${index + 1}. $message',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
                fontFamily: 'Hiragino Sans',
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}