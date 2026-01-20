// models/reality_remaster_photo.dart
import 'dart:typed_data';

class RealityRemasterPhoto {
  final String id;
  final String taskId;
  final String? albumId;
  final bool isSingleAlbum;
  final Uint8List imageBytes;
  final DateTime capturedAt;

  RealityRemasterPhoto({
    required this.id,
    required this.taskId,
    this.albumId,
    required this.isSingleAlbum,
    required this.imageBytes,
    required this.capturedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'taskId': taskId,
      'albumId': albumId,
      'isSingleAlbum': isSingleAlbum,
      'imageBytes': imageBytes.toList(),
      'capturedAt': capturedAt.toIso8601String(),
    };
  }

  factory RealityRemasterPhoto.fromJson(Map<String, dynamic> json) {
    return RealityRemasterPhoto(
      id: json['id'] ?? '',
      taskId: json['taskId'] ?? '',
      albumId: json['albumId'],
      isSingleAlbum: json['isSingleAlbum'] ?? false,
      imageBytes: Uint8List.fromList(List<int>.from(json['imageBytes'] ?? [])),
      capturedAt: DateTime.tryParse(json['capturedAt'] ?? '') ?? DateTime.now(),
    );
  }
}