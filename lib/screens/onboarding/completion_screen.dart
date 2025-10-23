// screens/onboarding/completion_screen.dart - アニメーション完全削除版
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:typed_data';
import '../../services/data_service.dart';

class CompletionScreen extends StatefulWidget {
  final String dreamTitle;
  final String artistName;
  final VoidCallback onComplete;
  final VoidCallback? onBack;
  final Uint8List? imageBytes;

  const CompletionScreen({
    super.key,
    required this.dreamTitle,
    required this.artistName,
    required this.onComplete,
    this.onBack,
    this.imageBytes,
  });

  @override
  State<CompletionScreen> createState() => _CompletionScreenState();
}

class _CompletionScreenState extends State<CompletionScreen> {
  final DataService _dataService = DataService();
  Uint8List? _displayImageBytes;
  String _albumImagePath = "";

  @override
  void initState() {
    super.initState();
    
    _displayImageBytes = widget.imageBytes;
    
    if (_displayImageBytes != null) {
      print('CompletionScreen: 画像データを受け取りました: ${_displayImageBytes!.length} bytes');
    } else {
      print('CompletionScreen: 画像データがありません');
    }
    
    _loadImageData();
  }

  Future<void> _loadImageData() async {
    try {
      final data = await _dataService.loadUserData();
      setState(() {
        _albumImagePath = data['albumImagePath'] ?? '';
      });
      
      if (_displayImageBytes != null) {
        print('渡された画像データを使用します');
        return;
      }
      
      final savedImageBytes = await _dataService.loadImageBytes();
      if (savedImageBytes != null) {
        setState(() {
          _displayImageBytes = savedImageBytes;
        });
        print('保存された画像を読み込みました: ${savedImageBytes.length} bytes');
      } else {
        print('保存された画像もありません');
      }
    } catch (e) {
      print('画像データ読み込みエラー: $e');
    }
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
              child: _buildMainContent(),
            ),
            _buildCompleteButton(),
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
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    final screenWidth = MediaQuery.of(context).size.width;
    const horizontalPadding = 20.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Center(child: _buildAlbumCover(screenWidth)),
        ),
        
        const SizedBox(height: 20),
        
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: _buildSongInfo(screenWidth),
        ),
        
        const Spacer(flex: 2),
        
        SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'どんなSNSの投稿より\n素敵なあなたに出会おう',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  fontFamily: 'Hiragino Sans',
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text(
                '今日の小さな選択が\nあなたの未来を変える',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  fontFamily: 'Hiragino Sans',
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        
        const Spacer(flex: 3),
      ],
    );
  }

  Widget _buildAlbumCover(double screenWidth) {
    final coverSize = screenWidth - 60;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _buildAlbumImage(coverSize),
      ),
    );
  }

  Widget _buildAlbumImage(double size) {
    if (_displayImageBytes != null) {
      print('画像データを表示します: ${_displayImageBytes!.length} bytes');
      return Image.memory(
        _displayImageBytes!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print('画像表示エラー: $error');
          return _buildDefaultAlbumCover(size);
        },
      );
    } else if (_albumImagePath.isNotEmpty && File(_albumImagePath).existsSync()) {
      return Image.file(
        File(_albumImagePath),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print('ファイル画像表示エラー: $error');
          return _buildDefaultAlbumCover(size);
        },
      );
    } else {
      return _buildDefaultAlbumCover(size);
    }
  }

  Widget _buildSongInfo(double screenWidth) {
    const horizontalPadding = 20.0;
    const albumMargin = 10.0;
    const albumLeftPosition = horizontalPadding + albumMargin;
    
    return Padding(
      padding: EdgeInsets.only(left: albumLeftPosition - horizontalPadding),
      child: SizedBox(
        width: screenWidth - albumLeftPosition - horizontalPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.dreamTitle,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                fontFamily: 'Hiragino Sans',
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.artistName,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w300,
                color: Colors.white.withOpacity(0.7),
                fontFamily: 'Hiragino Sans',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultAlbumCover(double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1DB954),
            Color(0xFF1ED760),
            Color(0xFF17A2B8),
          ],
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.album,
              size: 80,
              color: Colors.white,
            ),
            SizedBox(height: 16),
            Text(
              '理想像',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w300,
                fontFamily: 'Hiragino Sans',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompleteButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            widget.onComplete();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1DB954),
            foregroundColor: Colors.white,
            elevation: 8,
            shadowColor: const Color(0xFF1DB954).withOpacity(0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          child: const Text(
            'タスクをプレイする',
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