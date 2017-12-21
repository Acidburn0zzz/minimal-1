#!/bin/sh

set -e

# Load common properties and functions in the current script.
. ./common.sh

echo "*** GENERATE ROOTFS BEGIN ***"

echo "Preparing rootfs work area. This may take a while."
rm -rf $ROOTFS

# Copy all BusyBox generated stuff to the location of our 'rootfs' folder.
cp -r $BUSYBOX_INSTALLED $ROOTFS

# Copy all rootfs resources to the location of our 'rootfs' folder.
cp -r $SRC_DIR/minimal_rootfs/* $ROOTFS

# Delete the '.keep' files which we use in order to keep track of otherwise
# empty folders.
find $ROOTFS/* -type f -name '.keep' -exec rm {} +

# Remove 'linuxrc' which is used when we boot in 'RAM disk' mode.
rm -f $ROOTFS/linuxrc

# This is for the dynamic loader. Note that the name and the location are both
# specific for 32-bit and 64-bit machines. First we check the BusyBox executable
# and then we copy the dynamic loader to its appropriate location.
BUSYBOX_ARCH=$(file $ROOTFS/bin/busybox | cut -d' ' -f3)
if [ "$BUSYBOX_ARCH" = "64-bit" ] ; then
  mkdir -p $ROOTFS/lib64
  cp $SYSROOT/lib/ld-linux* $ROOTFS/lib64
  echo "Dynamic loader is accessed via '/lib64'."
else
  cp $SYSROOT/lib/ld-linux* $ROOTFS/lib
  echo "Dynamic loader is accessed via '/lib'."
fi

# Copy all necessary 'glibc' libraries to '/lib' BEGIN.

# BusyBox has direct dependencies on these libraries.
cp $SYSROOT/lib/libm.so.6 $ROOTFS/lib
cp $SYSROOT/lib/libc.so.6 $ROOTFS/lib

# Copy all necessary 'glibc' libraries to '/lib' END.

echo "Reducing the size of libraries and executables."
set +e
strip -g \
  $ROOTFS/bin/* \
  $ROOTFS/sbin/* \
  $ROOTFS/lib/* \
  2>/dev/null
set -e

# Read the 'OVERLAY_LOCATION' property from '.config'
OVERLAY_LOCATION=`read_property OVERLAY_LOCATION`

if [ "$OVERLAY_LOCATION" = "rootfs" \
  -a -d $OVERLAY_ROOTFS \
  -a ! "`ls -A $OVERLAY_ROOTFS`" = "" ] ; then

  echo "Merging overlay software in rootfs."

  # With '--remove-destination' all possibly existing soft links in
  # $OVERLAY_ROOTFS will be overwritten correctly.
  cp -r --remove-destination \
    $OVERLAY_ROOTFS/* $ROOTFS
  cp -r --remove-destination \
    $SRC_DIR/minimal_overlay/rootfs/* $ROOTFS
fi

echo "The rootfs area has been generated."

cd $SRC_DIR

echo "*** GENERATE ROOTFS END ***"
