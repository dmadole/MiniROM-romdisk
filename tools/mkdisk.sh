#!/bin/bash

# Read hex bytes on input, output binary characters

hexout () {
  while read line
  do
    for byte in $line
    do
      echo -n -e "\x$byte"
    done
  done
}

# Get size of file in bytes

fsize () {
  stat -c %s $1
}

# Get next available allocation unit on Elf/OS image

getau () {
  echo $((`fsize image/2`/2-256))
}

# Output a value as a binary byte

bbyte () {
  lsb=`printf %x $1`
  echo -e -n "\\x$lsb"
}

# Output word value as two binary bytes

bword () {
  msb=`printf %x $(($1/256))`
  lsb=`printf %x $(($1%256))`
  echo -e -n "\\x$msb\\x$lsb"
}

# Allocate next AU on Elf/OS image and set value

addau () {
  bword $1 >> image/2
}

# Output number of zero bytes

zeros () {
  dd if=/dev/zero bs=1 count=$1 status=none
}

# Ones

ones () {
  zeros $1 | tr '\0' '\377'
}

# Output date of a file in Elf/OS packed format

edate () {
  read year month day hour minute second \
    <<< `date -r $1 '+%-Y %-m %-d %-H %-M %-S'`
  bword $((($year-1972)*512+$month*32+$day))
  bword $(($hour*2048+$minute*32+$second/2))
}

# Add a file to the Elf/OS disk image

addfile () {
  if [ -d $1 ]
  then
    flags=1
    set - $1/... $2

  elif [ -z "${1##./files/bin/*}" ]
  then
    flags=2

  elif [ -x $1 ]
  then
    flags=2

  else
    flags=0
  fi

  size=`fsize $1`
  au=`getau`
  start=$au
  offset=0

  # Output in AU chunks and add to LAT

  while [ $size -ge 4096 ]
  do
    dd if=$1 of=image/$au bs=4096 count=1 skip=$offset status=none

    size=$(($size-4096))
    offset=$(($offset+1))
    au=$(($au+1))

    addau $au
  done

  # Final fraction of AU and EOF LAT

  dd if=$1 of=image/$au bs=4096 count=1 skip=$offset status=none
  addau 65278

  # Output 32-byte directory entry

  bword 0
  bword $start
  bword $size
  bbyte $flags
  edate $1
  zeros 1
  echo -n -e $2
  zeros $((20-${#2}))
}


echo
echo Removing any prior files

find ./files -name '...' -delete
rm -rf image romdisk.img /tmp/au.zx1 /tmp/disk.zx1
mkdir -p image


echo Creating allocation table

zeros 1 > image/1
zeros 512 > image/2

addau 65535
addau 65535
addau 65535


echo Adding files to image

find ./files -depth -mindepth 1 ! -name '!.*' |
while read path
do
  addfile $path ${path##*/} >> ${path%/*}/...
done


echo Creating system sector

hexout << END >> image/0
90 B2 B6 BD 30 09 93 30 01 FC 01 BB F8 2C AB F8
F4 AD F8 00 A2 22 AF F8 03 BF F8 E0 B8 F8 23 A6
C0 FF 3F D4 01 B3 F8 80 A9 D4 01 BE 3A 39 9C B7
8C A7 D4 01 E5 97 A9 32 7A D4 01 E1 9B BA 8B 38
B4 AA 9F BB 8F AB D4 FF 3C 9B BF F8 10 A6 ED 1B
1B 4B 3A 57 0B 32 64 8B FC 09 AB 8D B6 4B 32 7C
F7 1D 32 5D 96 AD 2B 8B F9 1F AB 1B 29 89 32 77
26 86 3A 4F 17 30 42 99 3A 26 30 7A 4D 3A 64 2B
8B FA E0 AB 0D 3A 23 D4 01 B3 F8 08 A9 D4 01 BE
3A 9C 8C FC FF 9C 7C 01 F6 32 AE A9 D4 01 E1 D4
FF 3C 17 29 89 3A 9F 9B BA 8B AA 99 3A 8A A0 F8
03 B0 D0 1B 1B 4B BA 4B AA 4B BC 4B AC D5 9A FC
11 A7 8F A8 7E B7 D4 FF 3C 9F FF 02 BF 8A FE A7
9F 7C 00 B7 47 BB 47 AB FF FE 3A DF 9B FF FE B9
D5 9A B7 8A A7 F8 20 A8 87 FE A7 97 7E B7 88 7E
A8 3B E8 D5 6F 73 00 6B 65 72 6E 65 6C 00 00 00
00 00 08 00 01 
END

bword $((`getau`*8)) >> image/0

hexout << END >> image/0
                     00 00 00 08 01 00 00 00 00
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
00 00 00 00 00 00 00 00 00 00 00 00
END

addfile ./files rom >> image/0


echo Padding out allocation table

aus=`getau`
ones $((7*512-2*$aus)) >> image/2


echo Compressing AUs and building index

bbyte $(($aus-1)) > romdisk.img

au=0
offset=$((1+$aus*2))

while [ $au -lt $aus ]
do
  zx1 -f image/$au /tmp/au.zx1 > /dev/null
  cat /tmp/au.zx1 >> /tmp/disk.zx1

  bword $offset >> romdisk.img

  offset=$(($offset+`fsize /tmp/au.zx1`))
  au=$(($au+1))
done


echo Assembling final disk image

cat /tmp/disk.zx1 >> romdisk.img

echo -n "  "
wc -c romdisk.img
echo

