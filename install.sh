#!/usr/bin/bash

connected = cat < /dev/null > /dev/tcp/8.8.8.8/53; echo $?

if [!ping -c 1 8.8.8.8 > /dev/nill]; then
	echo "What is your Network Name?"
	read NetworkName
	
	echo "What is your Network Password?"
	read NetworkPassword
	
	NetworkDevice = iw dev > /dev/null
	iwctl device $NetworkDevice connect $NetworkName password $NetworkPassword
fi

echo "NOTICE: Network Connected"
echo "What storage deivce do you want to install arch on?"
lsblk -o NAME,SIZE --nodeps
read Disk

partitons = ($(lsblk -o NAME "/dev/$Disk" | grep -E "${disk}[0-9]+"))

windows = false
umount /mnt
for parition in "${partitons}" do
	mount /dev/$partition /mnt
	if [-d "/mnt/windows/system32"] then
		v = true
		echo "Windows detected"
		while [ $v ] do
			echo "Do you wish to install archlinux alongside windows? "
			echo -n "[N/Y]: "
			read Input

			if [$Input == "N"] then
				echo "Will remove"
				v = false
			elif [$Input == "Y"] then
				echo "Will install alongside windows"
				windows = true
			else
				echo "Invalid input"
			fi
		done
		break
	fi
	umount /mnt
done

if ![windows] then
	parted -s /dev/$Disk mklabel gpt
	parted -s /dev/$Disk mkpart primary 0% 256MB
	mkfs.fat -F 32 /dev/{$Disk}1

	parted -s /dev/$Disk mkpart primary 257MB 5140GB
	mkfs.ext4 /dev/{$Disk}1

	parted -s /dev/$Disk mkpart primary 5398MB 100%
	mkfs.ext4 /dev/{$Disk}2
elif
	echo "No current functionality to install alongside windows"
	echo "Aborting"
	return
fi

echo "Mounting filesystem"
mount    /dev/{Disk}3 /mnt
mount -m /dev/{disk}2 /mnt/home
mount -m /dev/{disk}1 /mnt/boot


echo "What type of installation do you want?"

GUI = false
Internet = false
echo "
[0]: Base + Gui + Internet
[1]: Base + Gui
[2]: Base + internet
[3]: Base
" 
echo -n "Default [0]: "
read InstallationType

pacstrap /mnt base linux linux-firmware bash-completion base-devel

if [$InstallationType == "" || $InstallationType == 0]; then
	GUI = true
	Internet = true
elif [$InstallationType == "1"] then
	GUI = true
elif [$InstallationType == "2"] then
	Internet = true
fi

if [$GUI] then
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
	if [$DE == "0"] || [$DE == ""]; then
		pacstrap /mnt plasma
	elif [$DE == "1"]; then
		pacstrap /mnt cinnamon
	elif [$DE == "2"]; then
		pacstrap /mnt mate
	elif [$DE == "3"]; then
		pacstrap /mnt xfce4
	fi
fi

if [$Internet]; then
	pacstrap /mnt networkmanager
fi

echo "Generating fstab file"
genfstab -u /mnt >> /mnt/etc/fstab

echo "Doing base configuration"
arch-chroot /mnt /bin/bash -c "echo 'en_US.UTF-8 UTF-9' >> /etc/locale.gen"
arch-chroot /mnt /bin/bash -c "locale-gen"
arch-chroot /mnt /bin/bash -c "echo 'en_US.UTF-8' >> /etc/locale.conf"
arch-chroot /mnt /bin/bash -c "echo keymap=US >> /etc/vconsole.conf"

echo "What is your user's name?"
read Name
arch-chroot /mnt /bin/bash -c "useradd -m $Name"


echo "Enter in {$Name}'s password"
arch-chroot /mnt /bin/bash -c "passwd $Name"

if [$Network]; then
	echo "Configuring for Networking"
	arch-chroot /mnt /bin/bash -c "systemctl enable NetworkManager.service"
	if [$NetworkPassword] && [$NetworkName]; then
		arch-crhoot /mnt /bin/bash -c "
		nmcli device wifi connect $NetworkName password $NetworkPassword >> /dev/null"
	fi
	echo "Wifi sucessfully added"
fi

if [$GUI]; then
	echo "Enabling GUI"
	arch-chroot /mnt /bin/bash -c "systemctl enable Lightdm.Service"
fi

echo "$Name (ALL:ALL): All" >> /mnt/etc/sudoers

echo "Building Kernal"
arch-chroot /mnt /bin/bash -c "mkinitcpio -P"

echo "Installing Grub"
pacstrap /mnt grub

if [$efi]; then
	echo "Installing for efi"
	pacstrap /mnt efibootmgr

	grub-install --target=x86_64-efi --bootloader-id=Arch --efi-directory=
fi

echo "Archlinux sucessfully installed"
