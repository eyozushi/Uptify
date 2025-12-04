#!/usr/bin/env python3
# translate.py - 日本語UI文字列を英語に一括変換（ウィジェット対応版）

import os
import re

# 翻訳マッピング
translations = {
    # UI要素
    '設定': 'Settings',
    '保存': 'Save',
    '削除': 'Delete',
    'キャンセル': 'Cancel',
    '閉じる': 'Close',
    '追加': 'Add',
    '編集': 'Edit',
    '完了': 'Done',
    '次へ': 'Next',
    '戻る': 'Back',
    'リセット': 'Reset',
    'リリース': 'Release',
    'クリア': 'Clear',
    
    # タスク関連
    'タスク': 'Task',
    'タスク完了': 'Task Complete',
    'タスク完了！': 'Task Complete!',
    'タイトル': 'Title',
    '説明': 'Description',
    '再生時間': 'Duration',
    'タスクのタイトルを入力': 'Enter task title',
    'タスク設定': 'Task Settings',
    'タスク追加': 'Add Task',
    'タスクを追加しました': 'Task added',
    'タスクを削除しました': 'Task deleted',
    'タスクは最低1つ必要です': 'At least one task is required',
    'タスクは最大10個までです': 'Maximum 10 tasks allowed',
    'タスクを再生': 'tasks played',
    
    # 完了ダイアログ
    'このタスクはできましたか？': 'Did you complete this task?',
    'できなかった': 'Not Done',
    'できた！': 'Done!',
    '実行時間': 'Duration',
    
    # アルバム関連
    '理想像': 'Ideal Self',
    '理想像の画像': 'Ideal Self Image',
    'アルバム名': 'Album Name',
    'アルバムカバー': 'Album Cover',
    'アルバム名を入力': 'Enter album name',
    'アルバム設定': 'Album Settings',
    'アルバム作成': 'Create Album',
    'あなたのアルバム': 'Your Albums',
    'ライフドリームアルバム': 'Life Dream Album',
    'シングルアルバム': 'Single Album',
    
    # 画像関連
    '写真を選択': 'Select Photo',
    '写真を変更': 'Change Photo',
    '写真の取得方法を選択してください': 'Choose how to get photo',
    '写真を選択しました': 'Photo selected',
    '写真の選択に失敗しました': 'Failed to select photo',
    '写真の選択がキャンセルされました': 'Photo selection cancelled',
    'ギャラリー': 'Gallery',
    'カメラ': 'Camera',
    '画像なし': 'No Image',
    '画像を削除しました': 'Image deleted',
    
    # プロフィール関連
    'プロフィール設定': 'Profile Settings',
    'アーティスト名': 'Artist Name',
    'あなたの名前を入力': 'Enter your name',
    
    # 通知関連
    '通知設定': 'Notifications',
    '通知を有効にする': 'Enable notifications',
    '通知間隔': 'Notification interval',
    '定期的に行動を意識させる通知を送信します': 'Send periodic reminders to stay mindful of your actions',
    
    # 時間関連
    '分': 'min',
    '1分': '1min',
    '3分': '3min',
    '5分': '5min',
    '15分': '15min',
    '30分': '30min',
    '60分': '60min',
    '時間': 'hours',
    '日': 'Day',
    '日目': 'days',
    
    # メッセージ
    '設定を保存しました': 'Settings saved',
    '保存に失敗しました': 'Failed to save',
    '削除してもよろしいですか？': 'Are you sure you want to delete?',
    'この操作は取り消せません': 'This action cannot be undone',
    'フォームをリセットしました': 'Form reset',
    
    # その他
    'バージョン情報': 'Version',
    'ヘルプとフィードバック': 'Help & Feedback',
    'プライバシーポリシー': 'Privacy Policy',
    '利用規約': 'Terms of Service',
    '準備中です': 'Coming soon',
    '危険な操作': 'Danger Zone',
    'このアルバムを削除': 'Delete This Album',
    'アルバムを削除': 'Delete Album',
    
    # ランキング・統計
    'トップタスク': 'Top Tasks',
    'トップヒット曲': 'Top Tracks',
    'トップアルバム': 'Top Albums',
    '総タスク完了数': 'Total Tasks Completed',
    'あなたのコンサート': 'Your Concert',
    '新規': 'New',
    '会場': 'Venue',
    'ファン入場': 'Fan Entry',
    'タスク完了で入場可能': 'Complete tasks to allow entry',
    '入場中': 'Entering',
    
    # プレイバック
    'プレイバック': 'Playback',
    '週': 'Week',
    '月': 'Month',
    '年': 'Year',
    'のデータがありません': ' data not available',
    'デイリーレポート': 'Daily Report',
    'ウィークリーレポート': 'Weekly Report',
    'マンスリーレポート': 'Monthly Report',
    'アニュアルレポート': 'Annual Report',
    'データがありません': 'No data available',
    'この日はタスクを再生していません': 'No tasks played on this day',
    
    # レポート見出し
    'Daily Take': 'Daily Take',
    'Weekly Hits': 'Weekly Hits',
    'Monthly Hits': 'Monthly Hits',
    'Annual Legacy': 'Annual Legacy',
    '総再生時間': 'Total playtime',
    '年間トップアルバム': 'Top Albums of the Year',
    '年間トップヒット曲': 'Top Tracks of the Year',
    '今週のトップヒット曲': 'Top Tracks This Week',
    '今月のトップヒット曲': 'Top Tracks This Month',
    '今月のトップアルバム': 'Top Albums This Month',
    '今月の努力のリズム': 'Your Monthly Rhythm',
    '週ごとの1日平均タスク数': 'Daily average tasks per week',
    '継続性の記録': 'Consistency Record',
    '連続達成': 'Streak',
    'ピーク月': 'Peak Month',
    
    # 曜日
    '日': 'Sun',
    '月': 'Mon',
    '火': 'Tue',
    '水': 'Wed',
    '木': 'Thu',
    '金': 'Fri',
    '土': 'Sat',
    
    # 挨拶
    'おはよう': 'Good morning',
    'こんにちは': 'Hello',
    'こんばんは': 'Good evening',
    
    # 連続記録
    '連続タスク実行': 'Task Streak',
    
    # エラーメッセージ
    'データの読み込みに失敗しました': 'Failed to load data',
    '記録の保存に失敗しました': 'Failed to save record',
    
    # 削除確認
    'を削除しました': ' deleted',
    'を削除してもよろしいですか？': ', are you sure you want to delete?',
    'アルバムの全データが削除されます': 'All album data will be deleted',
    'タスク履歴も削除されます': 'Task history will also be deleted',
    'ホーム画面から消えます': 'Will be removed from home screen',
    
    # URL関連
    'を開けませんでした': 'Could not open',
    'URL起動時にエラーが発生しました': 'Error occurred while opening URL',
    
    # その他
    '不明': 'Unknown',
    '回': 'times',
    '平均': 'avg',
}

def translate_file(filepath):
    """ファイル内の日本語文字列を英語に変換"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original_content = content
        changes = []
        
        for jp, en in translations.items():
            # シングルクォート内の文字列を検索・置換
            pattern1 = f"'{re.escape(jp)}'"
            replacement1 = f"'{en}'"
            if re.search(pattern1, content):
                content = re.sub(pattern1, replacement1, content)
                changes.append(f"  '{jp}' → '{en}'")
            
            # ダブルクォート内の文字列を検索・置換
            pattern2 = f'"{re.escape(jp)}"'
            replacement2 = f'"{en}"'
            if re.search(pattern2, content):
                content = re.sub(pattern2, replacement2, content)
                changes.append(f'  "{jp}" → "{en}"')
        
        # 「タスク1」「タスク2」などの動的な文字列を変換
        content = re.sub(r"'タスク\$\{([^}]+)\}'", r"'Task ${\1}'", content)
        content = re.sub(r"'タスク\$\{_tasks\.length \+ 1\}'", r"'Task ${_tasks.length + 1}'", content)
        
        # 「${duration}分」を「${duration}min」に変換
        content = re.sub(r"'\$\{duration\}分'", r"'${duration}min'", content)
        content = re.sub(r'"\$\{duration\}分"', r'"${duration}min"', content)
        
        # 「${count}回」を「${count} times」に変換
        content = re.sub(r"'\$\{count\}回'", r"'${count} times'", content)
        content = re.sub(r'"\$\{count\}回"', r'"${count} times"', content)
        
        # 「${totalTasks} タスクを再生」を「${totalTasks} tasks played」に変換
        content = re.sub(r"'\$\{totalTasks\} タスクを再生'", r"'${totalTasks} tasks played'", content)
        
        # 「${hours}時間${minutes}分」を「${hours}h ${minutes}min」に変換
        content = re.sub(r"'\$\{hours\}時間\$\{minutes\}分'", r"'${hours}h ${minutes}min'", content)
        
        # 「${maxStreakDays}日」を「${maxStreakDays} days」に変換
        content = re.sub(r"'\$\{maxStreakDays\}日'", r"'${maxStreakDays} days'", content)
        
        # 「${month}月」を「${month}」に変換（月表示は数字のみ）
        content = re.sub(r"'\$\{month\}月'", r"'Month ${month}'", content)
        
        # 変更があった場合のみファイルを更新
        if content != original_content:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"✅ {os.path.basename(filepath)}")
            if changes:
                for change in changes[:5]:
                    print(change)
                if len(changes) > 5:
                    print(f"  ... and {len(changes) - 5} more changes")
            return True
        else:
            print(f"⏭️  {os.path.basename(filepath)} (no changes)")
            return False
            
    except Exception as e:
        print(f"❌ Error processing {filepath}: {e}")
        return False

def main():
    # 対象ファイルのリスト
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
    
    print("🌍 Starting translation process...")
    print("=" * 60)
    
    success_count = 0
    for filepath in files:
        if os.path.exists(filepath):
            if translate_file(filepath):
                success_count += 1
        else:
            print(f"⚠️  File not found: {filepath}")
    
    print("=" * 60)
    print(f"✨ Translation complete! {success_count}/{len(files)} files updated")

if __name__ == "__main__":
    main()