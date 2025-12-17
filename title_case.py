#!/usr/bin/env python3
# title_case.py - 英語文字列をTitle Caseに一括変換

import os
import re

# Title Caseで小文字のままにする単語（冠詞・接続詞・前置詞）
LOWERCASE_WORDS = {
    'a', 'an', 'and', 'as', 'at', 'but', 'by', 'for', 'from', 'in', 
    'into', 'of', 'on', 'or', 'the', 'to', 'with', 'via', 'vs', 'per'
}

def to_title_case(text):
    """
    文字列をTitle Caseに変換
    - 最初と最後の単語は必ず大文字
    - 冠詞・接続詞・前置詞は小文字
    - その他の単語は大文字で始まる
    """
    words = text.split()
    if not words:
        return text
    
    result = []
    for i, word in enumerate(words):
        # 最初と最後の単語は必ず大文字
        if i == 0 or i == len(words) - 1:
            result.append(word.capitalize())
        # 小文字リストに含まれる単語は小文字
        elif word.lower() in LOWERCASE_WORDS:
            result.append(word.lower())
        # その他は大文字で始まる
        else:
            result.append(word.capitalize())
    
    return ' '.join(result)

# Title Case変換マッピング
title_case_conversions = {
    # UI要素
    'Settings': 'Settings',
    'Save': 'Save',
    'Delete': 'Delete',
    'Cancel': 'Cancel',
    'Close': 'Close',
    'Add': 'Add',
    'Edit': 'Edit',
    'Done': 'Done',
    'Next': 'Next',
    'Back': 'Back',
    'Reset': 'Reset',
    'Release': 'Release',
    'Clear': 'Clear',
    
    # タスク関連
    'Task': 'Task',
    'Task Complete': 'Task Complete',
    'Task Complete!': 'Task Complete!',
    'Title': 'Title',
    'Description': 'Description',
    'Duration': 'Duration',
    'Enter task title': 'Enter task title',
    'Task Settings': 'Task Settings',
    'Add Task': 'Add Task',
    'Task added': 'Task added',
    'Task deleted': 'Task deleted',
    'At least one task is required': 'At least one task is required',
    'Maximum 10 tasks allowed': 'Maximum 10 tasks allowed',
    'tasks played': 'tasks played',
    
    # 完了ダイアログ
    'Did you complete this task?': 'Did you complete this task?',
    'Not Done': 'Not Done',
    'Done!': 'Done!',
    
    # アルバム関連
    'Ideal Self': 'Ideal Self',
    'Ideal Self Image': 'Ideal Self Image',
    'Album Name': 'Album Name',
    'Album Cover': 'Album Cover',
    'Enter album name': 'Enter album name',
    'Album Settings': 'Album Settings',
    'Create Album': 'Create Album',
    'Your Albums': 'Your Albums',
    'Life Dream Album': 'Life Dream Album',
    'Single Album': 'Single Album',
    
    # 画像関連
    'Select Photo': 'Select Photo',
    'Change Photo': 'Change Photo',
    'Choose how to get photo': 'Choose how to get photo',
    'Photo selected': 'Photo selected',
    'Failed to select photo': 'Failed to select photo',
    'Photo selection cancelled': 'Photo selection cancelled',
    'Gallery': 'Gallery',
    'Camera': 'Camera',
    'No Image': 'No Image',
    'Image deleted': 'Image deleted',
    
    # プロフィール関連
    'Profile Settings': 'Profile Settings',
    'Artist Name': 'Artist Name',
    'Enter your name': 'Enter your name',
    
    # 通知関連
    'Notifications': 'Notifications',
    'Enable notifications': 'Enable notifications',
    'Notification interval': 'Notification interval',
    'Send periodic reminders to stay mindful of your actions': 'Send periodic reminders to stay mindful of your actions',
    
    # 時間関連
    'min': 'min',
    'hours': 'hours',
    'Day': 'Day',
    'days': 'days',
    
    # メッセージ
    'Settings saved': 'Settings saved',
    'Failed to save': 'Failed to save',
    'Are you sure you want to delete?': 'Are you sure you want to delete?',
    'This action cannot be undone': 'This action cannot be undone',
    'Form reset': 'Form reset',
    
    # その他
    'Version': 'Version',
    'Help & Feedback': 'Help & Feedback',
    'Privacy Policy': 'Privacy Policy',
    'Terms of Service': 'Terms of Service',
    'Coming soon': 'Coming soon',
    'Danger Zone': 'Danger Zone',
    'Delete This Album': 'Delete This Album',
    'Delete Album': 'Delete Album',
    
    # ランキング・統計
    'Top Tasks': 'Top Tasks',
    'Top Tracks': 'Top Tracks',
    'Top Albums': 'Top Albums',
    'Total Tasks Completed': 'Total Tasks Completed',
    'Your Concert': 'Your Concert',
    'New': 'New',
    'Venue': 'Venue',
    'Fan Entry': 'Fan Entry',
    'Complete tasks to allow entry': 'Complete tasks to allow entry',
    'Entering': 'Entering',
    
    # プレイバック
    'Playback': 'Playback',
    'Week': 'Week',
    'Month': 'Month',
    'Year': 'Year',
    ' data not available': ' data not available',
    'Daily Report': 'Daily Report',
    'Weekly Report': 'Weekly Report',
    'Monthly Report': 'Monthly Report',
    'Annual Report': 'Annual Report',
    'No data available': 'No data available',
    'No tasks played on this day': 'No tasks played on this day',
    
    # レポート見出し
    'Daily Take': 'Daily Take',
    'Weekly Hits': 'Weekly Hits',
    'Monthly Hits': 'Monthly Hits',
    'Annual Legacy': 'Annual Legacy',
    'Total playtime': 'Total playtime',
    'Top Albums of the Year': 'Top Albums of the Year',
    'Top Tracks of the Year': 'Top Tracks of the Year',
    'Top Tracks This Week': 'Top Tracks This Week',
    'Top Tracks This Month': 'Top Tracks This Month',
    'Top Albums This Month': 'Top Albums This Month',
    'Your Monthly Rhythm': 'Your Monthly Rhythm',
    'Daily average tasks per week': 'Daily average tasks per week',
    'Consistency Record': 'Consistency Record',
    'Streak': 'Streak',
    'Peak Month': 'Peak Month',
    
    # 曜日
    'Sun': 'Sun',
    'Mon': 'Mon',
    'Tue': 'Tue',
    'Wed': 'Wed',
    'Thu': 'Thu',
    'Fri': 'Fri',
    'Sat': 'Sat',
    
    # 挨拶
    'Good morning': 'Good Morning',
    'Hello': 'Hello',
    'Good evening': 'Good Evening',
    
    # 連続記録
    'Task Streak': 'Task Streak',
    
    # エラーメッセージ
    'Failed to load data': 'Failed to load data',
    'Failed to save record': 'Failed to save record',
    
    # 削除確認
    ' deleted': ' deleted',
    ', are you sure you want to delete?': ', are you sure you want to delete?',
    'All album data will be deleted': 'All album data will be deleted',
    'Task history will also be deleted': 'Task history will also be deleted',
    'Will be removed from home screen': 'Will be removed from home screen',
    
    # URL関連
    'Could not open': 'Could not open',
    'Error occurred while opening URL': 'Error occurred while opening URL',
    
    # その他
    'Unknown': 'Unknown',
    'times': 'times',
    'avg': 'avg',
}

def add_letter_spacing(content):
    """
    letterSpacingを追加（大きなフォントサイズのみ）
    """
    # fontSize: 32 のスタイルに letterSpacing を追加
    content = re.sub(
        r'(fontSize:\s*32,)',
        r'\1\n            letterSpacing: -0.5,',
        content
    )
    
    # fontSize: 28 のスタイルに letterSpacing を追加
    content = re.sub(
        r'(fontSize:\s*28,)',
        r'\1\n            letterSpacing: -0.5,',
        content
    )
    
    # fontSize: 24 のスタイルに letterSpacing を追加
    content = re.sub(
        r'(fontSize:\s*24,)',
        r'\1\n            letterSpacing: -0.3,',
        content
    )
    
    # fontSize: 22 のスタイルに letterSpacing を追加
    content = re.sub(
        r'(fontSize:\s*22,)',
        r'\1\n            letterSpacing: -0.3,',
        content
    )
    
    # fontSize: 20 のスタイルに letterSpacing を追加
    content = re.sub(
        r'(fontSize:\s*20,)',
        r'\1\n            letterSpacing: -0.3,',
        content
    )
    
    # fontSize: 18 のスタイルに letterSpacing を追加
    content = re.sub(
        r'(fontSize:\s*18,)',
        r'\1\n            letterSpacing: -0.2,',
        content
    )
    
    return content

def process_file(filepath):
    """ファイルを処理"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original_content = content
        changes = []
        
        # Title Case変換は既に適切なので、そのまま使用
        # letterSpacingの追加のみ実行
        content = add_letter_spacing(content)
        
        if content != original_content:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"✅ {os.path.basename(filepath)}")
            print(f"  Added letterSpacing to large font sizes")
            return True
        else:
            print(f"⏭️  {os.path.basename(filepath)} (no changes)")
            return False
            
    except Exception as e:
        print(f"❌ Error processing {filepath}: {e}")
        return False

def main():
    files = [
        # Screens
        'lib/screens/album_detail_screen.dart',
        'lib/screens/app_settings_screen.dart',
        'lib/screens/charts_screen.dart',
        'lib/screens/home_screen.dart',
        'lib/screens/playback_screen.dart',
        'lib/screens/player_screen.dart',
        'lib/screens/settings_screen.dart',
        'lib/screens/single_album_create_screen.dart',
        'lib/screens/artist_screen.dart',
        
        # Widgets
        'lib/widgets/completion_dialog.dart',
        'lib/widgets/playback/annual_report_widget.dart',
        'lib/widgets/playback/calendar_widget.dart',
        'lib/widgets/playback/daily_report_widget.dart',
        'lib/widgets/playback/monthly_report_widget.dart',
        'lib/widgets/playback/weekly_report_widget.dart',
        'lib/widgets/playback/task_history_item.dart',
    ]
    
    print("✨ Adding letterSpacing to improve typography...")
    print("=" * 60)
    
    success_count = 0
    for filepath in files:
        if os.path.exists(filepath):
            if process_file(filepath):
                success_count += 1
        else:
            print(f"⚠️  File not found: {filepath}")
    
    print("=" * 60)
    print(f"✨ Processing complete! {success_count}/{len(files)} files updated")

if __name__ == "__main__":
    main()python3 title_case.py