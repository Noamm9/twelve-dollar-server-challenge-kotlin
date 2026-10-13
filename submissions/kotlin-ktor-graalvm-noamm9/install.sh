#!/usr/bin/env bash
set -euo pipefail

GRAALVM_URL="https://download.oracle.com/graalvm/25/archive/graalvm-jdk-25.0.4_linux-x64_bin.tar.gz"
GRAALVM_SHA256="76007c309f821aaf435bce63162ea0395587fc77350801c81643fe7feea37276"

apt-get update
apt-get install -y build-essential zlib1g-dev curl ca-certificates

curl -fsSL -o /tmp/graalvm.tar.gz "$GRAALVM_URL"
echo "$GRAALVM_SHA256  /tmp/graalvm.tar.gz" | sha256sum -c -

rm -rf /opt/graalvm
mkdir -p /opt/graalvm
tar -xzf /tmp/graalvm.tar.gz -C /opt/graalvm --strip-components=1
rm /tmp/graalvm.tar.gz
