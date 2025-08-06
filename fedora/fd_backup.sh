#!/usr/bin/env bash
# == Fedora backup (current version 42)
set -euo pipefail

# 0. start in $HOME
cd "${HOME}"

# 1. get the date
DATE=$(date +%F)

# 2. dump a list of explicitly installed packages
rm -f "$HOME/.pkglist.txt"
dnf repoquery --qf '%{name}\n' --userinstalled | sort > "${HOME}/.pkglist.txt"

# 3. dump a list of all flatpak apps
rm -f "${HOME}/.flatpaklist.txt"
flatpak list --app --columns=application | sort > "${HOME}/.flatpaklist.txt"

# 4. create temp backup location
BACKUP_DIR="${HOME}/Backup"
rm -rf "${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}"

# 5. rsync home dir into backup
rsync -aAX --info=progress2 \
  --exclude 'Backup' \
  --exclude 'Mjolnir' \
  --exclude '.cache' \
  "${HOME}/" "${BACKUP_DIR}/"

# 6. ensure we’re still in $HOME
cd "${HOME}"

# 7. tar and compress the backup dir
tar -czpf "${HOME}/Fedora_Backup-${DATE}.tar.gz" -C "${HOME}" "Backup"

# 8. clean up temp backup dir
rm -rf "${BACKUP_DIR}"

echo "Backup complete: ${HOME}/Fedora_Backup-${DATE}.tar.gz"
