#!/bin/sh
# Builds "Fuji Backup.app" (Apple silicon) into build/. Ad-hoc signed for use on this Mac.
set -eu
cd "$(dirname "$0")/.."

swift build -c release --arch arm64
BIN="$(swift build -c release --arch arm64 --show-bin-path)/FujiBackup"

APP="build/Fuji Backup.app"
rm -rf "$APP" build/AppIcon.iconset
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/FujiBackup"

swift scripts/make-icon.swift build/AppIcon.iconset
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Fuji Backup</string>
  <key>CFBundleDisplayName</key><string>Fuji Backup</string>
  <key>CFBundleIdentifier</key><string>local.fujibackup</string>
  <key>CFBundleExecutable</key><string>FujiBackup</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.photography</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSDocumentsFolderUsageDescription</key><string>Fuji Backup keeps your camera backups in Documents › Fuji Backups.</string>
</dict>
</plist>
EOF

codesign --force --sign - "$APP"
echo "Built $APP"
