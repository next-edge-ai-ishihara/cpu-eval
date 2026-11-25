#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: build_spike.sh <pinned-riscv-isa-sim-source> <install-prefix>" >&2
  exit 2
fi
: "${VERILATOR_INSTALL_DIR:?set VERILATOR_INSTALL_DIR to the pinned Verilator installation}"

SOURCE=$(realpath "$1")
PREFIX=$(realpath -m "$2")
BUILD_JOBS=${CPU_EVAL_BUILD_JOBS:-$(nproc)}
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PATCH1="$SCRIPT_DIR/0001-model-example-compressed-cvxif.patch"
PATCH2="$SCRIPT_DIR/0002-model-example-r4-cvxif.patch"
EXPECTED_SOURCE=880b27343fc4c9a2de3c325650f32192c158e0fc5cd1c183f914d5090dd28b93
EXPECTED_PATCH1=fd48c0835e956a74ce4aeaba9c1c16681781db9da76215b9d6949ac72f5a6448
EXPECTED_PATCH2=44fce5c91b055886b4ddfa31b33f36b3c7e2ccc51a3aafc94c0e36d893b2131f
EXPECTED_RESULT=4a154b19843de02c15981bac32218b084158d751d254023fa6e3a792585edb78

test "$(sha256sum "$SOURCE/customext/cvxif.cc" | cut -d' ' -f1)" = "$EXPECTED_SOURCE"
test "$(sha256sum "$PATCH1" | cut -d' ' -f1)" = "$EXPECTED_PATCH1"
test "$(sha256sum "$PATCH2" | cut -d' ' -f1)" = "$EXPECTED_PATCH2"

BUILD_ROOT=$(mktemp -d)
cleanup() {
  find "$BUILD_ROOT" -depth -delete
}
trap cleanup EXIT
cp -a "$SOURCE/." "$BUILD_ROOT/"
git -C "$BUILD_ROOT" apply "$PATCH1"
git -C "$BUILD_ROOT" apply "$PATCH2"
test "$(sha256sum "$BUILD_ROOT/customext/cvxif.cc" | cut -d' ' -f1)" = "$EXPECTED_RESULT"

mkdir "$BUILD_ROOT/build-cpueval"
cd "$BUILD_ROOT/build-cpueval"
# The pinned Spike sources include svdpi.h from Verilator.
export CPPFLAGS="-I$VERILATOR_INSTALL_DIR/share/verilator/include/vltstd${CPPFLAGS:+ $CPPFLAGS}"
../configure --prefix="$PREFIX"
make -j1 yaml-cpp-static
make -j"$BUILD_JOBS"
make -j"$BUILD_JOBS" install
