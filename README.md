# Pi Music Player

Converts a Raspberry Pi into a music player. Once booted, the Pi will start playing music from the first detected USB drive (outputting to the 3.5mm audio jack).

## Features
* Supports many audio encodings ([omxplayer](https://elinux.org/Omxplayer))
* Supports playlists via directories on the USB drive
* Continues playing the previous playlist on boot
* Supports "next song" and "next playlist" button
* Uses [udiskie](https://github.com/coldfix/udiskie) to continuously mount any USB drive that is plugged in (hence, you can switch USB drives while music is playing)

## Installation

To get this running on your Raspberry Pi, follow:
1. Install the following prerequisite packages:
   `qemu`
   `qemu-user-static`
   `binfmt-support`
2. Plug in your SD card, and use `lsblk` to determine your SD card's device file (e.g. `/dev/mmcblk0`)
3. Run `curl -s 'TODO/install.sh' | sudo sh` and follow the prompts

Note: If `install.sh` exits with this error `chroot: failed to run command ‘/usr/bin/bash’: Exec format error` after attempting to chroot into the SD's mount point, you most likely need to enable ARM to x86 translation (see [here](https://github.com/RoEdAl/linux-raspberrypi-wsp/wiki/Building-ArchLinux-ARM-packages-ona-a-PC-using-QEMU-Chroot) and [here](https://wiki.archlinux.org/index.php/change_root#Using_chroot)):
`sudo update-binfmts --enable qemu-arm`

## Connecting buttons to Pi

Attach push buttons to pin 17 and 27 without and pull up/down resistors (Raspberry Pi has built-in pull-up and pull-down resistors which are be enabled in `player.py`).

## Structure for files on usb drive
```
$ tree /run/media/michael/C2EF-215F/
/run/media/michael/C2EF-215F/
├── Marathon Motivation
│   ├── Bon Jovi - Its My Life.mp3
│   ├── Eminem - Lose Yourself.mp3
│   └── Survivor - Eye Of The Tiger.mp3
└── Old Songs
    ├── Gwen Stefani - Hollaback Girl.mp3
    └── The Killers - Mr. Brightside.mp3

2 directories, 5 files
```

## Usage

Once everything is installed, just boot the Pi, plug in a USB drive and connect some speakers/headphones to the audio jack.

## Troubleshooting

### Music not playing

If you Rasp Pi has booted and no music is playing, I'd recommend checking the logs for the music player service:

```
journalctl -u pi-music-player
```

## Credits

I followed [this guide](https://disconnected.systems/blog/raspberry-pi-archlinuxarm-setup/) to create a custom Arch Linux ARM image and drew inspirational for the installation script from [this](https://github.com/tom5760/arch-install) Arch installation script.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.