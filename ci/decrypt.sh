#!/bin/bash
# 解密签名用的密钥。只需要仓库 Secret：SIGNING_PASSPHRASE。
# 加密后的密钥放在 ci/keys/（也可以用 Secrets：ASC_KEY_ENC_B64 / DIST_KEY_ENC_B64 覆盖）。
# 用法：source ci/decrypt.sh  → 设置 KEY_PATH（.p8）、DIST_KEY（发布证书私钥 .pem）、KEY_ID、ISSUER_ID、TEAM_ID、BUNDLE_ID
set -e
[ -n "$PASS" ] || { echo "缺少 Secret：SIGNING_PASSPHRASE"; exit 1; }
K="${RUNNER_TEMP:-/tmp}/keys"; mkdir -p "$K"
A="${ASC_B64:-$(cat ci/keys/asc.enc.b64)}"; D="${DIST_B64:-$(cat ci/keys/dist.enc.b64)}"
printf %s "$A" | base64 --decode > "$K/asc.enc"; printf %s "$D" | base64 --decode > "$K/dist.enc"
export KEY_ID=$(jq -r .ascKeyId app.json) ISSUER_ID=$(jq -r .ascIssuerId app.json) TEAM_ID=$(jq -r .teamId app.json) BUNDLE_ID=$(jq -r .bundleId app.json)
openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 -in "$K/asc.enc" -out "$K/AuthKey_$KEY_ID.p8" -pass env:PASS
openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 -in "$K/dist.enc" -out "$K/dist_key.pem" -pass env:PASS
export KEY_PATH="$K/AuthKey_$KEY_ID.p8" DIST_KEY="$K/dist_key.pem"
if [ -n "$GITHUB_ENV" ]; then
  { echo "KEY_PATH=$KEY_PATH"; echo "DIST_KEY=$DIST_KEY"; echo "KEY_ID=$KEY_ID"; echo "ISSUER_ID=$ISSUER_ID"; echo "TEAM_ID=$TEAM_ID"; echo "BUNDLE_ID=$BUNDLE_ID"; echo "ASC_KEY_PATH=$KEY_PATH"; echo "ASC_KEY_ID=$KEY_ID"; echo "ASC_ISSUER_ID=$ISSUER_ID"; } >> "$GITHUB_ENV"
fi
if [ -f ci/review_contact.enc ]; then
  openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 -in ci/review_contact.enc -out "$K/contact.json" -pass env:PASS && [ -n "$GITHUB_ENV" ] && echo "CONTACT_PATH=$K/contact.json" >> "$GITHUB_ENV" || true
fi
set +e
