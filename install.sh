#!/usr/bin/env bash

setup() {
  if [ `whoami` != "root" ]; then
    echo "Please run this as root!"
    exit 1
  fi

  read -p "Enter device to install to: " -e -i /dev/mmcblk0 drive
  local boot_dev="$drive"p1
  local main_dev="$drive"p2

  read -p "Raspberry Pi generation: " -e -i 3 pi_generation

  echo 'Creating partitions'
  partition_drive "$drive"

  echo 'Formatting filesystems'
  format_filesystems "$boot_dev" "$main_dev"

  echo 'Mounting filesystems'
  mount_filesystems "$boot_dev" "$main_dev"

  echo 'Installing base system'
  install_base "$pi_generation"

  echo 'Chrooting into installed system to continue setup...'
  local setup_file="setup.sh"
  chroot_into_dev "$setup_file"

  if [ -f "/mnt/$setup_file" ]
  then
    echo 'ERROR: Something failed inside the chroot, not unmounting filesystems so you can investigate.'
    echo 'Make sure you unmount everything before you try to run this script again.'
  else
    echo 'Unmounting filesystems'
    unmount_filesystems
    echo 'Done! Unplug SD card.'
  fi
}

configure() {
  echo 'Installing additional packages'
  install_packages

  echo 'Clearing package tarballs'
  clean_packages

  echo 'Configuring sudo'
  set_sudoers

  echo 'Setting up udiskie'
  setup_udiskie

  echo 'Installing music player app'
  install_music_app

  rm /setup.sh
}

partition_drive() {
  local drive="$1"; shift

  # First partition, 100M in size, for the boot files and the second one for the rest of the system
  parted --script "$drive" mklabel msdos
  parted --script "$drive" mkpart primary fat32 0% 100M
  parted --script "$drive" mkpart primary ext4 100M 100%
}

format_filesystems() {
  local boot_dev="$1"; shift
  local main_dev="$1"; shift

  mkfs.vfat -F32 "$boot_dev"
  mkfs.ext4 -F "$main_dev"
}

mount_filesystems() {
  local boot_dev="$1"; shift
  local main_dev="$1"; shift

  mount "$main_dev" /mnt
  mkdir /mnt/boot
  mount "$boot_dev" /mnt/boot
}

install_base() {
  local pi_generation="$1"; shift

  if [ "$pi_generation" == "1" ]
  then
    wget http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-latest.tar.gz
  else
    wget http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-2-latest.tar.gz
  fi

  tar -xpf ArchLinuxARM-rpi-*latest.tar.gz -C /mnt
}

chroot_into_dev() {
  local setup_file="$1"; shift

  # Mount the temporary api filesystems
  mount -t proc none /mnt/proc
  mount -t sysfs none /mnt/sys
  mount -o bind /dev /mnt/dev

  # To get a working network inside the chroot we need to fix the resolv.conf file
  mv /mnt/etc/resolv.conf /mnt/etc/resolv.conf.bak
  cp /etc/resolv.conf /mnt/etc/resolv.conf

  # Allow us to execute arm executables on a x86 or x86_64 system
  cp /usr/bin/qemu-arm-static /mnt/usr/bin/

  cp $0 "/mnt/$setup_file"
  chroot /mnt "./$setup_file" chroot
}

unmount_filesystems() {
  umount /mnt/boot
  umount /mnt
}

install_packages() {
  local packages=''

  # General utilities/libraries
  packages+=' base-devel python2 flite'

  # Automatic mounting of devices is achieved with udisks2
  packages+=' udiskie'

  pacman -Sy --noconfirm --needed $packages
}

clean_packages() {
  yes | pacman -Scc
}

set_sudoers() {
  # Allows people in group wheel to run all commands, without a password
  echo '%wheel ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
}

setup_udiskie() {
  # Allow all members of the storage group to run udiskie
  cat > /etc/polkit-1/rules.d/50-udiskie.rules <<EOF
polkit.addRule(function(action, subject) {
  var YES = polkit.Result.YES;
  // NOTE: there must be a comma at the end of each line except for the last:
  var permission = {
    // required for udisks1:
    "org.freedesktop.udisks.filesystem-mount": YES,
    "org.freedesktop.udisks.luks-unlock": YES,
    "org.freedesktop.udisks.drive-eject": YES,
    "org.freedesktop.udisks.drive-detach": YES,
    // required for udisks2:
    "org.freedesktop.udisks2.filesystem-mount": YES,
    "org.freedesktop.udisks2.encrypted-unlock": YES,
    "org.freedesktop.udisks2.eject-media": YES,
    "org.freedesktop.udisks2.power-off-drive": YES,
    // required for udisks2 if using udiskie from another seat (e.g. systemd):
    "org.freedesktop.udisks2.filesystem-mount-other-seat": YES,
    "org.freedesktop.udisks2.filesystem-unmount-others": YES,
    "org.freedesktop.udisks2.encrypted-unlock-other-seat": YES,
    "org.freedesktop.udisks2.eject-media-other-seat": YES,
    "org.freedesktop.udisks2.power-off-drive-other-seat": YES
  };
  if (subject.isInGroup("storage")) {
    return permission[action.id];
  }
});
EOF

  # Add user 'alarm' to the group 'storage'
  gpasswd -a alarm storage

  # Create a systemd unit file that runs udiskie
  cat > /etc/systemd/system/udiskie.service <<EOF
[Unit]
Description=Udiskie

[Service]
ExecStart=/usr/bin/udiskie
User=alarm

[Install]
WantedBy=multi-user.target 
EOF

  # Enable the udiskie unit so it starts at boot time
  systemctl enable udiskie.service
}

install_music_app() {
  # Add user 'alarm' to the group 'gpio'
  gpasswd -a alarm gpio

  # Retrieve source code for the music player
  if [ ! -d "/home/alarm/pi-music-player" ]; then
    git clone TODO /home/alarm/pi-music-player
  fi

  # Create a systemd unit file that runs the music player 
  cat > /etc/systemd/system/pi-music-player.service <<EOF
[Unit]
Description=Pi Music Player

[Service]
WorkingDirectory=/home/alarm/pi-music-player
ExecStart=/home/alarm/pi-music-player/player.py
User=alarm

[Install]
WantedBy=multi-user.target 
EOF

  # Enable the unit so the music player starts at boot time
  systemctl enable pi-music-player.service
}

set -ex

if [ "$1" == "chroot" ]
then
  configure
else
  setup
fi