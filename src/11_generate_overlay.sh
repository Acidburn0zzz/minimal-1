#!/bin/sh

set -e

# Load common properties and functions in the current script.
. ./common.sh

echo "*** GENERATE OVERLAY BEGIN ***"

# Remove the old ISO image overlay area.
echo "Removing old overlay area. This may take a while."
rm -rf $ISOIMAGE_OVERLAY

# Create the new ISO image overlay area.
mkdir -p $ISOIMAGE_OVERLAY
cd $ISOIMAGE_OVERLAY

# Read the 'OVERLAY_TYPE' property from '.config'
OVERLAY_TYPE=`read_property OVERLAY_TYPE`

# Read the 'OVERLAY_LOCATION' property from '.config'
OVERLAY_LOCATION=`read_property OVERLAY_LOCATION`

if [ "$OVERLAY_LOCATION" = "iso" \
  -a "$OVERLAY_TYPE" = "sparse" \
  -a -d $OVERLAY_ROOTFS \
  -a ! "`ls -A $OVERLAY_ROOTFS`" = "" \
  -a "$(id -u)" = "0" ] ; then

  # Use sparse file as storage place. The above check guarantees that the whole
  # script is executed with root permissions or otherwise this block is skipped.
  # All files and folders located in the folder 'minimal_overlay' will be merged
  # with the root folder on boot.

  echo "Using sparse file for overlay."

  # This is the BusyBox executable that we have already generated.
  BUSYBOX=$ROOTFS/bin/busybox

  # Create sparse image file with 3MB size. Note that this increases the ISO
  # image size.
  $BUSYBOX truncate -s 3M $ISOIMAGE_OVERLAY/minimal.img

  # Find available loop device.
  LOOP_DEVICE=$($BUSYBOX losetup -f)

  # Associate the available loop device with the sparse image file.
  $BUSYBOX losetup $LOOP_DEVICE $ISOIMAGE_OVERLAY/minimal.img

  # Format the sparse image file with Ext2 file system.
  $BUSYBOX mkfs.ext2 $LOOP_DEVICE

  # Mount the sparse file in folder 'sparse".
  mkdir $ISOIMAGE_OVERLAY/sparse
  $BUSYBOX mount $ISOIMAGE_OVERLAY/minimal.img sparse

  # Create the overlay folders.
  mkdir -p $ISOIMAGE_OVERLAY/sparse/rootfs
  mkdir -p $ISOIMAGE_OVERLAY/sparse/work

  # Copy the overlay content.
  cp -r $OVERLAY_ROOTFS/* \
    $ISOIMAGE_OVERLAY/sparse/rootfs
  cp -r $SRC_DIR/minimal_overlay/rootfs/* \
    $ISOIMAGE_OVERLAY/sparse/rootfs

  # Unmount the sparse file and delete the temporary folder.
  sync
  $BUSYBOX umount $ISOIMAGE_OVERLAY/sparse
  sync
  sleep 1
  rm -rf $ISOIMAGE_OVERLAY/sparse

  # Detach the loop device since we no longer need it.
  $BUSYBOX losetup -d $LOOP_DEVICE
elif [ "$OVERLAY_LOCATION" = "iso" \
  -a "$OVERLAY_TYPE" = "folder" \
  -a -d $OVERLAY_ROOTFS \
  -a ! "`ls -A $OVERLAY_ROOTFS`" = "" ] ; then

  # Use normal folder structure for overlay. All files and folders located in
  # the folder 'minimal_overlay' will be merged with the root folder on boot.

  echo "Using folder structure for overlay."

  # Create the overlay folders.
  mkdir -p $ISOIMAGE_OVERLAY/minimal/rootfs
  mkdir -p $ISOIMAGE_OVERLAY/minimal/work

  # Copy the overlay content.
  cp -rf $OVERLAY_ROOTFS/* \
    $ISOIMAGE_OVERLAY/minimal/rootfs
  cp -r $SRC_DIR/minimal_overlay/rootfs/* \
    $ISOIMAGE_OVERLAY/minimal/rootfs
else
  echo "The ISO image will have no overlay structure."
fi

cd $SRC_DIR

echo "*** GENERATE OVERLAY END ***"
