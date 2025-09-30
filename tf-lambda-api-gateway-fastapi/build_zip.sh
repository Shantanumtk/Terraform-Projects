#!/bin/sh
set -eu
cd "$(dirname "$0")"

rm -rf build function.zip
python3 -m pip install -r requirements.txt -t build/python >/dev/null

# strip platform-specific binaries so Lambda uses pure-Python fallbacks
find build/python -type f \( -name '*.so' -o -name '*.dylib' -o -name '*.pyd' \) -delete

( cd build/python && zip -qr ../../function.zip . )
zip -qr function.zip app

echo "Built function.zip"
