#!/bin/bash
set -e

source "$(dirname "$(readlink -f "$0")")/00-config.sh"
source "${SCRIPTS_DIR}/00-arm64-cross-compile.sh"

# Go back to starting dir on script exit
STARTING_DIR="$PWD"
function cleanup {
	cd "$STARTING_DIR"
}
trap cleanup EXIT

# Clean up old directories
rm -rf "${ROOTFS_BASE_DIR}"

info "Bootstrapping Ubuntu with $DEBOOTSTRAP"
mkdir -p cache

# This is where we actually CREATE our initial Ubuntu system.
# debootstrap will fetch all the necessary packages for a base Debian/Ubuntu system,
# and install them fresh into our new rootfs directory, which we can later chroot into.
# 
# eatmydata is just there to speed things up, as apt/dpkg LOVES to constantly fsync during
# EVERY. SINGLE. PACKAGE.
mkdir -p "${ROOTFS_BASE_DIR}"
chown root:root "${ROOTFS_BASE_DIR}"
eatmydata $DEBOOTSTRAP \
		--arch=arm64 \
		--cache-dir="${CACHE_DIR}" \
		--include apt,initramfs-tools,eatmydata \
		"${UBUNTU_CODE}" \
		"${ROOTFS_BASE_DIR}" \
		http://ports.ubuntu.com/ubuntu-ports 2>&1| capture_and_log "bootstrap ubuntu"

# Since we suppressed all fsyncs during the bootstrap, we need to do them now.
info "Syncing data to filesystem"
sync

info "Syncing common files to rootfs"
rsync -arHAX --chown root:root "${FS_COMMON_DIR}/" "${ROOTFS_BASE_DIR}/" 2>&1| capture_and_log "rsync common files"

# Create ESP dir, to be mounted later
mkdir -p "${ROOTFS_BASE_DIR}/boot/efi"

perl -p -i -e 's/root:x:/root::/' "${ROOTFS_BASE_DIR}/etc/passwd"

# In order for the system to actually boot, we need to link systemd to /init,
# which is the kernel's default path for the init program.
info "Linking systemd to init"
ln -s lib/systemd/systemd "${ROOTFS_BASE_DIR}/init"
