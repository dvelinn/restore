#!/bin/bash
set -euo pipefail

# start in $HOME
cd "${HOME}"

# get the date
DATE=$(date +%F)

# dump a list of all packages installed by pacman
rm $HOME/.pkglist.txt
pacman -Qqe > "${HOME}/.pkglist.txt"

# dump a list of all applications installed by Flatpak
rm $HOME/.flatpaklist.txt
flatpak list --app --columns=application | sort > "${HOME}/.flatpaklist.txt"

# create temp backup location
BACKUP_DIR="${HOME}/Backup"
rm -rf "${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}"

# rsync home dir
rsync -aAX --info=progress2 \
  --exclude 'Backup' \
  --exclude 'Mjolnir' \
  --exclude '.cache' \
  "${HOME}/" "${BACKUP_DIR}/"

# tar and compress the backup dir
tar -czpf "${HOME}/ML4W_Backup-${DATE}.tar.gz" -C "${HOME}" "Backup"

# remove temp backup dir
rm -rf "${BACKUP_DIR}"

echo "Backup complete: ${HOME}/ML4W_Backup-${DATE}.tar.gz"
