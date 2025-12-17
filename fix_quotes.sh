#!/bin/bash

# onboardingフォルダ内の全dartファイルで、文字列内のアポストロフィをエスケープ
find lib/screens/onboarding -name "*.dart" -type f -exec sed -i '' -E "s/'([^']*)'([^']*)'/'\\1\\\\'\\2'/g" {} \;

echo "✅ アポストロフィのエスケープ完了"