#!/bin/bash

KERNEL_BRANCH=Boeffla-Kernel
KERNEL_VERSION=3.2

export ARCH=arm
export KBUILD_BUILD_USER=$KERNEL_BRANCH"-"$KERNEL_VERSION"-"`(date +%Y%m%d)`
export KBUILD_BUILD_HOST=sntree

echo "Will build kernel " $KBUILD_BUILD_USER"@"$KBUILD_BUILD_HOST

GOOGLE_TC=/opt/toolchains/arm-eabi-4.7/bin/arm-eabi-
LINARO_TC=/home/guni/kernel/arm-eabi-linaro-4.8.2/bin/arm-eabi-

print_error()
{
    echo "Usage: $1 operator toolchain_type"
    echo "$1 m0duosctc/m0 google/linaro"
    exit
}

check_op()
{
    if [ ! $1 ]
    then
        retval="false"
    elif [ $1 == "m0duosctc" ] || [ $1 == "m0" ]
    then
        retval="true"
    else
        retval="false"
    fi
    echo $retval
}

check_toolchain()
{
    if [ ! $1 ]
    then
        retval="false"
    elif [ $1 == "google" ] || [ $1 == "linaro" ]
    then
        retval="true"
    else
        retval="false"
    fi
    echo $retval
}

check_zimage()
{
    if [ -e arch/arm/boot/zImage ]
    then
        echo Found zImage in kernel build path!
    else
        echo Did not find zImage in kernel build path! Build the kernel first!
        exit 0
    fi
}

check_kernel()
{
    if [ -d $1"/boot.img-ramdisk" ]
    then
        echo Found boot.img-ramdisk in $1 directory

        if [ -e $1"/zImage" ]
        then
            echo Found zImage in $1 directory
        else
            echo Did not find zImage in $1 directory
            exit 0
        fi
    else
        echo Did not find boot.img-ramdisk folder in $1 directory!
        exit 0
    fi
}

check_modules()
{
    if [ -d modules ]
    then
        echo Found modules folder!
    else
        echo Did not find modules folder!
        exit 0
    fi
}

build_mkboot()
{
    mkbootimg_src=mkbootimg.c
    mkbootimg_out=mkbootimg
    mkbootfs_file=mkbootfs
    mkbootimg_file=$mkbootimg_out

    if [ -e $1"/"$mkbootfs_file ]
    then
        echo "Found $mkbootfs_file"
    else
        echo
        echo "Compiling mkbootfs ..."
        cd $1
        gcc -o mkbootfs mkbootfs.c 2>/dev/null
        cd ..

        if [ -e $1"/"$mkbootfs_file ]
        then
            echo mkbootfs successfully compiled
        else
            echo "Error: mkbootfs not successfully compiled!"
            exit 0   
        fi
    fi

    if [ -e $1"/"$mkbootimg_file ]
    then
        rm -f $mkbootimg_file
    fi

    echo
    echo "Compiling mkbootimg ..."
    cd $1
    gcc -c rsa.c
    gcc -c sha.c
    gcc rsa.o sha.o $mkbootimg_src -w -o $mkbootimg_out
    rm *.o
    cd ..

    if [ -e $1"/"$mkbootimg_file ]
    then
        echo "$mkbootimg_out successfully compiled"
    else
        echo "Error: $mkbootimg_out not successfully compiled!"
        exit 0
    fi    

    cp $1"/"$mkbootfs_file $2
    cp $1"/"$mkbootimg_file $2
}

retval=$( check_op $1 )
OP="m0duosctc"                    # assign m0duosctc as default operator
if [ "$retval" == "true" ]
then
    OP=$1
else
    print_error $0
fi

retval=$( check_toolchain $2 )
TC="google"                 # assign google toolchain as default toolchain
if [ "$retval" == "true" ]
then
    TC=$2
else
    print_error $0
fi

if [ $TC == "google" ]
then
    export CROSS_COMPILE=$GOOGLE_TC
elif [ $TC == "linaro" ]
then
    export CROSS_COMPILE=$LINARO_TC
fi

DEFCONFIG=$OP"_00_defconfig"

# Start build the kernel using four threads
make $DEFCONFIG
make -j4


check_zimage


