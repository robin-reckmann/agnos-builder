#!/usr/bin/env bash
set -e

DEFCONFIG=defconfig

# Get directories and make sure we're in the correct spot to start the build
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
TOOLS=$DIR/tools
TMP_DIR=/tmp/agnos-builder-tmp
OUTPUT_DIR=$DIR/output
BOOT_IMG=./boot.img
cd $DIR

if [[ "$(uname)" == 'Darwin' ]]; then
  BASE_VOLUME_PATH=$(echo $DIR | grep -o "^/Volumes/[^/]*" || echo "/")
  if ! diskutil info -plist $BASE_VOLUME_PATH | grep -q "<string>Case-sensitive APFS</string>"; then
    echo "---------------   macOS support   ---------------"
    echo "Ensure you are in a Case-sensitive APFS volume to build the AGNOS kernel."
    echo "https://github.com/commaai/agnos-builder?tab=readme-ov-file#macos"
    echo "-------------------------------------------------"
    exit 1
  fi
fi

# Setup kernel build container
echo "Building agnos-meta-builder docker image"
export DOCKER_BUILDKIT=1
docker build -f Dockerfile.builder -t agnos-meta-builder $DIR \
  --build-arg UNAME=$(id -nu) \
  --build-arg UID=$(id -u) \
  --build-arg GID=$(id -g)
echo "Starting agnos-meta-builder container"
CONTAINER_ID=$(docker run -d -v $DIR:$DIR -w $DIR agnos-meta-builder)

# Cleanup container on exit
trap "echo \"Cleaning up container:\"; \
docker container rm -f $CONTAINER_ID" EXIT

$DIR/tools/extract_tools.sh

build_kernel() {
  cd linux-kernel

  # Build parameters
  ARCH=$(uname -m)
  if [ "$ARCH" != "arm64" ] && [ "$ARCH" != "aarch64" ]; then
    export CROSS_COMPILE=$TOOLS/aarch64-linux-gnu-gcc/bin/aarch64-linux-gnu-
    export CC=$TOOLS/aarch64-linux-gnu-gcc/bin/aarch64-linux-gnu-gcc
    export LD=$TOOLS/aarch64-linux-gnu-gcc/bin/aarch64-linux-gnu-ld.bfd
  fi

  # Build arm64 arch
  export ARCH=arm64

  # Set ccache dir
  export CCACHE_DIR=$DIR/.ccache

  # Avoid LINUX_COMPILE_HOST to change on every run thus invalidating cache
  # https://patchwork.kernel.org/project/linux-kbuild/patch/1302015561-21047-8-git-send-email-mmarek@suse.cz/
  export KBUILD_BUILD_HOST="docker"

  # Disable all warnings
  export KCFLAGS="-w"

  # Remove old deb files
  rm linux-*.deb
  rm linux-*.buildinfo
  rm linux-*.changes

  # Load defconfig and build kernel
  echo "-- Config --"
  make $DEFCONFIG comma3.config O=out
  echo "-- Make: $(nproc --all) cores --"
  make bindeb-pkg -j$(nproc --all) O=out

  # Copy to output dir
  mkdir -p $OUTPUT_DIR
  cp linux-*.deb $OUTPUT_DIR/
}
# Run build_kernel in container
docker exec -u $(id -nu) $CONTAINER_ID bash -c "set -e; export DEFCONFIG=$DEFCONFIG DIR=$DIR TOOLS=$TOOLS TMP_DIR=$TMP_DIR OUTPUT_DIR=$OUTPUT_DIR BOOT_IMG=$BOOT_IMG; $(declare -f build_kernel); build_kernel"
