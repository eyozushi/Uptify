// screens/onboarding/artist_name_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'dart:math' as math;

class ArtistNameScreen extends StatefulWidget {
  final String? initialArtistName;
  final Uint8List? initialImageBytes;
  final Function(String artistName, Uint8List? imageBytes) onNext;
  final VoidCallback? onBack;

  const ArtistNameScreen({
    super.key,
    this.initialArtistName,
    this.initialImageBytes,
    required this.onNext,
    this.onBack,
  });

  @override
  State<ArtistNameScreen> createState() => _ArtistNameScreenState();
}

class _ArtistNameScreenState extends State<ArtistNameScreen>
    with TickerProviderStateMixin {
  late TextEditingController _controller;
  late AnimationController _animationController;
  late AnimationController _backgroundController;
  late Animation<double> _fadeInAnimation;
  late Animation<double> _slideUpAnimation;
  
  bool _isFormValid = false;
  Uint8List? _selectedImageBytes;

  @override
  void initState() {
    super.initState();
    
    _controller = TextEditingController(text: widget.initialArtistName ?? '');
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
    
    // 初期バリデーション
    _validateForm();
    _controller.addListener(_validateForm);
    
    // アニメーション開始
    _animationController.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _animationController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  void _validateForm() {
    setState(() {
      _isFormValid = _controller.text.trim().isNotEmpty;
    });
  }

  void _onNextPressed() {
  HapticFeedback.lightImpact();
  
  final artistName = _controller.text.trim();
  
  if (artistName.isEmpty) {
    _showErrorMessage('Please enter your artist name');
    return;
  }
  
  widget.onNext(artistName, _selectedImageBytes);
}


  Future<void> _selectImage() async {
    try {
      final source = await _showImageSourceDialog();
      if (source == null) return;
      
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 85,
      );
      
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
        });
        _showSuccessMessage('Photo selected');
      }
    } catch (e) {
      _showErrorMessage('Failed to select photo');
    }
  }

  Future<ImageSource?> _showImageSourceDialog() async {
    return await showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
  backgroundColor: const Color(0xFF2A2A2A), // 🔄 0xFF1A1A2E → 灰色に変更
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(20),
  ),
  title: const Text(
    'Select Profile Photo', // 🔄 改行なし
    style: TextStyle(
      color: Colors.white, 
      fontFamily: 'Hiragino Sans',
      fontWeight: FontWeight.bold,
    ),
  ),
  content: const Text(
  'Where would you like\nto choose from?', // 🔄 改行位置を調整
  style: TextStyle(
    color: Colors.white70, 
    fontFamily: 'Hiragino Sans',
  ),
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
                  Icon(Icons.camera_alt, color: Color(0xFF1DB954), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Camera',
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
                    'Gallery',
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

  void _showValidationMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white),
            SizedBox(width: 12),
            Text(
              'Please enter your artist name',
              style: TextStyle(fontFamily: 'Hiragino Sans'),
            ),
          ],
        ),
        backgroundColor: Colors.orange,
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
            'Step 1 of 4',
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
        final iconPosition = screenHeight * 0.25; // 画面の25%の位置
        
        return Stack(
          children: [
            // アイコン（画面の上から25%の位置に固定）
            Positioned(
              top: iconPosition - 50, // アイコンの中心が25%の位置になるよう調整
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _selectImage,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1DB954),
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: _selectedImageBytes != null
                          ? Image.memory(
                              _selectedImageBytes!,
                              fit: BoxFit.cover,
                              width: 100,
                              height: 100,
                            )
                          : Stack(
                              alignment: Alignment.center,
                              children: [
                                const Icon(
                                  Icons.person,
                                  size: 50,
                                  color: Colors.white,
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFF1DB954),
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      size: 16,
                                      color: Color(0xFF1DB954),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),

            // 🆕 以下を追加
Positioned(
  top: iconPosition - 70,
  left: 0,
  right: 0,
  child: Text(
    'Tap to set icon',
    style: TextStyle(
      fontSize: 12,
      color: Colors.white,
      fontFamily: 'Hiragino Sans',
    ),
    textAlign: TextAlign.center,
  ),
),
            
            // 質問文（画面の50%の位置）
            Positioned(
              top: screenHeight * 0.5 - 20, // 質問文が50%の位置になるよう調整
              left: 0,
              right: 0,
              child: const Text(
                'What\'s your artist name?',
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
            
            // 入力フィールド（画面の75%の位置）
            Positioned(
              top: screenHeight * 0.75 - 30, // 入力フィールドが75%の位置になるよう調整
              left: 32,
              right: 32,
              child: _buildInputField(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInputField() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TextField(
        controller: _controller,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          fontFamily: 'Hiragino Sans',
        ),
        decoration: InputDecoration(
          hintText: 'Your name',
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 20,
            fontFamily: 'Hiragino Sans',
          ),
          filled: true,
          fillColor: Colors.white.withOpacity(0.15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 20,
          ),
        ),
        onSubmitted: (value) {
          if (_isFormValid) {
            _onNextPressed();
          }
        },
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
          onPressed: _isFormValid ? _onNextPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _isFormValid 
                ? const Color(0xFF1DB954) 
                : Colors.white.withOpacity(0.1),
            foregroundColor: Colors.white,
            elevation: _isFormValid ? 8 : 0,
            shadowColor: const Color(0xFF1DB954).withOpacity(0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          child: const Text(
            'Next',
            style: TextStyle(
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