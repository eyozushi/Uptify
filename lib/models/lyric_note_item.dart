// models/lyric_note_item.dart
import 'package:uuid/uuid.dart';

// 🔧 修正: クラスの外に定義
const _undefined = Object();

class LyricNoteItem {
  final String id;
  final String? parentId; // 親のID
  final String text;
  final int level; // 0: 通常ノート, 1: 親, 2: 子, 3: 孫
  final bool isCollapsed; // 折りたたみ状態（親のみ使用）
  final bool isCompleted; // 完了状態（デフォルト: false = 黒文字、true = 白文字）
  final DateTime createdAt;
  final DateTime updatedAt;

  LyricNoteItem({
    String? id,
    this.parentId,
    required this.text,
    this.level = 0,
    this.isCollapsed = false,
    this.isCompleted = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// JSONから変換
  factory LyricNoteItem.fromJson(Map<String, dynamic> json) {
    return LyricNoteItem(
      id: json['id'] as String? ?? const Uuid().v4(),
      parentId: json['parentId'] as String?,
      text: json['text'] as String? ?? '',
      level: json['level'] as int? ?? 0,
      isCollapsed: json['isCollapsed'] as bool? ?? false,
      isCompleted: json['isCompleted'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  /// JSONに変換
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'parentId': parentId,
      'text': text,
      'level': level,
      'isCollapsed': isCollapsed,
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// コピーを作成（一部のフィールドを変更）
  /// null を明示的に設定するには copyWith(isCollapsed: null) のように呼ぶ
  LyricNoteItem copyWith({
    String? id,
    Object? parentId = _undefined,
    String? text,
    int? level,
    Object? isCollapsed = _undefined,
    Object? isCompleted = _undefined,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LyricNoteItem(
      id: id ?? this.id,
      parentId: parentId == _undefined ? this.parentId : parentId as String?,
      text: text ?? this.text,
      level: level ?? this.level,
      isCollapsed: isCollapsed == _undefined 
          ? this.isCollapsed 
          : (isCollapsed as bool?) ?? false,
      isCompleted: isCompleted == _undefined 
          ? this.isCompleted 
          : (isCompleted as bool?) ?? false,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'LyricNoteItem(id: $id, parentId: $parentId, text: "$text", level: $level, isCollapsed: $isCollapsed, isCompleted: $isCompleted)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LyricNoteItem &&
        other.id == id &&
        other.parentId == parentId &&
        other.text == text &&
        other.level == level &&
        other.isCollapsed == isCollapsed &&
        other.isCompleted == isCompleted;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      parentId,
      text,
      level,
      isCollapsed,
      isCompleted,
    );
  }
}