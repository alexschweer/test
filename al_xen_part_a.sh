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