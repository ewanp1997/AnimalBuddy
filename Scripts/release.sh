#!/bin/bash
set -e

VERSION="${1:-$(grep -A 1 "CFBundleShortVersionString" App/Info.plist | tail -n 1 | sed 's/.*<string>\(.*\)<\/string>.*/\1/')}"

echo "🚀 Preparing release for Animal Buddy $VERSION..."

# 1. Run tests
swift test

# 2. Build and package .app & zip
./Scripts/build_app.sh

# 3. Stage and commit if there are changes
if ! git diff-index --quiet HEAD --; then
    git add -A
    git commit -m "Release $VERSION"
fi

# 4. Push main branch
git push origin main

# 5. Tag and push tag
git tag -f "$VERSION"
git push -f origin "$VERSION"

# 6. Publish / update GitHub release
ZIP_NAME="AnimalBuddy-$VERSION.zip"
if [ -f "$ZIP_NAME" ]; then
    if gh release view "$VERSION" &>/dev/null; then
        echo "Updating existing release $VERSION..."
        gh release upload "$VERSION" "$ZIP_NAME" --clobber
    else
        echo "Creating GitHub release $VERSION..."
        gh release create "$VERSION" "$ZIP_NAME" --title "Animal Buddy $VERSION" --generate-notes
    fi
fi

echo "✅ Successfully released Animal Buddy $VERSION!"
