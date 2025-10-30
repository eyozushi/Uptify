// models/lyric_note_item.dart
import 'package:flutter/material.dart';

/// Lyric Noteの1行分のデータモデル
/// 階層構造（親・子・孫）とチェック状態を保持する
class LyricNoteItem {
  final String id;              // 一意識別子
  final String text;            // 行のテキスト内容
  final int level;              // 階層レベル（1=親, 2=子, 3=孫）
  final bool isChecked;         // チェックボックスの状態（完了/未完了）
  final bool isCollapsed;       // 折りたたみ状態（true=折りたたみ中）
  final DateTime createdAt;     // 作成日時
  final DateTime? updatedAt;    // 更新日時

  LyricNoteItem({
  String? id,
  required this.text,
  this.level = 0,               // 🔧 変更: デフォルトは通常のノート（Level 0）
  this.isChecked = false,
  this.isCollapsed = false,
  DateTime? createdAt,
  this.updatedAt,
})  : id = id ?? 'note_${DateTime.now().millisecondsSinceEpoch}_${text.hashCode}',
      createdAt = createdAt ?? DateTime.now();

  /// JSONからLyricNoteItemを作成
  factory LyricNoteItem.fromJson(Map<String, dynamic> json) {
    return LyricNoteItem(
      id: json['id'] ?? '',
      text: json['text'] ?? '',
      level: json['level'] ?? 1,
      isChecked: json['isChecked'] ?? false,
      isCollapsed: json['isCollapsed'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
    );
  }

  /// LyricNoteItemをJSONに変換
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'level': level,
      'isChecked': isChecked,
      'isCollapsed': isCollapsed,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// コピーを作成（指定されたフィールドのみ更新）
  LyricNoteItem copyWith({
    String? id,
    String? text,
    int? level,
    bool? isChecked,
    bool? isCollapsed,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LyricNoteItem(
      id: id ?? this.id,
      text: text ?? this.text,
      level: level ?? this.level,
      isChecked: isChecked ?? this.isChecked,
      isCollapsed: isCollapsed ?? this.isCollapsed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// レベル0（通常のノート）かどうか
bool get isNormal => level == 0;

/// レベル1（親）かどうか
bool get isParent => level == 1;

/// レベル2（子）かどうか
bool get isChild => level == 2;

/// レベル3（孫）かどうか
bool get isGrandchild => level == 3;

  @override
  String toString() {
    return 'LyricNoteItem(id: $id, text: "$text", level: $level, checked: $isChecked)';
  }
}