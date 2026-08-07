#!/bin/sh
set -e
cd "$CI_PRIMARY_REPOSITORY_PATH"
NUOVO=$((CI_BUILD_NUMBER + 100))
echo "=== BUILD NUMBER: $NUOVO ==="
python3 - "$NUOVO" << 'PY'
import re, sys
p = 'Fovea.xcodeproj/project.pbxproj'
t = open(p).read()
t, n = re.subn(r'CURRENT_PROJECT_VERSION = [0-9]+;',
               'CURRENT_PROJECT_VERSION = ' + sys.argv[1] + ';', t)
open(p, 'w').write(t)
print('sostituzioni:', n)
PY
grep CURRENT_PROJECT_VERSION Fovea.xcodeproj/project.pbxproj
