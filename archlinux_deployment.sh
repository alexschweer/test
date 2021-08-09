# TODO: Configure ZShell / zsh
# TODO: Install Xfce, Gnome, whatever, ...
# TODO: Automated updates
# TODO: No logs
# TODO: Security (AV, Firewall, Monitoring, etc.)

# German keyboard layout
loadkeys de

# Global variables
DEV="/dev/sda" # Harddisk
EFI="/dev/sda1" # EFI partition
LUKS="/dev/sda2" # LUKS partition
UCODE="intel-ucode" # CPU microcode
USER="alex" # Username

# System clock
timedatectl set-ntp true # Enable network time synchronization

# Partitioning (GPT parititon table)
sgdisk --zap-all $DEV # Wipe verything
sgdisk --new=1:0:+512M $DEV # Create EFI partition
sgdisk --new=2:0:0 $DEV # Create LUKS partition
sgdisk --typecode=1:ef00 --typecode=2:8309 $DEV # Write partition type codes
sgdisk --change-name=1:efi-sp --change-name=2:luks $DEV # Label partitions
sgdisk --print $DEV # Print partition table

# LUKS 
cryptsetup luksFormat $LUKS --type luks1 -c twofish-xts-plain64 -h sha512 -s 512 # Format LUKS partition
cryptsetup luksOpen $LUKS lukslvm # Open LUKS partition

# LVM 
pvcreate /dev/mapper/lukslvm # Create physical volume
vgcreate luksvg /dev/mapper/lukslvm # Create volume group
lvcreate -L 6144M luksvg -n swap # Create logical swap volume
lvcreate -l 100%FREE luksvg -n root # Create logical root volume

# Format partitions
mkfs.fat -F32 $EFI # EFI partition (FAT32)
mkfs.ext4 /dev/mapper/luksvg-root -L root # Root partition (EXT4)
mkswap /dev/mapper/luksvg-swap -L swap # Swap partition

# Mount filesystems
mkdir /mnt/boot/efi # Create folder to hold EFI files
mount $EFI /mnt/boot/efi # Mount EFI partition
mount /dev/luksvg/root /mnt # Mount root partition
swapon /dev/luksvg/swap # Activate swap partition

# Install base packages
pacman -Syy
pacstrap /mnt base base-devel git linux linux-firmware mkinitcpio sudo lvm2 dhcpcd wpa_supplicant nano zsh zsh-completions zsh-syntax-highlighting tilix $UCODE # Install base packages

# fstab
genfstab -U /mnt > /mnt/etc/fstab # Generate fstab file
sed -i 's/relatime/noatime/g' /mnt/etc/fstab # Replace 'relatime' with 'noatime' (Access time will not be saved in files)

# Enter new system chroot
arch-chroot /mnt # /mnt becomes temporary root directory
pacman -Syy # Synchronize Pacman repository again

# Time
timedatectl set-timezone Europe/Berlin # Berlin timezone
hwclock --systohc --utc # Assume hardware clock is UTC

# Locale
timedatectl set-ntp true # Enable NTP time synchronization again
echo "en_GB.UTF-8 UTF-8" > /etc/locale.gen # Change en-US (UTF-8) to en-GB (UTF-8)
locale-gen # Generate locale
echo LANG=en_GB.UTF-8 > /etc/locale.conf # Save locale to locale configuration
export LANG=en_GB.UTF-8 # Export LANG variable
echo KEYMAP=de-latin1 > /etc/vconsole.conf # Set keyboard layout
echo FONT=lat9w-16 >> /etc/vconsole.conf # Set console font

# Network
echo Workstation > /etc/hostname # Set hostname
echo "127.0.0.1 localhost" > /etc/hosts # Hosts file: Localhost (IP4)
echo "::1 localhost" >> /etc/hosts # Hosts file: Localhost (IP6)
echo "127.0.1.1 Workstation" >> /etc/hosts # Hosts file: This host (IP4)

# initramfs
echo "MODULES=()" > /etc/mkinitcpio.conf
echo "BINARIES=()" >> /etc/mkinitcpio.conf
#echo "FILES=()" >> /etc/mkinitcpio.conf
echo "HOOKS=(base udev autodetect modconf block filesystems keyboard fsck encrypt lvm2)" >> /etc/mkinitcpio.conf
mkinitcpio -p linux # Rebuild initramfs image

# Users
passwd # Set root password
useradd -m -G wheel,users -s /usr/bin/zsh $USER # Add new user
passwd $USER # Set user password
#echo "EDITOR=nano visudo" > /etc/sudoers # ???
echo "root ALL=(ALL) ALL" > /etc/sudoers # Root account may execute any command
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers # Users of group wheel may execute any command
echo "@includedir /etc/sudoers.d" >> /etc/sudoers # ???

# Generate & integrate LUKS keyfile 
mkdir /root/keyfiles # Create folder to hold keyfiles
chmod 700 /root/keyfiles # Protect keyfiles folder
dd if=/dev/urandom of=/root/keyfiles/boot.keyfile bs=512 count=1 # Generate pseudorandom keyfile
sync # Assert that memory is written to disk
chmod 600 /root/keyfiles/boot.keyfile # Protect key file
cryptsetup -v luksAddKey -i 1 $LUKS /root/keyfiles/boot.keyfile # Adding keyfile as key for LUKS partition
echo "FILES=(/root/keyfiles/boot.keyfile)" >> /etc/mkinitcpio.conf # Adding keyfile as resource to iniramfs image
mkinitcpio -p linux # Recreate initramfs image

# efibootmgr & GRUB
pacman -S --noconfirm efibootmgr grub # Install packages required for UEFI boot
echo "GRUB_ENABLE_CRYPTODISK=y" >> /etc/default/grub # Enable booting from encrypted /boot
sed -i 's/GRUB_CMDLINE_LINUX=""/#/g' /etc/default/grub # Disable default value
echo GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=$(cryptsetup luksUUID /dev/sda2):lukslvm root=/dev/luksvg/root cryptkey=rootfs:/root/keyfiles/boot.keyfile\" >> /etc/default/grub # Add encryption hook to GRUB
grub-install --target=x86_64-efi --efi-directory=/boot/efi # Install GRUB --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg # Generate GRUB configuration file
chmod 700 /boot # Protect /boot

# Install yay for access to the AUR ecosystem
mkdir /home/$USER/Tools
cd /home/$USER/Tools
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si --noconfirm

# Generate update script
echo "sudo pacman -Syu --noconfirm" > /home/$USER/Tools/update.sh
echo "yay -Syu --noconfirm" > /home/$USER/Tools/update.sh

# Install required software
pacman -S --noconfirm alsa-plugins alsa-utils net-tools p7zip rkhunter thermald tlp unrar unzip zip
yay -S --noconfirm chkrootkit secure-delete xen
#???: mousepad networkmanager parted vscodium-bin xxd
#UPROBABLY YES: gnupg gnupg2 gparted hexedit keepass macchanger mlocate netdiscover sgdisk virtualbox wireshark
#PROBABLY YES/NO: firefox ipython3 nmap python3 python3-pip wormhole openssh openvpn
#PROBABLY NO: audacity cheese chromium ffmpeg gimp inkscape kdenlive libreoffice okular picard simple-scan vlc wine PDFVIEWER IMAGEVIEWER
#DEFINITELY NO: sqlitebrowser teamviewer thunderbird
#HW & Base: cmake dbus dmidecode gdisk lshw

# Start services
systemctl enable fstrim.timer # TRIM timer for SSDs
systemctl enable systemd-timesyncd.service # Time synchronization

# Finalization
sync; exit # Synchronize and leave /mnt (temporary root directory)
sync; reboot # Synchronize and reboot

# ***NOTES***
# Do not allow SSH root access
# EDR - Firewall - SIEM/SOC
# SELinux - AppArmor - ... - ???
# Periodical checks (file integrity, rkhunter, chkrootkit, ...)
# No automount, noatime, "forensic" mode
# No logs BUT security logs
# No open ports
# Virtual Proxies ???
# Nested Virtualization with Plausible Deniability
# No internet access for dom0 ???
# Use of covert channels
# Neue MAC-Adresse bei jedem Neustart ???
# Neuen Hostnamen bei jedem Neustart ???
# Permit SSH Root Access
# Control Startup Applications