#!/usr/bin/env bash
# Creates the Android upload keystore and android/key.properties on THIS machine. Nothing is committed.
# Keep the keystore and passwords in your password manager: losing them means you cannot update the app
# (unless Play App Signing is used, which is recommended — Google then holds the app signing key).
set -euo pipefail
cd "$(dirname "$0")/.."
store="${1:-$HOME/onesource-upload-keystore.jks}"
if [ -e "$store" ]; then echo "$store already exists; not overwriting." >&2; exit 1; fi
read -rsp "Keystore password (min 6 chars): " pass; echo
keytool -genkeypair -v -keystore "$store" -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload -storepass "$pass" -keypass "$pass" \
  -dname "CN=OneSource Connect, O=OneSource, C=QA"
umask 077
cat > android/key.properties <<PROPS
storeFile=$store
storePassword=$pass
keyAlias=upload
keyPassword=$pass
PROPS
echo "Created $store and android/key.properties (git-ignored)."
echo "For CI: base64 -w0 \"$store\" > keystore.b64  and add it as the ANDROID_KEYSTORE_BASE64 secret, plus ANDROID_KEYSTORE_PASSWORD."
