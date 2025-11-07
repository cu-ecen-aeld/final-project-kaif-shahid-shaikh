#!/bin/bash
set -e
TOPDIR=$(dirname "$(realpath "$0")")

#Use external tree (renamed from base_external to mnet_external)
export BR2_EXTERNAL="${TOPDIR}/mnet_external"

#Configure Buildroot for Raspberry Pi 4 (64-bit) and build
make -C "${TOPDIR}/buildroot" O="${TOPDIR}/buildroot/output" raspberrypi4_64_defconfig
make -C "${TOPDIR}/buildroot" O="${TOPDIR}/buildroot/output" -j"$(nproc)"
