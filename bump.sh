#!/bin/bash
ULTIMO=$(app-store-connect get-latest-testflight-build-number "$APP_STORE_APP_ID" 2>/dev/null || echo 0)
NUOVO=$(( ${ULTIMO:-0} + 1 ))
echo "=== BUILD NUMBER: $NUOVO ==="
sed -i.bak -E "s/CURRENT_PROJECT_VERSION = [0-9]+;/CURRENT_PROJECT_VERSION = $NUOVO;/g" Fovea.xcodeproj/project.pbxproj
rm -f Fovea.xcodeproj/project.pbxproj.bak
grep CURRENT_PROJECT_VERSION Fovea.xcodeproj/project.pbxproj
