#!/usr/bin/env python3
# translate.py - 日本語UI文字列を英語に一括変換

import os
import re

# 翻訳マッピング
translations = {
    # ... 既存の翻訳 ...
    
    # 習慣改善メッセージ
    '今、何をしていますか？': 'What are you doing right now?',
    'この5分間で何を達成しましたか？': 'What did you accomplish in the last 5 minutes?',
    'スマホを見る時間、タスクに使いませんか？': 'Use phone time for tasks instead?',
    '今の行動は、本当に必要ですか？': 'Is this action really necessary?',
    '今この瞬間、何に集中していますか？': 'What are you focusing on right now?',
    '理想の自分に近づいていますか？': 'Are you moving toward your ideal self?',
    '今日のタスク、進んでいますか？': 'Making progress on today\'s tasks?',
    'アルバムの次のトラックを再生しましょう': 'Let\'s play the next track',
    '夢に近づく行動を始めませんか？': 'Start actions toward your dreams?',
    'この15分を、どう使いますか？': 'How will you use these 15 minutes?',
    '限られた時間、大切に使いましょう': 'Use your limited time wisely',
    '今の時間の使い方、満足ですか？': 'Satisfied with how you\'re using time?',
    '時間は戻らない。今を活かしましょう': 'Time won\'t come back. Make the most of now',
    'SNSをやめて、タスクを始めませんか？': 'Stop social media, start tasks?',
    'だらだらタイム、終了しませんか？': 'End the idle time?',
    'スクロールより、成長を選びませんか？': 'Choose growth over scrolling?',
    '習慣を変える瞬間は、今です': 'Now is the moment to change habits',
    '小さな一歩が、大きな変化を生みます': 'Small steps create big changes',
    '行動した分だけ、未来が変わります': 'Your future changes with each action',
    'あなたならできる。始めてみましょう': 'You can do it. Let\'s start',
    
    # 睡眠メッセージ
    'Time to put your phone away and rest ': 'Time to put your phone away and rest 🌙',
    'Good morning! Ready to conquer today? ': 'Good morning! Ready to conquer today? ☀️',
}


def translate_file(filepath):
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original = content
        changes = []
        
        for jp, en in translations.items():
            # シングルクォート
            pattern1 = f"'{re.escape(jp)}'"
            if re.search(pattern1, content):
                content = re.sub(pattern1, f"'{en}'", content)
                changes.append(f"'{jp}' → '{en}'")
            
            # ダブルクォート
            pattern2 = f'"{re.escape(jp)}"'
            if re.search(pattern2, content):
                content = re.sub(pattern2, f'"{en}"', content)
                changes.append(f'"{jp}" → "{en}"')
        
        # 動的文字列の変換
        content = re.sub(r"'「\$\{([^}]+)\}」", r"'\"${\1}\"", content)
        content = re.sub(r'"「\$\{([^}]+)\}」', r'"\"${\1}\"', content)
        
        if content != original:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"✅ {os.path.basename(filepath)}")
            for change in changes[:10]:
                print(f"  {change}")
            if len(changes) > 10:
                print(f"  ... and {len(changes) - 10} more")
            return True
        return False
            
    except Exception as e:
        print(f"❌ {filepath}: {e}")
        return False

def main():
    files = [
        'lib/main_wrapper.dart',
        'lib/screens/home_screen.dart',
        'lib/screens/player_screen.dart',
        'lib/screens/album_detail_screen.dart',
        'lib/screens/settings_screen.dart',
        'lib/screens/charts_screen.dart',
        'lib/screens/playback_screen.dart',
        'lib/screens/single_album_create_screen.dart',
        'lib/widgets/completion_dialog.dart',
        'lib/widgets/album_completion_dialog.dart',
        'lib/models/notification_config.dart',
    ]
    
    print("🌍 Starting translation...")
    print("=" * 60)
    count = sum(translate_file(f) for f in files if os.path.exists(f))
    print("=" * 60)
    print(f"✨ Done! {count} files updated")

if __name__ == "__main__":
    main()