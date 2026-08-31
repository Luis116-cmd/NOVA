#!/bin/zsh
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
release_binary="$project_dir/.build/release/NOVA"
app_dir="$project_dir/outputs/NOVA.app"

cd "$project_dir"
swift build -c release
rm -rf "$app_dir"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$release_binary" "$app_dir/Contents/MacOS/NOVA"
cp "$project_dir/Sources/NOVA/Resources/NOVA-Info.plist" "$app_dir/Contents/Info.plist"
chmod +x "$app_dir/Contents/MacOS/NOVA"
xattr -cr "$app_dir"
codesign --force --deep --sign - "$app_dir"
echo "Created $app_dir"
