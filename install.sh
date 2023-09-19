#!/usr/bin/bash

GUI=false
Internet=false
EFI=false

if [ -d "/sys/firmware/efi" ]; then
	EFI=true
	echo "EFI detected"
else
	EFI=false
	echo "BIOS detected"
fi

echo "Network Connected"
echo "Some compoments of the installation is silenced to make it easier to follow"
echo "What storage deivce do you want to install arch on?"
lsblk -o NAME,SIZE --nodeps
read Disk

echo "Paritioning"

wipefs -a /dev/$Disk
parted -s /dev/$Disk mklabel gpt 

if [ $EFI ]; then
	parted -s /dev/$Disk mkpart primary 0% 256MB 
	parted -s /dev/$Disk mkpart primary 256MB 5377MB 
	parted -s /dev/$Disk mkpart primary 5377MB 100% 

else
	parted -s /dev/$Disk mkpart primary 0% 1MB 
	parted -s /dev/$Disk set 1 bios_grub 
	parted -s /dev/$Disk mkpart primary 1MB 5049MB 
	parted -s /dev/$Disk mkpart primary 5049MB 100% 
fi

echo "Applying filesystems"

if [ $efi ]; then
	echo "y" | mkfs.fat -F 32 /dev/${Disk}1 
fi

echo "y" | mkfs.ext4 /dev/${Disk}2 
echo "y" | mkfs.ext4 /dev/${Disk}3 

echo "mounting filesystem"
mount -m /dev/${Disk}3 /mnt
mount -m /dev/${Disk}2 /mnt/home

if [ $efi ]; then
	mount -m /dev/${Disk}1 /mnt/boot
fi

echo "What type of installation do you want?"
echo "
Notice: Base includes other software used a lot in arch, it is still kept relitively minimal, read README for further details
[0]: Base + Gui + Internet
[1]: Base + Gui
[2]: Base + internet
[3]: Base
"

echo -n "Default [0]: "
read InstallationType

if [ "$InstallationType" == "" ] || [ "$InstallationType" == "0" ]; then
	echo "Selected: [0]"
	GUI=true
	Internet=true

elif [ "$InstallationType" == "1" ]; then
	echo "Selected: [1]"
	GUI=true

elif [ "$InstallationType" == "2" ]; then
	echo "Selected[2]"
	Internet=true

elif [ "$InstallationType" == "3" ]; then
	echo "Selected[3]"
fi

echo "Installing base"
pacstrap /mnt base linux linux-firmware bash-completion base-devel vim

if [ $GUI ]; then
	echo "Installing LightDM"
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
	if [ "$DE" == "" ] || [ "$DE" == "0" ]; then
		echo "installing plasma"
		pacstrap /mnt plasma

	elif [ "$DE" == "1" ]; then
		echo "installing cinnamon"
		pacstrap /mnt cinnamon

	elif [ "$DE" == "2" ]; then
		echo "installing mate"
		pacstrap /mnt mate

	elif [ "$DE" == "3" ]; then
		echo "installing xfce4"
		pacstrap /mnt xfce4

	elif [ "$DE" == "4" ]; then
		echo "installing gnome"
		pacstrap /mnt gnome
	fi

	arch-chroot /mnt systemctl enable lightdm.service
fi

if [ $Internet ]; then
	echo "Installing networkmanager"
	pacstrap /mnt firefox networkmanager
	arch-chroot /mnt systemctl enable NetworkManager
fi

echo "Generating fstab file"
genfstab -U /mnt >> /mnt/etc/fstab

echo "Doing base configuration"
echo "en_US.UTF-8 UTF-8" > /mnt/etc/locale.gen
arch-chroot /mnt locale-gen
echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf
echo "KEYMAP=us" > /mnt/etc/vconsole.conf
arch-chroot /mnt hwclock --systohc

echo "What do you want your computer's name to be?"
echo -n "Default [Arch]: "
read Arch
if [ "$Arch" == "" ]; then
	Arch="Arch"
fi

echo $Arch >> /mnt/etc/hostname

echo "What is your user's name?"
echo -n "Username: "
read Name
arch-chroot /mnt useradd -m ${Name}


echo "Enter in ${Name}'s password"
echo -n "Passowrd: "
read Password
arch-chroot /mnt chpasswd <<< "${Name}:${Password}" 

echo "Adding ${Name} to Suoders"
echo "\n${Name} ALL=(ALL:ALL): All" >> /mnt/etc/sudoers

echo "Rebuilding kernel (Reduency)"
arch-chroot /mnt mkinitcpio -P 

echo "Installing Grub"
pacstrap /mnt grub

if [ $EFI ]; then
	echo "Installing grub for EFI"
	pacstrap /mnt efibootmgr
	arch-chroot /mnt grub-install --target=x86_64-efi --bootloader-id=Arch --efi-directory=/boot
else
	echo "Installing grub for BIOS"
	arch-chroot /mnt grub-install --target=i386-pc /dev/$Disk
fi

echo "Conciguring grub"
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg 

echo "Archlinux sucessfully installed"
