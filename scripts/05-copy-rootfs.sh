#!/bin/bash
set -e

source $(dirname "$(readlink -f "$0")")/00-config.sh

# Go back to starting dir and clean up mounts on script exit
STARTING_DIR="$PWD"
function on_exit() {
	cd "$STARTING_DIR"
	sync
	umount -Rf mnt
	rm -rf mnt
}
trap on_exit EXIT

# Get loopback partitions
LODEV="$(losetup --find --show --partscan pop-os.img)"

# Mount!
info "Mounting rootfs.img"
mkdir -p mnt
mount -o loop,rw "${BUILD}/rootfs.img" mnt 2>&1| capture_and_log "mount rootfs.img"

# Rsync rootfs to mnt
info "Copying rootfs to mounted rootfs.img"
rsync -arv rootfs/ mnt/ 2>&1| capture_and_log "copy rootfs"