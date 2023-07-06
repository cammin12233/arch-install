#!/usr/bin/bash

timedatectl

echo "Network Connected"
echo "What storage deivce do you want to install arch on?"
lsblk -o NAME,SIZE --nodeps
read Disk

partitions=($(lsblk -o NAME /dev/$Disk | grep -E "{$Disk}[0-9]+"))

windows=false

if [ true ] then
	Var=Var+2048
	parted -s /dev/$Disk mklabel gpt
	parted -s /dev/$Disk mkpart primary fat32 0%	256MB
	parted -s /dev/$Disk mkpart primary ext4 257MB 5377MB
	parted -s /dev/$Disk mkpart primary ext4 5378MB 100%
	
	echo "mounting filesystem"
	mount -m /dev/${Disk}3 /mnt
	mount -m /dev/${Disk}2 /mnt/home
	mount -m /dev/${Disk}1 /mnt/boot
else
	echo "No current functionality to install alongside windows"
	echo "Aborting"
	return
fi

echo "What type of installation do you want?"
GUI=false
Internet=false
echo "
[0]: Base + Gui + Internet
[1]: Base + Gui
[2]: Base + internet
[3]: Base
" 
echo -n "Default [0]: "
read InstallationType

pacstrap /mnt base linux linux-firmware bash-completion base-devel

if [ $InstallationType == "" ] || [ $InstallationType == 0 ] then
	GUI=true
	Internet=true

elif [ $InstallationType == "1" ] then
	GUI=true

elif [ $InstallationType == "2" ] then
	Internet=true
fi

if [ $GUI ] then
	pacstrap /mnt lightdm lightdm-gtk-greeter
	echo "What Desktop Enviroment do you want?"
	echo "
[0]: KDE (plasma)
[1]: Cinnamon
[2]: Mate
[3]: Xfce4
"
	echo -n "Default [0]: "
	read DE
	if [ $DE == "0" ] || [ $DE == "" ] then
		pacstrap /mnt plasma
	elif [ $DE == "1" ] then
		pacstrap /mnt cinnamon
	elif [ $DE == "2" ] then
		pacstrap /mnt mate
	elif [ $DE == "3" ]; then
		pacstrap /mnt xfce4
	fi
fi

if [ $Internet ] then
	pacstrap /mnt networkmanager firefox
fi

echo "Generating fstab file"
genfstab -u /mnt >> /mnt/etc/fstab

echo "Doing base configuration"
echo "en_US.UTF-8 UTF-8" >> /mnt/etc/locale.gen
arch-chroot /mnt /bin/bash -c "locale-gen"
echo "en_US.UTF-8" >> /mnt/etc/locale.conf
echo "keymap=US" >> /mnt/etc/vconsole.conf
arch-chroot /mnt /bin/bash -c "hwclock --systohc"

echo "What do you want your computer's name to be?"
echo -n "Default [Arch]: "
read Arch
if [ $Arch == ""] then
	Arch = "Arch"
fi

echo $Arch >> /mnt/etc/hostname

echo "What is your user's name?"
read Name
arch-chroot /mnt /bin/bash -c "useradd -m $Name"


echo "Enter in {$Name}'s password"
arch-chroot /mnt /bin/bash -c "passwd $Name"

if [ $Network ] then
	echo "Configuring for Networking"
	arch-chroot /mnt /bin/bash -c "systemctl enable NetworkManager.service"
	if [$NetworkPassword] && [$NetworkName] then
		arch-crhoot /mnt /bin/bash -c "nmcli device wifi connect $NetworkName password $NetworkPassword >> /dev/null"
	fi
	echo "Wifi sucessfully added"
fi


if [ $GUI ] then
	echo "Enabling GUI"
	arch-chroot /mnt /bin/bash -c "systemctl enable Lightdm.Service"
fi

echo "$Name (ALL:ALL): All" >> /mnt/etc/sudoers

echo "Building Kernal"
arch-chroot /mnt /bin/bash -c "mkinitcpio -P"

echo "Installing Grub"
pacstrap /mnt grub

echo "Installing grub for efi"
pacstrap /mnt efibootmgr

grub-install --target=x86_64-efi --bootloader-id=Arch --efi-directory=/boot

echo "Archlinux sucessfully installed"
