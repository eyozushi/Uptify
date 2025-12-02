#!/bin/bash

# welcome_screen.dart
sed -i '' "s/'タップ'/'Tap'/g" lib/screens/onboarding/welcome_screen.dart
sed -i '' "s/'音楽を再生するように'/'Just like playing music'/g" lib/screens/onboarding/welcome_screen.dart
sed -i '' "s/'タスクをプレイする'/'Play Your Tasks'/g" lib/screens/onboarding/welcome_screen.dart

# artist_name_screen.dart
sed -i '' "s/'あなたのアーティスト名は？'/'What's your artist name?'/g" lib/screens/onboarding/artist_name_screen.dart
sed -i '' "s/'あなたの名前'/'Your name'/g" lib/screens/onboarding/artist_name_screen.dart
sed -i '' "s/'次へ'/'Next'/g" lib/screens/onboarding/artist_name_screen.dart
sed -i '' "s/'プロフィール写真を選択'/'Select Profile Photo'/g" lib/screens/onboarding/artist_name_screen.dart
sed -i '' "s/'どこから写真を選びますか？'/'Where would you like to choose from?'/g" lib/screens/onboarding/artist_name_screen.dart
sed -i '' "s/'キャンセル'/'Cancel'/g" lib/screens/onboarding/artist_name_screen.dart
sed -i '' "s/'カメラ'/'Camera'/g" lib/screens/onboarding/artist_name_screen.dart
sed -i '' "s/'ギャラリー'/'Gallery'/g" lib/screens/onboarding/artist_name_screen.dart
sed -i '' "s/'写真を選択しました'/'Photo selected'/g" lib/screens/onboarding/artist_name_screen.dart
sed -i '' "s/'写真の選択に失敗しました'/'Failed to select photo'/g" lib/screens/onboarding/artist_name_screen.dart
sed -i '' "s/'アーティスト名を入力してください'/'Please enter your artist name'/g" lib/screens/onboarding/artist_name_screen.dart

# dream_input_screen.dart
sed -i '' "s/'あなたの夢は？'/'What's your dream?'/g" lib/screens/onboarding/dream_input_screen.dart
sed -i '' "s/'理想像は？'/'Your ideal self?'/g" lib/screens/onboarding/dream_input_screen.dart
sed -i '' "s/'あなたの理想像'/'Your ideal self'/g" lib/screens/onboarding/dream_input_screen.dart
sed -i '' "s/'これがアルバムのタイトルになるよ'/'This will be your album title'/g" lib/screens/onboarding/dream_input_screen.dart
sed -i '' "s/'あなたの夢・理想像を入力してください'/'Please describe your dream or ideal self'/g" lib/screens/onboarding/dream_input_screen.dart

# image_selection_screen.dart
sed -i '' "s/'その理想のイメージは？'/'What does that ideal look like?'/g" lib/screens/onboarding/image_selection_screen.dart
sed -i '' "s/'選択'/'Select'/g" lib/screens/onboarding/image_selection_screen.dart
sed -i '' "s/'写真なしで次へ'/'Continue without photo'/g" lib/screens/onboarding/image_selection_screen.dart
sed -i '' "s/'理想像の写真を選択'/'Select Your Ideal Image'/g" lib/screens/onboarding/image_selection_screen.dart
sed -i '' "s|'あなたの理想像を表す写真を\\nどこから選びますか？'|'Where would you like to choose a photo that represents your ideal self?'|g" lib/screens/onboarding/image_selection_screen.dart
sed -i '' "s/'写真を削除しました'/'Photo removed'/g" lib/screens/onboarding/image_selection_screen.dart

# actions_setup_screen.dart
sed -i '' "s/'理想に近づくために今することは？'/'What will you do to reach your ideal?'/g" lib/screens/onboarding/actions_setup_screen.dart
sed -i '' "s/'行動'/'Action'/g" lib/screens/onboarding/actions_setup_screen.dart
sed -i '' "s/'任意'/'Optional'/g" lib/screens/onboarding/actions_setup_screen.dart
sed -i '' "s/'アルバムをリリースする'/'Release Your Album'/g" lib/screens/onboarding/actions_setup_screen.dart
sed -i '' "s/'例：毎朝30分読書する'/'e.g., Read for 30 minutes every morning'/g" lib/screens/onboarding/actions_setup_screen.dart
sed -i '' "s/'例：週3回運動する'/'e.g., Exercise 3 times a week'/g" lib/screens/onboarding/actions_setup_screen.dart
sed -i '' "s/'例：新しいスキルを学ぶ'/'e.g., Learn a new skill'/g" lib/screens/onboarding/actions_setup_screen.dart
sed -i '' "s/'例：人とのつながりを大切にする'/'e.g., Value connections with others'/g" lib/screens/onboarding/actions_setup_screen.dart
sed -i '' "s/'最低1つの行動を入力してください'/'Please enter at least one action'/g" lib/screens/onboarding/actions_setup_screen.dart

# completion_screen.dart
sed -i '' "s|'どんなSNSの投稿より\\n素敵なあなたに出会おう'|'Meet the best version of yourself,\\nbetter than any social media post'|g" lib/screens/onboarding/completion_screen.dart
sed -i '' "s|'今日の小さな選択が\\nあなたの未来を変える'|'Today's small choices\\nshape your future'|g" lib/screens/onboarding/completion_screen.dart
sed -i '' "s/'理想像'/'Your Ideal'/g" lib/screens/onboarding/completion_screen.dart

# onboarding_wrapper.dart
sed -i '' "s/'オンボーディングの初期化に失敗しました'/'Failed to initialize onboarding'/g" lib/screens/onboarding/onboarding_wrapper.dart
sed -i '' "s/'スキップに失敗しました'/'Failed to skip'/g" lib/screens/onboarding/onboarding_wrapper.dart
sed -i '' "s/'完了処理中にエラーが発生しました'/'An error occurred during completion'/g" lib/screens/onboarding/onboarding_wrapper.dart
sed -i '' "s/'理想の自分'/'Your Ideal Self'/g" lib/screens/onboarding/onboarding_wrapper.dart
sed -i '' "s/'あなた'/'You'/g" lib/screens/onboarding/onboarding_wrapper.dart
sed -i '' "s|'今日という日を大切に生きよう\\n一歩ずつ理想の自分に近づいていく\\n昨日の自分を超えていこう\\n今この瞬間を輝かせよう'|'Live today to the fullest\\nStep by step toward your ideal self\\nSurpass who you were yesterday\\nMake this moment shine'|g" lib/screens/onboarding/onboarding_wrapper.dart
sed -i '' "s/'の人生という音楽の主人公。毎日新しい楽曲を作り続ける唯一無二のアーティスト。時には激しく、時には優しく、常に成長を続けている。今日もまた新しいメロディーを奏でている。'/\", the protagonist of life's music. A unique artist creating new songs every day. Sometimes intense, sometimes gentle, always growing. Creating new melodies again today.\"/g" lib/screens/onboarding/onboarding_wrapper.dart
sed -i '' "s/'毎日成長する理想の自分'/'My ideal self growing every day'/g" lib/screens/onboarding/onboarding_wrapper.dart
sed -i '' "s/'オンボーディングをスキップ'/'Skip Onboarding'/g" lib/screens/onboarding/onboarding_wrapper.dart
sed -i '' "s|'セットアップをスキップして、デフォルト設定でアプリを開始しますか？\\n\\n後からいつでも設定を変更できます。'|'Skip setup and start with default settings?\\n\\nYou can change settings anytime later.'|g" lib/screens/onboarding/onboarding_wrapper.dart
sed -i '' "s/'スキップ'/'Skip'/g" lib/screens/onboarding/onboarding_wrapper.dart
sed -i '' "s/'エラーが発生しました'/'An error occurred'/g" lib/screens/onboarding/onboarding_wrapper.dart
sed -i '' "s/'再試行'/'Retry'/g" lib/screens/onboarding/onboarding_wrapper.dart

echo "✅ オンボーディング画面の英語化完了！"