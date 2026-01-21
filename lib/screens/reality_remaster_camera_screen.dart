// screens/reality_remaster_camera_screen.dart
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../models/reality_remaster_photo.dart';
import '../services/data_service.dart';

class RealityRemasterCameraScreen extends StatefulWidget {
  final String taskId;
  final String? albumId;
  final bool isSingleAlbum;
  
  const RealityRemasterCameraScreen({
    super.key,
    required this.taskId,
    this.albumId,
    required this.isSingleAlbum,
  });

  @override
  State<RealityRemasterCameraScreen> createState() => _RealityRemasterCameraScreenState();
}

class _RealityRemasterCameraScreenState extends State<RealityRemasterCameraScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isProcessing = false;
  Uint8List? _capturedImageBytes;
  int _selectedCameraIndex = 0;
  final DataService _dataService = DataService();
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  // 🆕 カメラ初期化
  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        print('❌ カメラが見つかりません');
        return;
      }

      _cameraController = CameraController(
        _cameras![_selectedCameraIndex],
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      print('❌ カメラ初期化エラー: $e');
    }
  }

  // 🆕 カメラ切り替え
  Future<void> _toggleCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;
    
    setState(() {
      _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras!.length;
    });
    
    await _cameraController?.dispose();
    await _initializeCamera();
  }

  // 🆕 写真撮影
  Future<void> _takePicture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final XFile image = await _cameraController!.takePicture();
      final bytes = await image.readAsBytes();
      
      setState(() {
        _capturedImageBytes = bytes;
        _isProcessing = false;
      });
    } catch (e) {
      print('❌ 写真撮影エラー: $e');
      setState(() {
        _isProcessing = false;
      });
    }
  }

  // 🆕 ギャラリーから選択
  Future<void> _pickFromGallery() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _capturedImageBytes = bytes;
        });
      }
    } catch (e) {
      print('❌ ギャラリー選択エラー: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  // 🆕 Reality Remasterをリリース
  Future<void> _releaseRealityRemaster() async {
    if (_capturedImageBytes == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final photo = RealityRemasterPhoto(
        id: _dataService.generateRealityRemasterPhotoId(),
        taskId: widget.taskId,
        albumId: widget.albumId,
        isSingleAlbum: widget.isSingleAlbum,
        imageBytes: _capturedImageBytes!,
        capturedAt: DateTime.now(),
      );

      await _dataService.saveRealityRemasterPhoto(photo);

      if (mounted) {
        Navigator.of(context).pop(true); // true = 写真が保存された
      }
    } catch (e) {
      print('❌ Reality Remasterリリースエラー: $e');
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_capturedImageBytes != null) {
      return _buildPreviewScreen();
    }

    return _buildCameraScreen();
  }

  // 🔧 修正: カメラ画面
  Widget _buildCameraScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 🔧 修正: カメラプレビュー（正方形）
          if (_isInitialized && _cameraController != null)
            Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final screenWidth = MediaQuery.of(context).size.width;
                  
                  return SizedBox(
                    width: screenWidth,
                    height: screenWidth, // 正方形
                    child: ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.center,
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: screenWidth,
                            height: screenWidth / _cameraController!.value.aspectRatio,
                            child: CameraPreview(_cameraController!),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            ),

          // 上部: タイトル
          Positioned(
            top: MediaQuery.of(context).padding.top + 20,
            left: 0,
            right: 0,
            child: const Text(
              'Remaster Your Ideal',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                fontFamily: 'Hiragino Sans',
                letterSpacing: -1.0,
              ),
            ),
          ),

          // 下部: コントロール
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // ギャラリーボタン
                _buildControlButton(
                  icon: Icons.photo_library,
                  onTap: _pickFromGallery,
                ),

                // シャッターボタン
                GestureDetector(
                  onTap: _takePicture,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF1DB954),
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                    ),
                  ),
                ),

                // カメラ切り替えボタン
                _buildControlButton(
                  icon: Icons.cameraswitch,
                  onTap: _toggleCamera,
                ),
              ],
            ),
          ),

          // 閉じるボタン
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            child: IconButton(
              icon: const Icon(
                Icons.close,
                color: Colors.white,
                size: 28,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),

          // ローディング
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 🔧 修正: プレビュー画面
  Widget _buildPreviewScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // タイトル
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: const Text(
                'Remaster Your Ideal',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Hiragino Sans',
                  letterSpacing: -1.0,
                ),
              ),
            ),

            // 中央: プレビュー画像
            Expanded(
              child: Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final screenWidth = MediaQuery.of(context).size.width;
                    final size = screenWidth - 80;
                    
                    return Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          _capturedImageBytes!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // 下部: ボタン群
            Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // リリースボタン
                  GestureDetector(
                    onTap: _isProcessing ? null : _releaseRealityRemaster,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1DB954),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _isProcessing
                          ? const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'Release Reality Remaster',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Hiragino Sans',
                              ),
                            ),
                    ),
                  ),

                  // 戻るボタン
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _capturedImageBytes = null;
                      });
                    },
                    child: const Text(
                      'Retake',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontFamily: 'Hiragino Sans',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🆕 コントロールボタン
  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black45,
          border: Border.all(
            color: Colors.white,
            width: 2,
          ),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}