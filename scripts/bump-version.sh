#!/bin/bash
# Bumps the patch version in package.json and syncs it into Info.plist.
# Commits/tags are intentionally left to you.

set -e

PROJECT_DIR="macos/sol-macOS"
INFOPLIST_DIR="${PROJECT_DIR}/Info.plist"

npm --no-git-tag-version version patch

PACKAGE_VERSION=$(node -p "require('./package.json').version")

BUILD_NUMBER=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "${INFOPLIST_DIR}")
BUILD_NUMBER=$((BUILD_NUMBER + 1))

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${PACKAGE_VERSION}" "${INFOPLIST_DIR}"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${BUILD_NUMBER}" "${INFOPLIST_DIR}"

echo "Bumped to ${PACKAGE_VERSION} (build ${BUILD_NUMBER}). Review with 'git diff', then commit when ready."
