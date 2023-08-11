#!/usr/bin/bash

timedatectl

if [ -d "/sys/firmware/efivars" ]; then
	efi=true
	echo "Bios detected"
fi

echo "Network Connected"
echo "What storage deivce do you want to install arch on?"
lsblk -o NAME,SIZE --nodeps
read Disk

echo "Paritioning"

wipefs -a /dev/$Disk
parted -s /dev/$Disk mklabel gpt

if $efi; then
	parted -s /dev/$Disk mkpart primary 0% 256MB
	parted -s /dev/$Disk mkpart primary 256MB 5377MB
	parted -s /dev/$Disk mkpart primary 5377MB 100%

else
	parted -s /dev/$Disk mkpart primary 0% 1MB
	parted -s /dev/$Dosl set 1 bios_grub
	parted -s /dev/$Disk mkpart primary 1MB 5041MB
	parted -s /dev/$Disk mkpart primary 5042MB 100%
fi

echo "Applying filesystems"

if [ $efi ]; then
	mkfs.fat -F 32 /dev/${Disk}1
fi

mkfs.ext4 /dev/${Disk}2
mkfs.ext4 /dev/${Disk}3

echo "mounting filesystem"
mount -m /dev/${Disk}3 /mnt
mount -m /dev/${Disk}2 /mnt/home

if [ $efi == true ]; then
	mount -m /dev/${Disk}1 /mnt/boot
fi

echo "What type of installation do you want?"
echo "
[0]: Base + Gui + Internet
[1]: Base + Gui
[2]: Base + internet
[3]: Base
"

echo -n "Default [0]: "
read InstallationType

pacstrap /mnt base linux linux-firmware bash-completion base-devel vim

if [ "$InstallationType" == "" ] || [ "$InstallationType" == "0" ]; then
	GUI=true
	Internet=true

elif [ "$InstallationType" == "1" ]; then
	GUI=true

elif [ "$InstallationType" == "2" ]; then
	Internet=true

elif [ "$InstallationType" == "3" ]; then
	GUI=false
	Internet=false
fi

if [ $GUI ]; then
	pacstrap /mnt lightdm lightdm-gtk-greeter
	echo "What Desktop Enviroment do you want?"
	echo "
[0]: KDE (plasma)
[1]: Cinnamon
[2]: Mate
[3]: Xfce4
[4]: Gnome
"
	echo -n "Default [0]: "
	read DE
	if [ $DE == "0" ] || [ "$DE" == "" ]; then
		pacstrap /mnt plasma
	elif [ $DE == "1" ]; then
		pacstrap /mnt cinnamon
	elif [ $DE == "2" ]; then
		pacstrap /mnt mate
	elif [ $DE == "3" ]; then
		pacstrap /mnt xfce4
	elif [ $DE == "4" ]; then
		pacstrap /mnt gnome
	fi
fi

if [ $Internet ]; then
	pacstrap /mnt firefox networkmanager
fi

echo "Generating fstab file"
genfstab -U /mnt >> /mnt/etc/fstab

echo "Doing base configuration"
echo "en_US.UTF-8 UTF-8" > /mnt/etc/locale.gen
arch-chroot /mnt /bin/bash -c "locale-gen"
echo "en_US.UTF-8" > /mnt/etc/locale.conf
echo "keymap=us" > /mnt/etc/vconsole.conf
arch-chroot /mnt /bin/bash -c "hwclock --systohc"

echo "What do you want your computer's name to be?"
echo -n "Default [Arch]: "
read Arch
if [ $Arch == "" ]; then
	Arch="Arch"
fi

echo $Arch >> /mnt/etc/hostname

echo "What is your user's name?"
echo -n "Username: "
read Name
arch-chroot /mnt /bin/bash -c "useradd -m $Name"


echo "Enter in ${Name}'s password"
echo -n "Passowrd: "
read Password

arch-chroot /mnt /bin/bash -c "echo -e "$Password\n$Password" | passwd $Name"

if [ $Network ]; then
	echo "Configuring for Networking"
	arch-chroot /mnt /bin/bash -c "systemctl enable NetworkManager.service"
fi


if [ $GUI ]; then
	echo "Enabling GUI"
	arch-chroot /mnt /bin/bash -c "systemctl enable lightdm.service"
fi

echo "$Name ALL=(ALL:ALL): All" >> /mnt/etc/sudoers

echo "Building Kernal"
arch-chroot /mnt /bin/bash -c "mkinitcpio -P"

echo "Installing Grub"
pacstrap /mnt grub

if [ $efi == true ]; then
	echo "Installing grub for efi"
	pacstrap /mnt efibootmgr
	arch-chroot /mnt grub-install --target=x86_64-efi --bootloader-id=Arch --efi-directory=/boot
	arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
else
	echo "Installing grub for bios"
	arch-chroot /mnt grub-install --target=i386-pc /dev/$Disk
fi

echo "Archlinux sucessfully installed"
