#!/bin/bash
# Construit l'app « Garde-fous Tabl » et la pose sur le bureau.
# Usage : scripts/garde_fous_app/construire.sh [dossier de destination]
set -euo pipefail

ICI="$(cd "$(dirname "$0")" && pwd)"
DESTINATION="${1:-$HOME/Desktop}"
NOM="Garde-fous Tabl"
TRAVAIL="$(mktemp -d)"
APP="$TRAVAIL/$NOM.app"

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -parse-as-library -O "$ICI/GardeFous.swift" -o "$APP/Contents/MacOS/$NOM"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>$NOM</string>
  <key>CFBundleIdentifier</key><string>app.tabl.garde-fous</string>
  <key>CFBundleName</key><string>$NOM</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleIconFile</key><string>icone</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# Icône : le bouclier de SF Symbols sur fond sombre.
swift "$ICI/icone.swift" "$TRAVAIL/icone.iconset" >/dev/null
iconutil -c icns "$TRAVAIL/icone.iconset" -o "$APP/Contents/Resources/icone.icns"

codesign --force --deep -s - "$APP" >/dev/null 2>&1
rm -rf "$DESTINATION/$NOM.app"
ditto "$APP" "$DESTINATION/$NOM.app"
rm -rf "$TRAVAIL"
echo "$DESTINATION/$NOM.app"
