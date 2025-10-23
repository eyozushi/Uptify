// screens/onboarding/image_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'dart:math' as math;

class ImageSelectionScreen extends StatefulWidget {
  final Uint8List? initialImageBytes;
  final Function(Uint8List? imageBytes) onNext;
  final VoidCallback? onBack;

  const ImageSelectionScreen({
    super.key,
    this.initialImageBytes,
    required this.onNext,
    this.onBack,
  });

  @override
  State<ImageSelectionScreen> createState() => _ImageSelectionScreenState();
}

class _ImageSelectionScreenState extends State<ImageSelectionScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _backgroundController;
  late Animation<double> _fadeInAnimation;
  late Animation<double> _slideUpAnimation;
  late Animation<double> _scaleAnimation;
  
  Uint8List? _selectedImageBytes;

  @override
  void initState() {
    super.initState();
    
    _selectedImageBytes = widget.initialImageBytes;
    
    // アニメーション初期化
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    )..repeat();
    
    _fadeInAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));
    
    _slideUpAnimation = Tween<double>(
      begin: 30.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.4, 1.0, curve: Curves.elasticOut),
    ));
    
    // アニメーション開始
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  Future<void> _selectImageFromGallery() async {
    try {
      final source = await _showImageSourceDialog();
      if (source == null) return;
      
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
      );
      
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
        });
      }
    } catch (e) {
      _showErrorMessage('写真の選択に失敗しました');
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImageBytes = null;
    });
    _showSuccessMessage('写真を削除しました');
  }

  void _onNextPressed() {
    HapticFeedback.lightImpact();
    widget.onNext(_selectedImageBytes);
  }

  Future<ImageSource?> _showImageSourceDialog() async {
    return await showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            '理想像の写真を選択',
            style: TextStyle(
              color: Colors.white, 
              fontFamily: 'Hiragino Sans',
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'あなたの理想像を表す写真を\nどこから選びますか？',
            style: TextStyle(
              color: Colors.white70, 
              fontFamily: 'Hiragino Sans',
            ),
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
                  Icon(Icons.camera_alt, color: Color(0xFF1DB954), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'カメラ',
                    style: TextStyle(color: Color(0xFF1DB954)),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(ImageSource.gallery),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.photo_library, color: Color(0xFF1DB954), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'ギャラリー',
                    style: TextStyle(color: Color(0xFF1DB954)),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Text(
              message,
              style: const TextStyle(fontFamily: 'Hiragino Sans'),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1DB954),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Text(
              message,
              style: const TextStyle(fontFamily: 'Hiragino Sans'),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
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
            // ヘッダー
            _buildHeader(),
            
            // メインコンテンツ
            Expanded(
              child: _buildMainContent(),
            ),
            
            // 次へボタン
            _buildNextButton(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (widget.onBack != null)
            IconButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                widget.onBack!();
              },
              icon: const Icon(
                Icons.keyboard_arrow_down,
                color: Colors.white,
                size: 28,
              ),
            ),
          const Spacer(),
          Text(
            'Step 3 of 4',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
              fontFamily: 'Hiragino Sans',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenHeight = constraints.maxHeight;
        
        return Stack(
          children: [
            // アイコン（画面の上から25%の位置に固定）
            Positioned(
              top: screenHeight * 0.25 - 40,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1DB954),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.photo_camera,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            
            // 質問文（画面の50%の位置）
            Positioned(
              top: screenHeight * 0.5 - 20,
              left: 0,
              right: 0,
              child: const Text(
                'その理想のイメージは？',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'Hiragino Sans',
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            // 画像選択エリア（画面の75%の位置）
            Positioned(
              top: screenHeight * 0.75 - 75, // 正方形の中心が75%の位置になるよう調整
              left: 0,
              right: 0,
              child: Center(
                child: _buildImagePreview(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildImagePreview() {
    return GestureDetector(
      onTap: _selectImageFromGallery,
      child: Container(
        width: 150,
        height: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFF1DB954),
        ),
        child: _selectedImageBytes != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(
                  _selectedImageBytes!,
                  width: 150,
                  height: 150,
                  fit: BoxFit.cover,
                ),
              )
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate,
                    size: 50,
                    color: Colors.white,
                  ),
                  SizedBox(height: 12),
                  Text(
                    '選択',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Hiragino Sans',
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildNextButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _onNextPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1DB954),
            foregroundColor: Colors.white,
            elevation: 8,
            shadowColor: const Color(0xFF1DB954).withOpacity(0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          child: Text(
            _selectedImageBytes != null ? '次へ' : '写真なしで次へ',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              fontFamily: 'Hiragino Sans',
            ),
          ),
        ),
      ),
    );
  }
}