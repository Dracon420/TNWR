#!/bin/sh
# Packages the unsigned iPhone build as build/ipa/TNWR.ipa for AltStore/SideStore,
# which sign it with the tester's own Apple ID. See docs/BETA_INSTALL.md.
set -e
cd "$(dirname "$0")/.."
flutter build ios --release --no-codesign
rm -rf build/ipa
mkdir -p build/ipa/Payload
cp -R build/ios/iphoneos/Runner.app build/ipa/Payload/
(cd build/ipa && zip -qry TNWR.ipa Payload && rm -rf Payload)
echo "Built build/ipa/TNWR.ipa"
