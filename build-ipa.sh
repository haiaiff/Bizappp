#!/bin/bash
# 在 macOS 上生成未签名 ipa（不依赖 Xcode 图形界面，也不用配证书）
# 用法：双击或在终端执行 ./build-ipa.sh
set -e

cd "$(dirname "$0")"
APP_NAME="BizApp"
IPA_NAME="${APP_NAME}-unsigned.ipa"

command -v xcodebuild >/dev/null 2>&1 || {
  echo "❌ 找不到 xcodebuild，请先安装 Xcode（App Store 免费下载）并执行："
  echo "   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  exit 1
}

echo "▶ Xcode 版本：$(xcodebuild -version | head -1)"

rm -rf build Payload "$IPA_NAME"

echo "▶ 开始编译（跳过签名）…"
xcodebuild \
  -project "${APP_NAME}.xcodeproj" \
  -scheme "${APP_NAME}" \
  -configuration Release \
  -sdk iphoneos \
  -derivedDataPath build \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGN_ENTITLEMENTS="" \
  clean build 2>&1 | tail -25

APP_PATH="build/Build/Products/Release-iphoneos/${APP_NAME}.app"
if [ ! -d "$APP_PATH" ]; then
  echo "❌ 编译失败，未找到 ${APP_PATH}"
  exit 1
fi

echo "▶ 打包成 ipa…"
mkdir -p Payload
cp -R "$APP_PATH" Payload/
zip -qry "$IPA_NAME" Payload
rm -rf Payload

echo ""
echo "✅ 完成：$(pwd)/${IPA_NAME}"
ls -lh "$IPA_NAME"
echo ""
echo "下一步：用 Sideloadly / AltStore / 爱思助手 / 企业证书 直接签这个 ipa 即可。"
