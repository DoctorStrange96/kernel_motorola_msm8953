#!/bin/bash

# Variables
sequence=`seq 1 100`;
this="KaminariKernel";

# Set up the cross-compiler (pt. 1)
export ARCH=arm64;
export SUBARCH=arm64;
export PATH=$HOME/Toolchains/Linaro-GCC-7.4-ARM64/bin:$PATH;
export CROSS_COMPILE=aarch64-linux-gnu-;
CLANG=$HOME/Toolchains/Clang-9.0.3/bin/clang-9;
device=sanders;

# Clear the screen
clear;

# Variables for bold & normal text
bold=`tput bold`;
normal=`tput sgr0`;

# Let's start...
echo -e "Building Lit Kernel for Moto G5s Plus (sanders)...\n";

cleanstr="Do you want to remove everything from the last build? (Y/N)

You ${bold}MUST${normal} do this if you have changed toolchains and/or hotplugs. ";

# Select which device the kernel should be built for
# Clean everything via `make mrproper`.
# Recommended if there were extensive changes to the source code or if building for a different device.
while read -p "$cleanstr" clean; do
	case $clean in
		"y" | "Y" | "yes" | "Yes")
			echo -e "Cleaning everything...\n";
			make --quiet mrproper && \
			find . -iname "*.dtb" -exec rm -f {} \; && \
				echo -e "Done!\n";
			break;;
		"n" | "N" | "no" | "No" | "" | " ")
			echo -e "Not cleaning anything.\n";
			break;;
		*)
			echo -e "\nInvalid option. Try again.\n";;
	esac;
done;
	
# Tell exactly when the build started
echo -e "Build started at:\n`date +"%A, %d %B %Y @ %H:%M:%S %Z"`\n`date --utc +"%A, %d %B %Y @ %H:%M:%S %Z"`\n";
starttime=`date +"%s"`;
			
# Build the kernel
make sanders_defconfig O=out;

# 2x no. of CPU cores
make -j$((`nproc --all` * 2)) CC=$CLANG CLANG_TRIPLE=aarch64-linux-gnu O=out;

if [[ -f arch/arm/boot/Image.gz ]]; then
	echo -e "Code compilation finished at:\n`date +"%A, %d %B %Y @ %H:%M:%S %Z (GMT %:z)"`\n`date --utc +"%A, %d %B %Y @ %H:%M:%S %Z"`\n";
	maketime=`date +"%s"`;
	makediff=$(($maketime - $starttime));
	echo -e "Code compilation took: $(($makediff / 60)) minute(s) and $(($makediff % 60)) second(s).\n";
	version=`date --utc "+%Y%m%d-%H%M%S"`;
else
	echo -e "Image.gz not found. Kernel build failed. Aborting.\n";
	exit 1;
fi;

# Define directories (zip, out)
maindir=$HOME/Kernel/zip/lit;
outdir=$HOME/Kernel/out/lit/$device;
devicedir=$maindir/$device;

# Make the zip and out dirs if they don't exist
if [ ! -d $maindir ] || [ ! -d $outdir ]; then
	mkdir -p $maindir && mkdir -p $outdir;
fi;

# Copy zImage & generate dt.img
echo -e "Copying zImage...\n";
cp -rf out/arch/arm64/boot/Image.gz $devicedir/;
echo -e "Compiling device tree...\n";
python dtbtool.py -o $devicedir/dt.img out/arch/arm64/boot/dts/qcom/ -s 2048 -p out/scripts/dtc/;

# Copy modules
find . -type f -name "*.ko" -exec cp {} $devicedir/modules/vendor/lib/modules/ \;

# Set the zip's name
zipname="Lit-$version-$device-AnyKernel";

# Zip the stuff we need & finish
echo -e "Creating flashable ZIP...\n";
echo -e $device > $devicedir/device.txt;
echo -e "Version: $version" > $devicedir/version.txt;
cd $maindir/common;
zip -r9 $outdir/$zipname.zip . > /dev/null;
cd $devicedir;
zip -r9 $outdir/$zipname.zip * > /dev/null;
echo -e "Done!"
# Tell exactly when the build finished
echo -e "Build finished on:\n`date +"%A, %d %B %Y @ %H:%M:%S %Z (GMT %:z)"`\n`date --utc +"%A, %d %B %Y @ %H:%M:%S %Z"`\n";
finishtime=`date +"%s"`;
finishdiff=$(($finishtime - $starttime));
echo -e "This build took: $(($finishdiff / 60)) minute(s) and $(($finishdiff % 60)) second(s).\n";
