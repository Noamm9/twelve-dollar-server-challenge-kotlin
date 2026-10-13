#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

export JAVA_HOME=/opt/graalvm
export GRAALVM_HOME=/opt/graalvm

bash ./gradlew --no-daemon clean nativeCompile
