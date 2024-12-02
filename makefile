
FILES=$(wildcard files/* files/*/* files/*/*/*)

all: romdisk.img

romdisk.img: $(FILES)
	bash tools/mkdisk.sh

clean: FORCE
	rm -f romdisk.img
	find files -name ... -delete
	rm -rf image

FORCE:
