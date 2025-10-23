// models/single_album.dart
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'task_item.dart';

class SingleAlbum {
  final String id;
  final String albumName;
  final Uint8List? albumCoverImage;
  final List<TaskItem> tasks;
  final DateTime createdAt;

  SingleAlbum({
    required this.id,
    required this.albumName,
    this.albumCoverImage,
    required this.tasks,
    required this.createdAt,
  });

  // JSON変換用のメソッド
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'albumName': albumName,
      'albumCoverImage': albumCoverImage?.toList(), // Uint8List を List<int> に変換
      'tasks': tasks.map((task) => task.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // JSONからSingleAlbumを作成するメソッド
  factory SingleAlbum.fromJson(Map<String, dynamic> json) {
    return SingleAlbum(
      id: json['id'] ?? '',
      albumName: json['albumName'] ?? '',
      albumCoverImage: json['albumCoverImage'] != null 
          ? Uint8List.fromList(List<int>.from(json['albumCoverImage']))
          : null,
      tasks: (json['tasks'] as List? ?? [])
          .map((taskJson) => TaskItem.fromJson(taskJson))
          .toList(),
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  // copyWithメソッド
  SingleAlbum copyWith({
    String? id,
    String? albumName,
    Uint8List? albumCoverImage,
    List<TaskItem>? tasks,
    DateTime? createdAt,
  }) {
    return SingleAlbum(
      id: id ?? this.id,
      albumName: albumName ?? this.albumName,
      albumCoverImage: albumCoverImage ?? this.albumCoverImage,
      tasks: tasks ?? this.tasks,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}