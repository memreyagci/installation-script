#!/bin/sh

USERNAME="emre"

enable_chaoticaur_repo() {
    pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
    pacman-key --lsign-key 3056513887B78AEB
    pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
    pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
    [ -z "$(grep chaotic-aur /etc/pacman.conf)" ] && bash -c "echo -e \"\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist\" >> /etc/pacman.conf"
}

install_packages() {
    echo "Refreshing package database..\n\n"
    pacman --noconfirm -Syu > /dev/null 2>&1

    pacman --noconfirm -needed -S yay

    total=$(wc -l < ./packages.csv)
    while IFS=, read -r program repo comment
    do
		n=$((n+1))
        echo -e "($n/$total) Installing $program: $comment\n"
        case "$repo" in
            "PACMAN") pacman --noconfirm --needed -S "$program" > /dev/null 2>&1 ;;
            "AUR") su -c "yay --noconfirm --needed -S \"$program\"" emre ;;
            "PIP") pip install $program > /dev/null 2>&1 ;;
        esac
    done < ./packages.csv
}

install_dotfiles() {
    [ -d "/home/$USERNAME/.dotfiles" ] && git clone https://github.com/memreyagci/dotfiles /home/$USERNAME/.dotfiles
    cd /home/$USERNAME/.dotfiles
    su -c "stow -R $(echo $(ls -d */))" $USERNAME
}

enable_services() {
    SERVICES=(
        NetworkManager
        autorandr
        bluetooth
        cronie
        syncthing@$USERNAME
        usdisks2
    )
    systemctl enable --now $SERVICES
}

install_suckless_utilities() {
    REPOS=(
        dwm
        dwmblocks
        dmenu
        st
        slock
        )
    
    for repo in $REPOS; do
        git clone https://github.com/memreyagci/$repo /tmp/$repo
        cd /tmp/$repo
        make install
    done
}

error() {
    echo "ERROR: $1 task is failed. Exiting.." && exit
}

# Check if this script is run with root privileges:
[ $(echo $EUID) != 0 ] && echo "This script must be run as root. Exiting.." && exit

# Create user:
echo "Creating new user $USERNAME.."
useradd -m $USERNAME
echo "permit persist $USERNAME as root" > /etc/doas.conf
echo "New user $USERNAME has been created. Please set a password: "
passwd $USERNAME
echo -e "\n"

# Enable Chaotic AUR repository:
echo "Enabling Chaotic AUR repository.."
enable_chaoticaur_repo > /dev/null 2>&1 && echo -e "Chaotic AUR repository is enabled.\n" || error "Enabling Chaotic AUR repository"
enable_chaoticaur_repo && echo -e "Chaotic AUR repository is enabled.\n" || error "Enabling Chaotic AUR repository"

# Install packages
echo "Installing packages.."
install_packages && echo -e "Packages are installed.\n" || error "Installing packages"

# Install user's dotfiles:
echo "Installing dotfiles.."
install_dotfiles && echo -e "Dotfiles are installed.\n" || error "Installing dotfiles"

# Enable & start services:
echo "Enabling & starting services.."
enable_services > /dev/null 2>&1 && echo -e "Services are started & enabled.\n" || error "Starting and enabling services"

# Install suckless utilities:
echo "Installing suckless utilities.."
install_suckless_utilities > /dev/null 2>&1 && echo -e "Suckless utilities are installed.\n" || error "Installing suckless utilities"

# Setting cronjobs:
echo "Setting cronjobs.."
crontab -u $USERNAME ./files/cronjobs.txt > /dev/null 2>&1 && echo -e "Cronjobs are set.\n" || error "Setting cronjobs"

# Enable tap-to-click for touchpad:
echo "Enabling tap-to-click for touchpad.."
sudo cp ./files/40-libinput.conf /etc/X11/xorg.conf.d/ > /dev/null 2>&1 && echo -e "Tap-to-click is enabled.\n" || error "Enabling tap-to-click for touchpad"

# Change default user shell to ZSH:
echo "Changing the default shell for $USERNAME to ZSH.."
sudo usermod --shell /bin/zsh $USERNAME && echo -e "Tap-to-click is enabled.\n" || error "Changing the default shell"
