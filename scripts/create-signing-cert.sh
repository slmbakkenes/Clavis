#!/bin/bash
# Creates the self-signed code-signing certificate the Xcode project expects
# ("MyLauncher Local Signing") and installs it in the login keychain.
# Run once per machine, or again if the certificate disappears from the keychain.

set -euo pipefail

NAME="MyLauncher Local Signing"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

if security find-identity -v -p codesigning "$KEYCHAIN" | grep -q "$NAME"; then
  echo "'$NAME' already exists in the login keychain."
  exit 0
fi

cat > "$TMP/cert.cnf" <<CNF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
subjectKeyIdentifier = hash
CNF

echo "==> Generating key and certificate"
openssl req -x509 -newkey rsa:2048 -nodes -sha256 -days 3650 \
  -keyout "$TMP/key.pem" -out "$TMP/cert.pem" -config "$TMP/cert.cnf" >/dev/null 2>&1
openssl pkcs12 -export -legacy -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
  -out "$TMP/cert.p12" -passout pass:clavis -name "$NAME"

echo "==> Importing into login keychain"
security import "$TMP/cert.p12" -k "$KEYCHAIN" -P clavis \
  -T /usr/bin/codesign -T /usr/bin/security

# Trust it for code signing at the user level. macOS shows a dialog for this.
echo "==> Marking certificate as trusted for code signing"
security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$TMP/cert.pem"

# Let codesign (invoked by xcodebuild) use the key without a per-build prompt.
echo "==> Granting codesign access to the private key (asks for your login password)"
security set-key-partition-list -S apple-tool:,apple:,codesign: -s "$KEYCHAIN"

echo "==> Result"
security find-identity -v -p codesigning "$KEYCHAIN"
