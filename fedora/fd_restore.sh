# Polygon's Restore! :D

#!/usr/bin/env bash
set -euo pipefail

# == Set initial environment ==

# Define colors for success/fail states
RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
BLUE='\e[96m'
RESET='\e[0m'

info()    { echo -e "${BLUE}[INFO]${RESET} $*"; }
success() { echo -e "${GREEN}[OK]${RESET} $*"; }
warning() { echo -e "${YELLOW}[WARN]${RESET} $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

# SSH options
# Where to create socket
CONTROL_PATH="${HOME}/.ssh/cm_%r@%h:%p"

# SSH options to enable a master connection
SSH_OPTS=(
  -o ControlMaster=auto
  -o ControlPath="$CONTROL_PATH"
  -o ControlPersist=15m
)

# NAS info
# Set user and host
read -rp "Enter NAS username: " NAS_USER
read -rp "Enter NAS IP address: " NAS_HOST

# Set file paths
NAS_BACKUP_DIR="/volume1/Linux/Backup/Fedora"
NAS_DOWNLOAD_DIR="/Linux/Backup/Fedora"
LOCAL_DOWNLOAD_DIR="${HOME}/Downloads"

# Package files
PKGLIST_FILE="${HOME}/.pkglist.txt"
FLATPAKLIST_FILE="${HOME}/.flatpaklist.txt"


# == Begin restore ==

# 0) Establish Master ssh connection
info ":: Establishing SSH master connection..."
ssh "${SSH_OPTS[@]}" "${NAS_USER}@${NAS_HOST}" true

# 1) Find the newest backup on the NAS
info ":: Finding latest backup on NAS..."
LATEST_FILE=$(ssh "${SSH_OPTS[@]}" "${NAS_USER}@${NAS_HOST}" \
  "cd ${NAS_BACKUP_DIR} && ls -1t Fedora_Backup-*.tar.gz | head -n1")

if [[ -z "$LATEST_FILE" ]]; then
  error ":: No backups found in ${NAS_BACKUP_DIR}" >&2
  exit 1
fi
success ":: Latest backup is: ${LATEST_FILE}"

# 2) Copy it locally
info ":: Downloading ${LATEST_FILE} to ${LOCAL_DOWNLOAD_DIR}..."
mkdir -p "${LOCAL_DOWNLOAD_DIR}"
scp "${SSH_OPTS[@]}" \
    "${NAS_USER}@${NAS_HOST}:${NAS_DOWNLOAD_DIR}/${LATEST_FILE}" \
    "${LOCAL_DOWNLOAD_DIR}/${LATEST_FILE}"
BACKUP_FILE="${LOCAL_DOWNLOAD_DIR}/${LATEST_FILE}"
success ":: Downloaded as: ${BACKUP_FILE}"

# 3) Extract into $HOME, stripping top-level 'Backup/' directory
info ":: Extracting backup into your home..."
tar --strip-components=1 -xzf "${BACKUP_FILE}" -C "${HOME}"
success ":: Extraction complete"

# 4) Enable copr repos
info ":: Enabling copr repos.."
sudo dnf copr enable erikreider/SwayNotificationCenter -y
sudo dnf copr enable monkeygold/nautilus-open-any-terminal -y
sudo dnf copr enable peterwu/rendezvous -y
sudo dnf copr enable phracek/PyCharm -y
sudo dnf copr enable solopasha/hyprland -y
sudo dnf copr enable tofik/nwg-shell -y
sudo dnf copr enable sneexy/zen-browser -y

# 5) Enable RPM Fusion repos
info ":: Enabling RPM Fusion.."
sudo dnf install -y \
  https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm \
  https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-steam-$(rpm -E %fedora).rpm

# 6) Switch to official flathub
info ":: Setting up flathub"
sudo flatpak remote-delete flathub
sudo remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# 7) Install 1Password
info ":: Installing 1Password"
sudo rpm --import https://downloads.1password.com/linux/keys/1password.asc
sudo sh -c 'echo -e "[1password]\nname=1Password Stable Channel\nbaseurl=https://downloads.1password.com/linux/rpm/stable/\$basearch\nenabled=1\ngpgcheck=1\nrepo_gpgcheck=1\ngpgkey=\"https://downloads.1password.com/linux/keys/1password.asc\"" > /etc/yum.repos.d/1password.repo'
sudo dnf install -y 1password

# 8) Install Mullvad
info ":: Installing Mullvad"
sudo dnf config-manager addrepo --from-repofile=https://repository.mullvad.net/rpm/stable/mullvad.repo
sudo dnf install -y mullvad-vpn


# 9) Install packages via dnf
if [[ -f "${PKGLIST_FILE}" ]]; then
  info ":: Installing remaining packages from ${PKGLIST_FILE}..."
sudo dnf install -y $(< "$PKGLIST_FILE")
  success ":: Package installs complete"
else
  error ":: Package list ${PKGLIST_FILE} not found; skipping"
fi

# 10) Install Flatpaks
if [[ -f "${FLATPAKLIST_FILE}" ]]; then
  info ":: Installing Flatpaks from ${FLATPAKLIST_FILE}..."
  while read -r app; do
    [[ "$app" =~ ^# ]] && continue
    [[ -z "$app" ]] && continue
    sudo flatpak install -y flathub "$app" || error ":: Failed: $app"
  done < "${FLATPAKLIST_FILE}"
  success ":: Flatpak installs complete"
else
  error ":: Flatpak list ${FLATPAKLIST_FILE} not found; skipping"
fi

# 11) Install ML4W helper apps
info ":: Installing the ML4W Apps"

bash -c "$(curl -s https://raw.githubusercontent.com/mylinuxforwork/dotfiles-welcome/master/setup.sh)"
bash -c "$(curl -s https://raw.githubusercontent.com/mylinuxforwork/dotfiles-settings/master/setup.sh)"
bash -c "$(curl -s https://raw.githubusercontent.com/mylinuxforwork/dotfiles-sidebar/master/setup.sh)"
bash -c "$(curl -s https://raw.githubusercontent.com/mylinuxforwork/dotfiles-calendar/master/setup.sh)"
bash -c "$(curl -s https://raw.githubusercontent.com/mylinuxforwork/hyprland-settings/master/setup.sh)"

# 12) A little configuration for greetd
info ":: Configuring tuigreet session manager"

# 12.0.1 Make sure tuigreet is actually installed
sudo dnf install -y tuigreet

# 12.1) Copy files
sudo rm /etc/greetd/config.toml
sudo rm /etc/vconsole.conf
sudo cp $HOME/Documents/Scripts/greetd/fd-config.toml /etc/greetd/config.toml
sudo cp $HOME/Documents/Scripts/greetd/vtrgb /etc/vtrgb
sudo cp $HOME/Documents/Scripts/greetd/vconsole.conf /etc/vconsole.conf

# 12.2) Set service locations
SERVICE=greetd.service
OVERRIDE_DIR="/etc/systemd/system/${SERVICE}.d"
OVERRIDE_FILE="${OVERRIDE_DIR}/override.conf"

# 12.3) Make sure the drop-in directory exists
sudo mkdir -p "${OVERRIDE_DIR}"

# 12.4) Write the override
sudo tee "${OVERRIDE_FILE}" > /dev/null <<'EOF'
[Service]
ExecStartPre=/usr/bin/setvtrgb /etc/vtrgb
EOF

# 12.5) Reload systemd and enable the service
sudo systemctl daemon-reload
sudo systemctl enable "${SERVICE}"

success ":: Override installed for ${SERVICE} at ${OVERRIDE_FILE}"

# 13) Create NAS sync dir
mkdir -p $HOME/Mjolnir

# 14) Zen fixes
sudo mkdir /etc/1password
sudo touch /etc/1password/custom_allowed_browsers
echo "zen-bin" | sudo tee -a /etc/1password/custom_allowed_browsers

# 15) Prompt for reboot
echo
read -rp "Restore  complete. Reboot now? [y/N]: " REPLY
case "${REPLY,,}" in
  y|yes)
    info ":: Rebooting..."
    sudo reboot
    ;;
  *)
    success ":: Reboot to apply changes."
    ;;
esac

exit 0
