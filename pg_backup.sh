# Polygon's Backup! :D

#!/usr/bin/env bash
set -euo pipefail

# 0. start in $HOME
cd "${HOME}"

# 1. get the date
DATE=$(date +%F)

# 2. dump a list of all packages installed by pacman
rm $HOME/.pkglist.txt
pacman -Qqe > "${HOME}/.pkglist.txt"

# 3. dump a list of all applications installed by Flatpak
rm $HOME/.flatpaklist.txt
flatpak list --app --columns=application | sort > "${HOME}/.flatpaklist.txt"

# 4. create temp backup location
BACKUP_DIR="${HOME}/Backup"
rm -rf "${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}"

# 5. rsync home dir
rsync -aAX --info=progress2 \
  --exclude 'Backup' \
  --exclude 'Mjolnir' \
  --exclude '.cache' \
  "${HOME}/" "${BACKUP_DIR}/"

# 6. make sure we're still in $HOME
cd "${HOME}"

# 7. tar and compress the backup dir
tar -czpf "${HOME}/ML4W_Backup-${DATE}.tar.gz" -C "${HOME}" "Backup"

# 8. remove temp backup dir
rm -rf "${BACKUP_DIR}"

echo "Backup complete: ${HOME}/ML4W_Backup-${DATE}.tar.gz"
