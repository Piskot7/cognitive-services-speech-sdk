#!/bin/bash
set -x -e -o pipefail
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
SOURCE_ROOT="$SCRIPT_DIR/../.."

USAGE="Usage: $0 [--smoke-test] image-tag release-drop"
SMOKE_TEST=0
if [[ $1 == --smoke-test ]]; then
  SMOKE_TEST=1
  shift
fi
IMAGE_TAG="${1?$USAGE}"
RELEASE_DROP="${2?$USAGE}"
[[ -f $RELEASE_DROP ]]

[[ -z $SPEECH_SUBSCRIPTION_KEY ]] && {
  echo Environment variable SPEECH_SUBSCRIPTION_KEY not set.
  exit 1
}

# Build OOBE image

TEST_DIR="$(mktemp --directory --tmpdir="$SCRIPT_DIR" oobetest-XXXXXX)"
trap '[[ -d $TEST_DIR ]] &&  rm -rf $TEST_DIR' EXIT

mkdir "$TEST_DIR/speechsdk"
tar -xzf "$RELEASE_DROP" --strip-components=1 -C "$TEST_DIR/speechsdk"
cp -av "$SOURCE_ROOT/public_samples/quickstart/cpp-linux" "$TEST_DIR"
cp -p "$SCRIPT_DIR/../run-with-pulseaudio.sh" "$TEST_DIR/cpp-linux"
cp -p "$SOURCE_ROOT/tests/input/audio/whatstheweatherlike.wav" "$TEST_DIR/cpp-linux"

perl -i -pe 's(SPEECHSDK_ROOT:=.*)(SPEECHSDK_ROOT:=/test/speechsdk)' "$TEST_DIR/cpp-linux/Makefile"
perl -i -pe 's(L"YourSubscriptionKey")(L"'$SPEECH_SUBSCRIPTION_KEY'")' "$TEST_DIR/cpp-linux/"*.cpp
perl -i -pe 's(L"YourServiceRegion")(L"westus")' "$TEST_DIR/cpp-linux/"*.cpp

if [[ $SMOKE_TEST == 1 ]]; then
  docker run --rm --volume "$(readlink -f "$TEST_DIR"):/test" --workdir /test/cpp-linux "$IMAGE_TAG" bash -c 'make && LD_LIBRARY_PATH=/test/speechsdk/lib/x64 ./run-with-pulseaudio.sh whatstheweatherlike.wav ./helloworld'
else
  docker run --rm --volume "$(readlink -f "$TEST_DIR"):/test" --workdir /test/cpp-linux "$IMAGE_TAG" make
fi
