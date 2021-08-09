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

# German keyboard layout
log_blue "Loading German keyboard layout..."
loadkeys de

# Global variables
log_blue "Initializing global variables..."
DEV="/dev/sda" # Harddisk
EFI="/dev/sda1" # EFI partition
LUKS="/dev/sda2" # LUKS partition
UCODE="intel-ucode" # CPU microcode
USER="alex" # Username

# System clock
log_blue "Enable network time synchronization..."
timedatectl set-ntp true # Enable network time synchronization

# Partitioning (GPT parititon table)
log_blue "Partitioning the HDD/SSD with GPT partition layout..."
sgdisk --zap-all $DEV # Wipe verything
sgdisk --new=1:0:+512M $DEV # Create EFI partition
sgdisk --new=2:0:0 $DEV # Create LUKS partition
sgdisk --typecode=1:ef00 --typecode=2:8309 $DEV # Write partition type codes
sgdisk --change-name=1:efi-sp --change-name=2:luks $DEV # Label partitions
sgdisk --print $DEV # Print partition table

# LUKS 
log_blue "Formatting the second partition as LUKS crypto partition..."
cryptsetup luksFormat $LUKS --type luks1 -c twofish-xts-plain64 -h sha512 -s 512 # Format LUKS partition
cryptsetup luksOpen $LUKS lukslvm # Open LUKS partition

# LVM 
log_blue "Setting up LVM..."
pvcreate /dev/mapper/lukslvm # Create physical volume
vgcreate luksvg /dev/mapper/lukslvm # Create volume group
lvcreate -L 6144M luksvg -n swap # Create logical swap volume
lvcreate -l 100%FREE luksvg -n root # Create logical root volume

# Format partitions
log_blue "Formatting the partitions..."
mkfs.fat -F32 $EFI # EFI partition (FAT32)
mkfs.ext4 /dev/mapper/luksvg-root -L root # Root partition (EXT4)
mkswap /dev/mapper/luksvg-swap -L swap # Swap partition

# Mount filesystems
log_blue "Mounting filesystems..."
mkdir /mnt/boot/efi # Create folder to hold EFI files
mount $EFI /mnt/boot/efi # Mount EFI partition
mount /dev/luksvg/root /mnt # Mount root partition
swapon /dev/luksvg/swap # Activate swap partition

# Install base packages
log_blue "Bootstrapping Arch Linux into /mnt..."
pacman -Syy
pacstrap /mnt base base-devel git linux linux-firmware mkinitcpio sudo lvm2 dhcpcd wpa_supplicant nano zsh zsh-completions zsh-syntax-highlighting tilix $UCODE # Install base packages

# fstab
log_blue "Generating fstab file and setting 'noatime'..."
genfstab -U /mnt > /mnt/etc/fstab # Generate fstab file
sed -i 's/relatime/noatime/g' /mnt/etc/fstab # Replace 'relatime' with 'noatime' (Access time will not be saved in files)