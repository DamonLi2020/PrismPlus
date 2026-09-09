#!/bin/bash

set -euo pipefail

readonly SCRIPT_DIRECTORY="$(cd "$(dirname "$0")" && pwd)"
readonly PROJECT_DIRECTORY="$(cd "$SCRIPT_DIRECTORY/.." && pwd)"
readonly VERSION="${VERSION:-0.1.0}"
readonly TECTONIC_SOURCE="${TECTONIC_PATH:-/opt/homebrew/bin/tectonic}"
readonly HOMEBREW="${HOMEBREW_PATH:-/opt/homebrew/bin/brew}"
readonly DERIVED_DATA_DIRECTORY="$PROJECT_DIRECTORY/build/PrototypeDerivedData"
readonly DIST_DIRECTORY="$PROJECT_DIRECTORY/dist"
readonly STAGING_DIRECTORY="$DIST_DIRECTORY/PrismPlus-${VERSION}-arm64"
readonly APP_SOURCE="$DERIVED_DATA_DIRECTORY/Build/Products/Release/PrismPlus.app"
readonly APP_DESTINATION="$STAGING_DIRECTORY/Prism Plus.app"
readonly FRAMEWORKS_DIRECTORY="$APP_DESTINATION/Contents/Frameworks"
readonly RESOURCES_DIRECTORY="$APP_DESTINATION/Contents/Resources"
readonly BUNDLED_TECTONIC="$APP_DESTINATION/Contents/MacOS/tectonic"
readonly DMG_PATH="$DIST_DIRECTORY/PrismPlus-${VERSION}-arm64.dmg"
readonly ZIP_PATH="$DIST_DIRECTORY/PrismPlus-${VERSION}-arm64.zip"
readonly SEEN_DEPENDENCIES="$(mktemp)"

cleanup() {
    rm -f "$SEEN_DEPENDENCIES"
}
trap cleanup EXIT

fail() {
    echo "error: $*" >&2
    exit 1
}

command -v xcodegen >/dev/null || fail "Install XcodeGen before packaging."
[[ -x "$TECTONIC_SOURCE" ]] || fail "Tectonic was not found at $TECTONIC_SOURCE."
[[ -x "$HOMEBREW" ]] || fail "Homebrew is required to collect bundled runtime licenses."
[[ "$(uname -m)" == "arm64" ]] || fail "This prototype packager currently targets Apple silicon."
file "$TECTONIC_SOURCE" | grep -q "arm64" || fail "The selected Tectonic executable is not arm64."

echo "Generating the Xcode project..."
cd "$PROJECT_DIRECTORY"
xcodegen generate

echo "Building Prism Plus ${VERSION} for Apple silicon..."
xcodebuild build \
    -project PrismPlus.xcodeproj \
    -scheme PrismPlus \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$DERIVED_DATA_DIRECTORY" \
    ARCHS=arm64 \
    ONLY_ACTIVE_ARCH=YES \
    CODE_SIGNING_ALLOWED=NO

[[ -d "$APP_SOURCE" ]] || fail "Xcode did not produce $APP_SOURCE."

rm -rf "$STAGING_DIRECTORY"
mkdir -p "$STAGING_DIRECTORY" "$FRAMEWORKS_DIRECTORY" "$RESOURCES_DIRECTORY/Licenses"
ditto "$APP_SOURCE" "$APP_DESTINATION"
install -m 755 "$TECTONIC_SOURCE" "$BUNDLED_TECTONIC"

bundle_dependency() {
    local source_path="$1"
    local destination_path="$2"
    local destination_kind="$3"
    local dependency
    local resolved_dependency
    local bundled_dependency
    local replacement

    source_path="$(realpath "$source_path")"
    if grep -Fqx "$source_path" "$SEEN_DEPENDENCIES"; then
        return
    fi
    printf '%s\n' "$source_path" >> "$SEEN_DEPENDENCIES"

    while IFS= read -r dependency; do
        resolved_dependency=""
        case "$dependency" in
            /opt/homebrew/*|/usr/local/*)
                resolved_dependency="$(realpath "$dependency")"
                ;;
            @loader_path/*)
                resolved_dependency="$(dirname "$source_path")/${dependency#@loader_path/}"
                [[ -f "$resolved_dependency" ]] || continue
                resolved_dependency="$(realpath "$resolved_dependency")"
                ;;
            *)
                continue
                ;;
        esac

        bundled_dependency="$FRAMEWORKS_DIRECTORY/$(basename "$resolved_dependency")"
        if [[ ! -f "$bundled_dependency" ]]; then
            install -m 755 "$resolved_dependency" "$bundled_dependency"
        fi

        if [[ "$destination_kind" == "executable" ]]; then
            replacement="@loader_path/../Frameworks/$(basename "$resolved_dependency")"
        else
            replacement="@loader_path/$(basename "$resolved_dependency")"
        fi
        if [[ "$dependency" != "$replacement" ]]; then
            install_name_tool -change "$dependency" "$replacement" "$destination_path"
        fi

        bundle_dependency "$resolved_dependency" "$bundled_dependency" "library"
    done < <(otool -L "$source_path" | tail -n +2 | awk '{print $1}')

    if [[ "$destination_kind" == "library" ]]; then
        install_name_tool -id "@loader_path/$(basename "$destination_path")" "$destination_path"
    fi
}

echo "Bundling Tectonic and its runtime libraries..."
bundle_dependency "$TECTONIC_SOURCE" "$BUNDLED_TECTONIC" "executable"

copy_formula_license() {
    local formula="$1"
    local source_name="$2"
    local destination_name="$3"
    local prefix

    prefix="$($HOMEBREW --prefix "$formula")"
    [[ -f "$prefix/$source_name" ]] \
        || fail "Could not find the $formula license at $prefix/$source_name."
    cp "$prefix/$source_name" "$RESOURCES_DIRECTORY/Licenses/$destination_name"
}

cp "$PROJECT_DIRECTORY/THIRD_PARTY_NOTICES.md" "$RESOURCES_DIRECTORY/THIRD_PARTY_NOTICES.md"
copy_formula_license tectonic LICENSE Tectonic-LICENSE.txt
copy_formula_license freetype LICENSE.TXT FreeType-LICENSE.txt
copy_formula_license graphite2 LICENSE Graphite2-LICENSE.txt
copy_formula_license graphite2 COPYING Graphite2-COPYING.txt
copy_formula_license harfbuzz COPYING HarfBuzz-COPYING.txt
copy_formula_license icu4c@78 LICENSE ICU-LICENSE.txt
copy_formula_license libpng LICENSE libpng-LICENSE.txt
copy_formula_license glib LGPL-2.1-or-later.txt GLib-LGPL-2.1-or-later.txt
copy_formula_license gettext COPYING gettext-COPYING.txt
copy_formula_license pcre2 COPYING PCRE2-COPYING.txt

if find "$APP_DESTINATION/Contents/MacOS" "$FRAMEWORKS_DIRECTORY" -type f -print0 \
    | xargs -0 otool -L 2>/dev/null \
    | grep -E '/opt/homebrew|/usr/local/(Cellar|opt)' >/dev/null; then
    fail "The packaged app still contains machine-specific Homebrew library references."
fi

echo "Ad-hoc signing the prototype..."
find "$FRAMEWORKS_DIRECTORY" -type f -name '*.dylib' -print0 \
    | xargs -0 -n 1 codesign --force --sign - --timestamp=none
codesign --force --sign - --timestamp=none "$BUNDLED_TECTONIC"
codesign --force --sign - --timestamp=none "$APP_DESTINATION"
codesign --verify --deep --strict --verbose=2 "$APP_DESTINATION"

echo "Smoke-testing the bundled compiler..."
"$BUNDLED_TECTONIC" --version

cp "$PROJECT_DIRECTORY/Packaging/README-FIRST.txt" "$STAGING_DIRECTORY/README-FIRST.txt"
cp "$PROJECT_DIRECTORY/Packaging/FRIEND-FEEDBACK.md" "$STAGING_DIRECTORY/FRIEND-FEEDBACK.md"
ln -s /Applications "$STAGING_DIRECTORY/Applications"

rm -f "$DMG_PATH" "$ZIP_PATH"
hdiutil create \
    -volname "Prism Plus Prototype" \
    -srcfolder "$STAGING_DIRECTORY" \
    -ov \
    -format UDZO \
    "$DMG_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_DESTINATION" "$ZIP_PATH"

shasum -a 256 "$DMG_PATH" "$ZIP_PATH" > "$DIST_DIRECTORY/SHA256SUMS.txt"

echo
echo "Prototype package ready:"
echo "  $DMG_PATH"
echo "  $ZIP_PATH"
echo "  $DIST_DIRECTORY/SHA256SUMS.txt"
