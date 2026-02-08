#!/usr/bin/env bash
# ============================================================================
#  Custom Script: Dynamic Version Stamping (Date + Time)
# ============================================================================
#  Purpose : Stamps every build with a unique, chronologically sortable
#            version string in YYYY.MM.DD-HHMM format.
#  Targets : Android  →  versionName  in app/build.gradle
#            iOS      →  CFBundleShortVersionString  in Info.plist
#  Usage   : Add as a "Custom Script" step in your CI/CD workflow
#            BEFORE the build step so the native files carry the new version.
#
#  Exit Codes:
#    0 — success
#    1 — no target files found (neither Android nor iOS)
# ============================================================================

set -euo pipefail  # strict mode: fail on errors, undefined vars, pipe failures

# ─── Configuration ──────────────────────────────────────────────────────────
# Override BUILD_VERSION externally to inject a custom version if needed.
# Otherwise it defaults to current UTC date+time.
BUILD_VERSION="${BUILD_VERSION:-$(date -u +"%Y.%m.%d-%H%M")}"

# Numeric build code derived from the timestamp (YYYYMMDDHHmm) for versionCode / CFBundleVersion
BUILD_CODE="${BUILD_CODE:-$(date -u +"%Y%m%d%H%M")}"

# ─── Logging helpers ────────────────────────────────────────────────────────
info()    { echo " [VERSION] $*"; }
success() { echo "[VERSION] $*"; }
warn()    { echo " [VERSION] $*"; }
error()   { echo "[VERSION] $*" >&2; }

# ─── Resolve project root ──────────────────────────────────────────────────
# In Appcircle the workspace is $AC_REPOSITORY_DIR; fall back to script dir.
PROJECT_ROOT="${AC_REPOSITORY_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
info "Project root : $PROJECT_ROOT"
info "Build version: $BUILD_VERSION"
info "Build code   : $BUILD_CODE"
echo "──────────────────────────────────────────────────────"

UPDATED=0

# ============================================================================
#  ANDROID — update app/build.gradle
# ============================================================================
GRADLE_FILE="${PROJECT_ROOT}/android/app/build.gradle"

if [[ -f "$GRADLE_FILE" ]]; then
    info "Found Android build file: $GRADLE_FILE"

    # ── versionName ─────────────────────────────────────────────────────
    if grep -q 'versionName' "$GRADLE_FILE"; then
        sed -i.bak "s/versionName \"[^\"]*\"/versionName \"$BUILD_VERSION\"/" "$GRADLE_FILE"
        success "versionName → \"$BUILD_VERSION\""
    else
        warn "No versionName field found in build.gradle — skipping."
    fi

    # ── versionCode (bonus: auto-increment for unique uploads) ──────────
    if grep -q 'versionCode' "$GRADLE_FILE"; then
        sed -i.bak "s/versionCode [0-9]*/versionCode $BUILD_CODE/" "$GRADLE_FILE"
        success "versionCode → $BUILD_CODE"
    fi

    # Clean up sed backup files
    rm -f "${GRADLE_FILE}.bak"
    UPDATED=$((UPDATED + 1))

    # Print the updated values for CI log inspection
    echo "── Android verification ──"
    grep -n 'versionName\|versionCode' "$GRADLE_FILE" || true
    echo "──────────────────────────"
else
    warn "Android build.gradle not found at $GRADLE_FILE — skipping Android."
fi

# ============================================================================
#  iOS — update Info.plist
# ============================================================================
# Search common paths for Info.plist
IOS_PLIST=""
for candidate in \
    "${PROJECT_ROOT}/ios/${PROJECT_NAME:-$(basename "$PROJECT_ROOT")}/Info.plist" \
    "${PROJECT_ROOT}/ios/App/Info.plist" \
    "${PROJECT_ROOT}/ios/Info.plist"; do
    if [[ -f "$candidate" ]]; then
        IOS_PLIST="$candidate"
        break
    fi
done

# Fallback: find the first Info.plist under ios/
if [[ -z "$IOS_PLIST" ]] && [[ -d "${PROJECT_ROOT}/ios" ]]; then
    IOS_PLIST=$(find "${PROJECT_ROOT}/ios" -name "Info.plist" -not -path "*/Pods/*" -not -path "*/build/*" | head -1)
fi

if [[ -n "$IOS_PLIST" ]]; then
    info "Found iOS plist: $IOS_PLIST"

    # Use PlistBuddy (available on macOS and Appcircle macOS runners)
    if command -v /usr/libexec/PlistBuddy &>/dev/null; then
        # CFBundleShortVersionString = the user-visible version (e.g. 2026.02.03-1455)
        /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $BUILD_VERSION" "$IOS_PLIST"
        success "CFBundleShortVersionString (Bundle Version String) → \"$BUILD_VERSION\""

        # CFBundleVersion = the build number (numeric for TestFlight compatibility)
        /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_CODE" "$IOS_PLIST"
        success "CFBundleVersion → \"$BUILD_CODE\""
    else
        # Fallback for Linux runners: use sed
        warn "PlistBuddy not found — falling back to sed."
        sed -i.bak "/<key>CFBundleShortVersionString<\/key>/{ n; s/<string>[^<]*<\/string>/<string>$BUILD_VERSION<\/string>/; }" "$IOS_PLIST"
        sed -i.bak "/<key>CFBundleVersion<\/key>/{ n; s/<string>[^<]*<\/string>/<string>$BUILD_CODE<\/string>/; }" "$IOS_PLIST"
        rm -f "${IOS_PLIST}.bak"
        success "Updated Info.plist via sed fallback."
    fi

    UPDATED=$((UPDATED + 1))

    # Print the updated values for CI log inspection
    echo "── iOS verification ──"
    grep -A1 'CFBundleShortVersionString\|CFBundleVersion' "$IOS_PLIST" || true
    echo "──────────────────────"
else
    warn "iOS Info.plist not found — skipping iOS."
fi

# ============================================================================
#  EXPO — update app.json / app.config.js (for managed workflow)
# ============================================================================
APP_JSON="${PROJECT_ROOT}/app.json"

if [[ -f "$APP_JSON" ]]; then
    info "Found Expo app.json: $APP_JSON"

    # Check if jq is available for safe JSON manipulation
    if command -v jq &>/dev/null; then
        TEMP_JSON=$(mktemp)
        jq --arg ver "$BUILD_VERSION" --arg code "$BUILD_CODE" '
            .expo.version = $ver |
            .expo.ios.buildNumber = $code |
            .expo.android.versionCode = ($code | tonumber)
        ' "$APP_JSON" > "$TEMP_JSON" && mv "$TEMP_JSON" "$APP_JSON"
        success "app.json → version: \"$BUILD_VERSION\", buildNumber: \"$BUILD_CODE\", versionCode: $BUILD_CODE"
    else
        # Lightweight fallback using node (always available in JS CI environments)
        node -e "
            const fs = require('fs');
            const app = JSON.parse(fs.readFileSync('$APP_JSON', 'utf8'));
            if (!app.expo) app.expo = {};
            app.expo.version = '$BUILD_VERSION';
            if (!app.expo.ios) app.expo.ios = {};
            app.expo.ios.buildNumber = '$BUILD_CODE';
            if (!app.expo.android) app.expo.android = {};
            app.expo.android.versionCode = parseInt('$BUILD_CODE');
            fs.writeFileSync('$APP_JSON', JSON.stringify(app, null, 2) + '\n');
        "
        success "app.json updated via Node.js fallback."
    fi

    UPDATED=$((UPDATED + 1))

    echo "── Expo verification ──"
    cat "$APP_JSON"
    echo ""
    echo "───────────────────────"
fi

# ============================================================================
#  Summary
# ============================================================================
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║          VERSION STAMP SUMMARY                      ║"
echo "╠══════════════════════════════════════════════════════╣"
printf "║  Version : %-40s ║\n" "$BUILD_VERSION"
printf "║  Code    : %-40s ║\n" "$BUILD_CODE"
printf "║  Targets : %-40s ║\n" "$UPDATED platform(s) updated"
echo "╚══════════════════════════════════════════════════════╝"

if [[ "$UPDATED" -eq 0 ]]; then
    error "No platform files found to update. Ensure the native projects exist."
    error "For Expo managed projects, run 'npx expo prebuild' first."
    exit 1
fi

# Export for downstream CI steps (Appcircle environment variables)
export AC_BUILD_VERSION="$BUILD_VERSION"
export AC_BUILD_CODE="$BUILD_CODE"

success "Version stamping complete — build may proceed."
exit 0
