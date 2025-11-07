#!/usr/bin/env bash
set -euo pipefail

red()  { printf "\033[31m%s\033[0m\n" "$*"; }
grn()  { printf "\033[32m%s\033[0m\n" "$*"; }
ylw()  { printf "\033[33m%s\033[0m\n" "$*"; }
die()  { red "FAIL: $*"; exit 1; }

ROOT="$(pwd)"
[ -f build.sh ] || die "run from AESD_Final_Project root (build.sh not found)"

grn "== Repo layout =="
[ -d buildroot ]      || die "missing buildroot/"
[ -d mnet_external ]  || die "missing mnet_external/"
[ -d mnet_external/package ] || die "missing mnet_external/package/ (should exist, can be empty)"
ylw "OK: directories look present"

grn "== Buildroot Raspberry Pi support =="
[ -f buildroot/configs/raspberrypi4_64_defconfig ] || die "no raspberrypi4_64_defconfig in buildroot/configs/"
[ -d buildroot/board/raspberrypi ]                  || die "no buildroot/board/raspberrypi directory"
ylw "OK: RPi defconfigs + board files exist"

grn "== build.sh sanity =="
grep -q 'BR2_EXTERNAL=.*mnet_external' build.sh   || die "build.sh must export BR2_EXTERNAL to mnet_external"
grep -q 'raspberrypi4_64_defconfig' build.sh      || die "build.sh must select raspberrypi4_64_defconfig"
[ -x build.sh ] || ylw "NOTE: build.sh not executable, fixing..." && chmod +x build.sh || true
ylw "OK: build.sh wired for Pi 4"

grn "== External tree files =="
CFG="mnet_external/Config.in"
DESC="mnet_external/external.desc"
MK="mnet_external/external.mk"
[ -f "$CFG" ]  || die "missing $CFG"
[ -f "$DESC" ] || die "missing $DESC"
[ -f "$MK" ]   || die "missing $MK"

# ensure no lingering AESD/QEMU refs
grep -Eiq 'aesd|assignment|qemu|base_external|shared\.sh' "$CFG" "$DESC" "$MK" && die "mnet_external files still reference AESD/QEMU/base_external/shared.sh"
grep -Eiq 'aesd|assignment|qemu|base_external|shared\.sh' -R mnet_external/package 2>/dev/null && die "mnet_external/package still has AESD/QEMU refs"

# check minimal content expectations
grep -q '^name:\s*mnet' "$DESC" || die "external.desc should be 'name: mnet'"
grep -q '^menu ' "$CFG" || die "Config.in should have a 'menu' block (minimal is fine)"
ylw "OK: external tree is clean"

grn "== Leftover course files =="
BAD=( assignment-autotest conf runqemu.sh runqemu.sh.bak runqemu.sh.bak3 save-config.sh shared.sh full-test.sh )
for f in "${BAD[@]}"; do
  [ -e "$f" ] && die "leftover course file/dir found: $f (delete it)"
done
ylw "OK: no course-only files"

grn "== Host dependencies =="
# minimal set buildroot uses frequently
REQ=( make gcc g++ pkg-config bc bison flex unzip cpio rsync file sed gawk perl python3 git wget xz tar gzip lzip )
MISS=()
for t in "${REQ[@]}"; do
  command -v "$t" >/dev/null 2>&1 || MISS+=("$t")
done
[ ${#MISS[@]} -eq 0 ] || die "missing host packages: ${MISS[*]}. On Ubuntu: sudo apt-get install -y ${MISS[*]}"

ylw "OK: host tools present"

grn "== Disk space check =="
# need ~10-20GB free
FREE_KB=$(df -Pk . | awk 'NR==2{print $4}')
FREE_GB=$(( FREE_KB / 1024 / 1024 ))
[ "$FREE_GB" -ge 10 ] || die "low disk space: ${FREE_GB}GB free (need >=10GB)"

ylw "OK: ${FREE_GB}GB free"

grn "== Internet check (for downloads) =="
if ! ping -c1 -W2 goog le.com >/dev/null 2>&1; then
  ylw "WARN: ping failed (maybe blocked). Buildroot can still work if HTTPS allowed."
else
  ylw "OK: network reachable"
fi

grn "== Write perms and path sanity =="
[ -w buildroot ] || die "no write permission in buildroot/"
[ -w . ]         || die "no write permission in repo root"
ylw "OK: permissions fine"

grn "== Final grep for forbidden strings =="
# repo-wide scan for things that should not be present anymore
if grep -RniE '(aesd-assignments|base_external|qemu|shared\.sh)' . --exclude-dir=.git 2>/dev/null; then
  die "forbidden strings found (above). clean them up."
fi
ylw "OK: no forbidden strings"

grn "All sanity checks passed ✅"

