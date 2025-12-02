import re
import glob

files = glob.glob('lib/screens/onboarding/*.dart')

for filepath in files:
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 文字列リテラル内の ' を \' に置換
    # パターン: 'で囲まれた文字列内に ' がある場合
    def escape_quotes(match):
        string_content = match.group(1)
        # 既にエスケープされていない ' のみをエスケープ
        escaped = string_content.replace("\\'", "TEMP_ESCAPED").replace("'", "\\'").replace("TEMP_ESCAPED", "\\'")
        return f"'{escaped}'"
    
    # シングルクォートで囲まれた文字列を検索して置換
    content = re.sub(r"'([^'\\]*(?:\\.[^'\\]*)*)'", escape_quotes, content)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"✓ {filepath}")

print("\n✅ 完了")