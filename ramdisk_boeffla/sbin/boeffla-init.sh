#!/system/bin/sh
#
# credits to various people

# define block devices
SYSTEM_DEVICE="/dev/block/mmcblk0p9"
CACHE_DEVICE="/dev/block/mmcblk0p8"
DATA_DEVICE="/dev/block/mmcblk0p12"


# define file paths, depending on whether we are on Samsung or CM
if [ -d "/lib/modules" ] ; then
	# Samsung
	BOEFFLA_DATA_PATH="/data/media/boeffla-kernel-data"
	KERNEL="SAM"
else
	# CM
	BOEFFLA_DATA_PATH="/data/media/0/boeffla-kernel-data"
	KERNEL="CM"
fi
BOEFFLA_LOGFILE="$BOEFFLA_DATA_PATH/boeffla-kernel.log"


# If not yet exists, create a boeffla-kernel-data folder on sdcard 
# which is used for many purposes (set permissions and owners correctly)
if [ ! -d "$BOEFFLA_DATA_PATH" ] ; then
	/sbin/busybox mkdir $BOEFFLA_DATA_PATH
	/sbin/busybox chmod 775 $BOEFFLA_DATA_PATH
	/sbin/busybox chown 1023:1023 $BOEFFLA_DATA_PATH
fi

# maintain log file history
rm $BOEFFLA_LOGFILE.3
mv $BOEFFLA_LOGFILE.2 $BOEFFLA_LOGFILE.3
mv $BOEFFLA_LOGFILE.1 $BOEFFLA_LOGFILE.2
mv $BOEFFLA_LOGFILE $BOEFFLA_LOGFILE.1


# Initialize the log file (chmod to make it readable also via /sdcard link)
echo $(date) Boeffla-Kernel initialisation started > $BOEFFLA_LOGFILE
/sbin/busybox chmod 666 $BOEFFLA_LOGFILE
/sbin/busybox cat /proc/version >> $BOEFFLA_LOGFILE
echo "=========================" >> $BOEFFLA_LOGFILE


# Include version information about firmware in log file
/sbin/busybox grep ro.build.version /system/build.prop >> $BOEFFLA_LOGFILE
echo "=========================" >> $BOEFFLA_LOGFILE


# Fix potential issues and clean up
. /sbin/boeffla-fix-and-cleanup.inc


# Custom boot animation support only for Samsung Kernel,
# boeffla sound change delay changed only for Samsung Kernel
if [ "SAM" == "$KERNEL" ]; then
	. /sbin/boeffla-bootanimation.inc
	. /sbin/boeffla-sound-prepare.inc
fi


# Then set the options which change the stock kernel defaults
# to Boeffla-Kernel defaults

# Ext4 tweaks default to on
sync
/sbin/busybox mount -o remount,commit=20,noatime $CACHE_DEVICE /cache
sync
/sbin/busybox mount -o remount,commit=20,noatime $DATA_DEVICE /data
sync
echo $(date) Ext4 tweaks applied >> $BOEFFLA_LOGFILE

# Sdcard buffer tweaks default to 256 kb
echo 256 > /sys/block/mmcblk0/bdi/read_ahead_kb
echo $(date) "SDcard buffer tweaks (256 kb) applied for internal sd memory" >> $BOEFFLA_LOGFILE
echo 256 > /sys/block/mmcblk1/bdi/read_ahead_kb
echo $(date) "SDcard buffer tweaks (256 kb) applied for external sd memory" >> $BOEFFLA_LOGFILE

# AC and USB charging rate defaults default to 1100 and 475 mA
echo "1100" > /sys/kernel/charge_levels/charge_level_ac
echo $(date) "AC charge rate set to 1100 mA" >> $BOEFFLA_LOGFILE
echo "475" > /sys/kernel/charge_levels/charge_level_usb
echo $(date) "USB charge rate set to 475 mA" >> $BOEFFLA_LOGFILE

# Android logger defaults to off
echo 0 > /sys/kernel/logger_mode/logger_mode
echo $(date) Android logger disabled >> $BOEFFLA_LOGFILE

# Kernel logger defaults to off (only Samsung kernels)
if [ "SAM" == "$KERNEL" ]; then
	echo 0 > /sys/kernel/printk_mode/printk_mode
	echo $(date) Kernel logger disabled >> $BOEFFLA_LOGFILE
fi

# Now wait for the rom to finish booting up
# (by checking for the android acore process)
while ! /sbin/busybox pgrep android.process.acore ; do
  /sbin/busybox sleep 1
done
echo $(date) Rom boot trigger detected, continuing after 12 more seconds... >> $BOEFFLA_LOGFILE
/sbin/busybox sleep 12


# Configuration app support (delete the old scriptmanager app)
. /sbin/boeffla-app.inc

# Turn off debugging for certain modules
. /sbin/boeffla-disabledebugging.inc

# Auto root support
. /sbin/boeffla-autoroot.inc

# EFS backup
. /sbin/boeffla-efsbackup.inc

# init.d support
. /sbin/boeffla-initd.inc

# Finished
echo $(date) Boeffla-Kernel initialisation completed >> $BOEFFLA_LOGFILE
