#!/system/bin/sh

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
	/sbin/busybox grep ro.build.version /system/build.prop >> $BOEFFLA_LOGFILE
	echo "=========================" >> $BOEFFLA_LOGFILE

# Correct /sbin and /res directory and file permissions
	/sbin/busybox mount -o remount,rw /

	# change permissions of /sbin folder and scripts in /res/bc
	/sbin/busybox chmod -R 755 /sbin
	/sbin/busybox chmod 755 /res/bc/*

	/sbin/busybox sync
	/sbin/busybox mount -o remount,ro /

# Custom boot animation support only for Samsung Kernel,
# boeffla sound change delay changed only for Samsung Kernel
	if [ "SAM" == "$KERNEL" ]; then

		# check whether custom boot animation is available to be played
		if /sbin/busybox [ -f /data/local/bootanimation.zip ] || /sbin/busybox [ -f /system/media/bootanimation.zip ]; then
				echo $(date) Playing custom boot animation >> $BOEFFLA_LOGFILE
				/system/bin/bootanimation &
		else
				echo $(date) Playing Samsung stock boot animation >> $BOEFFLA_LOGFILE
				/system/bin/samsungani &
		fi

		# set boeffla sound change delay to 200 ms
		echo "200000" > /sys/class/misc/boeffla_sound/change_delay
		echo $(date) Boeffla-Sound change delay set to 200 ms >> $BOEFFLA_LOGFILE
	fi

# Set the options which change the stock kernel defaults
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

	# AC charging rate defaults defaults to 1100 mA
	echo "1100" > /sys/kernel/charge_levels/charge_level_ac
	echo $(date) "AC charge rate set to 1100 mA" >> $BOEFFLA_LOGFILE

# Now wait for the rom to finish booting up
# (by checking for the android acore process)
	while ! /sbin/busybox pgrep android.process.acore ; do
	  /sbin/busybox sleep 1
	done
	echo $(date) Rom boot trigger detected... >> $BOEFFLA_LOGFILE

# Play sound for Boeffla-Sound compatibility
	/sbin/tinyplay /res/misc/silence.wav -D 0 -d 0 -p 880

# Interaction with Boeffla-Config app V2
	# save original stock values for selected parameters
	cat /sys/devices/system/cpu/cpu0/cpufreq/UV_mV_table > /dev/bk_orig_cpu_voltage
	cat /sys/class/misc/gpu_clock_control/gpu_control > /dev/bk_orig_gpu_clock
	cat /sys/class/misc/gpu_voltage_control/gpu_control > /dev/bk_orig_gpu_voltage
	cat /sys/kernel/charge_levels/charge_level_ac > /dev/bk_orig_charge_level_ac
	cat /sys/kernel/charge_levels/charge_level_usb > /dev/bk_orig_charge_level_usb
	cat /sys/kernel/charge_levels/charge_level_wireless > /dev/bk_orig_charge_level_wireless
	cat /sys/module/lowmemorykiller/parameters/minfree > /dev/bk_orig_minfree
	/sbin/busybox lsmod > /dev/bk_orig_modules

	# remove old startconfig done file
	/sbin/busybox rm -f $BOEFFLA_DATA_PATH/startconfig_done

	# if there is a startconfig placed by Boeffla-Config V2 app, execute it
	if [ -f /data/.boeffla/startconfig ]; then
		echo "Startup configuration found, applying now the following:"  >> $BOEFFLA_LOGFILE
		cat /data/.boeffla/startconfig >> $BOEFFLA_LOGFILE
		. /data/.boeffla/startconfig
		echo "Startup configuration applied."  >> $BOEFFLA_LOGFILE
	fi
	
# Wait for another 12 seconds before we continue
	echo $(date) Waiting 12 more seconds... >> $BOEFFLA_LOGFILE
	/sbin/busybox sleep 12

# Cleanup: delete the old scriptmanager and dialog helper app
# and delete old config scripts in init.d
	/system/bin/pm uninstall bo.boeffla
	/system/bin/pm uninstall bo.boeffla.tweaks.dialog.helper
	/sbin/busybox mount -o remount,rw -t ext4 $SYSTEM_DEVICE /system
	/sbin/busybox rm /system/etc/init.d/*_bk*
	/sbin/busybox rm /system/etc/init.d/*_???bk*
	/sbin/busybox mount -o remount,ro -t ext4 $SYSTEM_DEVICE /system

# Turn off debugging for certain modules
	echo 0 > /sys/module/ump/parameters/ump_debug_level
	echo 0 > /sys/module/mali/parameters/mali_debug_level
	echo 0 > /sys/module/kernel/parameters/initcall_debug
	echo 0 > /sys/module/lowmemorykiller/parameters/debug_level
	echo 0 > /sys/module/earlysuspend/parameters/debug_mask
	echo 0 > /sys/module/alarm/parameters/debug_mask
	echo 0 > /sys/module/alarm_dev/parameters/debug_mask
	echo 0 > /sys/module/binder/parameters/debug_mask
	echo 0 > /sys/module/xt_qtaguid/parameters/debug_mask

# Auto root support
	if [ -f /data/media/autoroot ]; then

		echo $(date) Auto root is enabled >> $BOEFFLA_LOGFILE

		if [ ! -f /system/xbin/su ] && [ ! -f /system/bin/su ]; then
			/sbin/busybox mount -o remount,rw -t ext4 $SYSTEM_DEVICE /system
			/sbin/busybox cp /res/misc/su /system/xbin/su
			/sbin/busybox chown 0.0 /system/xbin/su
			/sbin/busybox chmod 6755 /system/xbin/su
			/sbin/busybox mount -o remount,ro -t ext4 $SYSTEM_DEVICE /system
			echo $(date) Auto root: su binaries copied >> $BOEFFLA_LOGFILE
		fi

		if [ ! -f /system/app/Superuser.apk ] && [ ! -f /data/app/Superuser.apk ]; then
			/sbin/busybox mount -o remount,rw -t ext4 $SYSTEM_DEVICE /system
			/sbin/busybox cp /res/misc/Superuser.apk /system/app/Superuser.apk
			/sbin/busybox chown 0.0 /system/app/Superuser.apk
			/sbin/busybox chmod 644 /system/app/Superuser.apk
			/sbin/busybox mount -o remount,ro -t ext4 $SYSTEM_DEVICE /system
			echo $(date) Auto root: Superuser app copied >> $BOEFFLA_LOGFILE
		fi

		rm /data/media/autoroot
	fi

# EFS backup
	EFS_BACKUP_INT="$BOEFFLA_DATA_PATH/efs.tar.gz"
	EFS_BACKUP_EXT="/storage/extSdCard/efs.tar.gz"

	if [ ! -f $EFS_BACKUP_INT ]; then

		cd /efs
		/sbin/busybox tar cvz -f $EFS_BACKUP_INT .
		/sbin/busybox chmod 666 $EFS_BACKUP_INT

		/sbin/busybox cp $EFS_BACKUP_INT $EFS_BACKUP_EXT
		
		echo $(date) EFS Backup: Not found, now creating one >> $BOEFFLA_LOGFILE
	fi

# init.d support
	if cd /system/etc/init.d >/dev/null 2>&1 ; then
		for file in * ; do
			if ! cat "$file" >/dev/null 2>&1 ; then continue ; fi
			echo $(date) init.d file $file started >> $BOEFFLA_LOGFILE
			/system/bin/sh "$file"
			echo $(date) init.d file $file executed >> $BOEFFLA_LOGFILE
		done
	fi

# Finished
	echo $(date) Boeffla-Kernel initialisation completed >> $BOEFFLA_LOGFILE
