#!/bin/sh
export KERNELDIR=`readlink -f .`
export RAMFS_SOURCE=`readlink -f $KERNELDIR/../SCH-I939D-Ramfs`
export PARENT_DIR=`readlink -f ..`
export USE_SEC_FIPS_MODE=true
export CROSS_COMPILE=/opt/toolchains/arm-eabi-4.7/bin/arm-eabi-

BOEFFLA_RAMDISK="ramdisk_boeffla"

RAMFS_TMP="/tmp/ramfs-source-i939d"

#remove previous ramfs files
rm -rf $RAMFS_TMP
rm -rf $RAMFS_TMP.cpio
rm -rf $RAMFS_TMP.cpio.gz
#copy ramfs files to tmp directory
cp -ax $RAMFS_SOURCE $RAMFS_TMP
#clear git repositories in ramfs
find $RAMFS_TMP -name .git -exec rm -rf {} \;
#remove empty directory placeholders
find $RAMFS_TMP -name EMPTY_DIRECTORY -exec rm -rf {} \;
rm -rf $RAMFS_TMP/tmp/*
#remove mercurial repository
rm -rf $RAMFS_TMP/.hg
#copy modules into ramfs
mkdir -p $INITRAMFS/lib/modules
mv -f drivers/media/video/samsung/mali_r3p0_lsi/mali.ko drivers/media/video/samsung/mali_r3p0_lsi/mali_r3p0_lsi.ko
mv -f drivers/net/wireless/bcmdhd.cm/dhd.ko drivers/net/wireless/bcmdhd.cm/dhd_cm.ko
find -name '*.ko' -exec cp -av {} $RAMFS_TMP/lib/modules/ \;
${CROSS_COMPILE}strip --strip-unneeded $RAMFS_TMP/lib/modules/*


# Remove and copy new boeffla specific configuration files into corresponding directory
rm -rf $RAMFS_TMP"/res"
cp -R $BOEFFLA_RAMDISK"/res" $RAMFS_TMP
rm -rf $RAMFS_TMP"/sbin/boeffla-*"
rm -rf $RAMFS_TMP"/sbin/busybox"

for f in $BOEFFLA_RAMDISK"/sbin/"*
do
    cp $f $RAMFS_TMP"/sbin/"
done

for f in $RAMFS_TMP"/sbin/"*
do
    chmod 750 $f
done

# Patch boeffla
for f in $BOEFFLA_RAMDISK"/"*.patch
do
    patch -d $RAMFS_TMP < $f
done

cd $RAMFS_TMP
find | fakeroot cpio -H newc -o > $RAMFS_TMP.cpio 2>/dev/null
ls -lh $RAMFS_TMP.cpio
gzip -9 $RAMFS_TMP.cpio
cd -


./mkbootimg --kernel $KERNELDIR/arch/arm/boot/zImage --ramdisk $RAMFS_TMP.cpio.gz --board smdk4x12 --base 0x10000000 --pagesize 2048 --ramdiskaddr 0x11000000 --cmdline "no_console_suspend=1 console=null" -o $KERNELDIR/boot.img

#$KERNELDIR/mkshbootimg.py $KERNELDIR/boot.img $KERNELDIR/boot.img.pre
#rm -f $KERNELDIR/boot.img.pre

tar -H ustar -c boot.img > boot.tar
md5sum -t boot.tar >> boot.tar
mv boot.tar boot.tar.md5

