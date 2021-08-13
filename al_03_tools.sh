# Install yay for access to the AUR ecosystem
echo "Installing yay for access to the AUR ecosystem..."
USER=$(whoami)
mkdir /home/$USER/Tools
cd /home/$USER/Tools
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si --noconfirm

# Pacman software
TOOLS="dmidecode gparted"
for Tool in $TOOLS; do
    pacman -S --noconfirm $Tool
done

# AUR software
TOOLS="chkrootkit secure-delete xen"
for Tool in $TOOLS; do
    yay -S --noconfirm $Tool
done