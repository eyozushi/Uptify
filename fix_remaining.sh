#!/bin/bash

# actions_setup_screen.dart
sed -i '' "s/'行動/'Action/g" lib/screens/onboarding/actions_setup_screen.dart

# completion_screen.dart  
sed -i '' "s/'どんなSNSの投稿より\\\\n素敵なあなたに出会おう'/'Meet the best version of yourself,\\\\nbetter than any social media post'/g" lib/screens/onboarding/completion_screen.dart
sed -i '' "s/'今日の小さな選択が\\\\nあなたの未来を変える'/'Today\\\\'s small choices\\\\nshape your future'/g" lib/screens/onboarding/completion_screen.dart
sed -i '' "s/'タスクをプレイする'/'Play Your Tasks'/g" lib/screens/onboarding/completion_screen.dart

# dream_input_screen.dart
sed -i '' "s/'あなたの心の中にある夢を\\\\n音楽にして表現してみませんか？'/'What dream lives in your heart?\\\\nLet\\\\'s express it through music'/g" lib/screens/onboarding/dream_input_screen.dart
sed -i '' "s/'どんな未来の自分に\\\\n出会いたいですか？'/'What future version of yourself\\\\ndo you want to meet?'/g" lib/screens/onboarding/dream_input_screen.dart
sed -i '' "s/'あなたの人生という楽曲は\\\\nどんな物語を奏でたいですか？'/'What story will the song\\\\nof your life tell?'/g" lib/screens/onboarding/dream_input_screen.dart
sed -i '' "s/'理想の自分という\\\\nメロディーを聞かせてください'/'Let me hear the melody\\\\nof your ideal self'/g" lib/screens/onboarding/dream_input_screen.dart

# image_selection_screen.dart
sed -i '' "s/'あなたの理想像を表す写真を\\\\nどこから選びますか？'/'Where would you like to choose a photo\\\\nthat represents your ideal self?'/g" lib/screens/onboarding/image_selection_screen.dart

# onboarding_wrapper.dart
sed -i '' "s/'今日という日を大切に生きよう\\\\n一歩ずつ理想の自分に近づいていく\\\\n昨日の自分を超えていこう\\\\n今この瞬間を輝かせよう'/'Live today to the fullest\\\\nStep by step toward your ideal self\\\\nSurpass who you were yesterday\\\\nMake this moment shine'/g" lib/screens/onboarding/onboarding_wrapper.dart
sed -i '' "s/の人生という音楽の主人公。毎日新しい楽曲を作り続ける唯一無二のアーティスト。時には激しく、時には優しく、常に成長を続けている。今日もまた新しいメロディーを奏でている。/, the protagonist of life\\\\'s music. A unique artist creating new songs every day. Sometimes intense, sometimes gentle, always growing. Creating new melodies again today./g" lib/screens/onboarding/onboarding_wrapper.dart
sed -i '' "s/'あなたの人生という音楽の主人公。毎日新しい楽曲を作り続ける唯一無二のアーティスト。時には激しく、時には優しく、常に成長を続けている。今日もまた新しいメロディーを奏でている。'/'The protagonist of life\\\\'s music. A unique artist creating new songs every day. Sometimes intense, sometimes gentle, always growing. Creating new melodies again today.'/g" lib/screens/onboarding/onboarding_wrapper.dart
sed -i '' "s/'セットアップをスキップして、デフォルト設定でアプリを開始しますか？\\\\n\\\\n後からいつでも設定を変更できます。'/'Skip setup and start with default settings?\\\\n\\\\nYou can change settings anytime later.'/g" lib/screens/onboarding/onboarding_wrapper.dart

echo "✅ 完了"