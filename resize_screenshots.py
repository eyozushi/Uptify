from PIL import Image
import os

# 入力フォルダと出力フォルダ
input_folder = "/Users/kazushiosaki/Desktop"
output_folder = "/Users/kazushiosaki/Desktop/resized_screenshots"

# 出力フォルダを作成
os.makedirs(output_folder, exist_ok=True)

# 目標サイズ (iPhone 16 Pro Max)
target_size = (1290, 2796)

# デスクトップのスクリーンショットを処理
screenshot_files = [
    "Simulator Screenshot - iPhone 16 Pro - 2025-12-09 at 17.20.05.png",
    "Simulator Screenshot - iPhone 16 Pro - 2025-12-09 at 17.21.04.png",
    "Simulator Screenshot - iPhone 16 Pro - 2025-12-09 at 17.21.34.png",
    "Simulator Screenshot - iPhone 16 Pro - 2025-12-09 at 17.22.12.png",
    "Simulator Screenshot - iPhone 16 Pro - 2025-12-09 at 17.22.46.png",
    "Simulator Screenshot - iPhone 16 Pro - 2025-12-09 at 17.23.29.png"
]

for i, filename in enumerate(screenshot_files, 1):
    input_path = os.path.join(input_folder, filename)
    if os.path.exists(input_path):
        img = Image.open(input_path)
        # リサイズ（アスペクト比維持）
        img_resized = img.resize(target_size, Image.Resampling.LANCZOS)
        # 保存
        output_path = os.path.join(output_folder, f"screenshot_{i}.png")
        img_resized.save(output_path, "PNG")
        print(f"✓ {filename} → screenshot_{i}.png ({target_size[0]}x{target_size[1]})")
    else:
        print(f"✗ {filename} が見つかりません")

print(f"\n完了！リサイズされた画像は以下に保存されました：")
print(output_folder)