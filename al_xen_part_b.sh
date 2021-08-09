# Dependencies
log_alert () {
    echo "\e[1;33m[-] ALERT: $1\e[1;0m"
}
log_blue () {
    echo "\e[1;34m$1\e[1;0m"
}
log_debug () {
    echo "\e[1;36m[~] DEBUG: $1\e[1;0m"
}
log_error () {
    echo "\e[1;31m[X] ERROR: $1\e[1;0m"
}
log_info () {
    echo "\e[1;34m[*]\e[1;0m $1"
}
log_red () {
    echo "\e[1;31m$1\e[1;0m"
}
log_success () {
    echo "\e[1;32m[+] $1\e[1;0m"
}
log_yellow () {
    echo "\e[1;33m$1\e[1;0m"
}

# *****************************************************************************************************************************************************
# *****************************************************************************************************************************************************
# *****************************************************************************************************************************************************


# Enter new system chroot
log_blue "Entering new system root and synchronizing pacman..."
arch-chroot /mnt # /mnt becomes temporary root directory
pacman -Syy # Synchronize Pacman repository again

# Time
log_blue "Setting timezone and hardware clock..."
timedatectl set-timezone Europe/Berlin # Berlin timezone
hwclock --systohc --utc # Assume hardware clock is UTC

# Locale
log_blue "Initializing the locale..."
timedatectl set-ntp true # Enable NTP time synchronization again
echo "en_GB.UTF-8 UTF-8" > /etc/locale.gen # Change en-US (UTF-8) to en-GB (UTF-8)
locale-gen # Generate locale
echo LANG=en_GB.UTF-8 > /etc/locale.conf # Save locale to locale configuration
export LANG=en_GB.UTF-8 # Export LANG variable
echo KEYMAP=de-latin1 > /etc/vconsole.conf # Set keyboard layout
echo FONT=lat9w-16 >> /etc/vconsole.conf # Set console font

# Network
log_blue "Setting hostname and /etc/hosts..."
echo Workstation > /etc/hostname # Set hostname
echo "127.0.0.1 localhost" > /etc/hosts # Hosts file: Localhost (IP4)
echo "::1 localhost" >> /etc/hosts # Hosts file: Localhost (IP6)
echo "127.0.1.1 Workstation" >> /etc/hosts # Hosts file: This host (IP4)

# initramfs
log_blue "Rebuilding initramfs image using mkinitcpio..."
echo "MODULES=()" > /etc/mkinitcpio.conf
echo "BINARIES=()" >> /etc/mkinitcpio.conf
#echo "FILES=()" >> /etc/mkinitcpio.conf
echo "HOOKS=(base udev autodetect modconf block filesystems keyboard fsck encrypt lvm2)" >> /etc/mkinitcpio.conf
mkinitcpio -p linux # Rebuild initramfs image

# Users
log_blue "Adding root and home user..."
log_yellow "SET ROOT PASSWORD!"
passwd # Set root password
useradd -m -G wheel,users -s /usr/bin/zsh $USER # Add new user
log_yellow "SET HOME USER PASSWORD!"
passwd $USER # Set user password
#echo "EDITOR=nano visudo" > /etc/sudoers # ???
echo "root ALL=(ALL) ALL" > /etc/sudoers # Root account may execute any command
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers # Users of group wheel may execute any command
echo "@includedir /etc/sudoers.d" >> /etc/sudoers # ???

# Generate & integrate LUKS keyfile 
log_blue "Adding keyfile for LUKS partition..."
mkdir /root/keyfiles # Create folder to hold keyfiles
chmod 700 /root/keyfiles # Protect keyfiles folder
dd if=/dev/urandom of=/root/keyfiles/boot.keyfile bs=512 count=1 # Generate pseudorandom keyfile
sync # Assert that memory is written to disk
chmod 600 /root/keyfiles/boot.keyfile # Protect key file
cryptsetup -v luksAddKey -i 1 $LUKS /root/keyfiles/boot.keyfile # Adding keyfile as key for LUKS partition
echo "FILES=(/root/keyfiles/boot.keyfile)" >> /etc/mkinitcpio.conf # Adding keyfile as resource to iniramfs image
mkinitcpio -p linux # Recreate initramfs image

# efibootmgr & GRUB
log_blue "Installing GRUB with CRYPTODISK flag..."
pacman -S --noconfirm efibootmgr grub # Install packages required for UEFI boot
echo "GRUB_ENABLE_CRYPTODISK=y" >> /etc/default/grub # Enable booting from encrypted /boot
sed -i 's/GRUB_CMDLINE_LINUX=""/#/g' /etc/default/grub # Disable default value
echo GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=$(cryptsetup luksUUID /dev/sda2):lukslvm root=/dev/luksvg/root cryptkey=rootfs:/root/keyfiles/boot.keyfile\" >> /etc/default/grub # Add encryption hook to GRUB
grub-install --target=x86_64-efi --efi-directory=/boot/efi # Install GRUB --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg # Generate GRUB configuration file
chmod 700 /boot # Protect /boot

# Install yay for access to the AUR ecosystem
log_blue "Installing yay for access to the AUR ecosystem..."
mkdir /home/$USER/Tools
cd /home/$USER/Tools
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si --noconfirm

# Generate update script
log_blue "Generating update script..."
echo "sudo pacman -Syu --noconfirm" > /home/$USER/Tools/update.sh
echo "yay -Syu --noconfirm" > /home/$USER/Tools/update.sh

# Install required software
log_blue "Installing required software..."
pacman -S --noconfirm alsa-plugins alsa-utils gptfdisk keepass macchanger mousepad net-tools p7zip rkhunter thermald tlp unrar unzip wget zip #wget???
yay -S --noconfirm chkrootkit secure-delete xen

# Start services
log_blue "Starting system services..."
systemctl enable fstrim.timer # TRIM timer for SSDs
systemctl enable systemd-timesyncd.service # Time synchronization

# Finalization
log_blue "Sync & Exit..."
sync; exit # Synchronize and leave /mnt (temporary root directory)