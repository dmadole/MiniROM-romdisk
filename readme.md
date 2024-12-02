# MiniROM-romdisk

This project builds a ROM disk image for the Mini/ROM firmware for the 1802/Mini. This is a representation of an Elf/OS Type 1 disk designed to be put into a ROM for read-only use as an installation or recovery boot source. Think of it a bit like a Linux Live CD.

The image is compressed in two ways to maximize space. First, the allocation unit tails past the end-of-file are not stored in the image, only the used part of each allocation unit. Secondly, each allocation unit is compressed using ZX1 compression which is designed to be efficient on 8-bit systems. The files currently being included in the image total 31,058 bytes and would take 144KB on an Elf/OS disk. In the ROM disk image they are 22,562 bytes.

The work is done by a shell script that makes the content under the files directory into the disk image. This is done without any actual Mini/DOS code, it's all done by the shell script. The resulting image can be bundled with BIOS and the utility program into a complete ROM image using the MiniROM-image project.

Until I come up with a better way to package that part, this includes all the files actually put into the image, but of course these can be replaced to customize.

