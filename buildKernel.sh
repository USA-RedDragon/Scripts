#!/bin/bash

export kernel=Werewolf
export device=hammerhead
export deviceconfig=werewolf_defconfig
export outdir=/usr/share/nginx/html/Werewolf
export makeopts="-j$(nproc)"
export zImagePath="arch/arm/boot/zImage-dtb"
export dtbPath="/does/not/apply-Dtb-is-baked-in"
export KBUILD_BUILD_USER=USA-RedDragon
export KBUILD_BUILD_HOST=EdgeOfCreation
export CROSS_COMPILE="ccache /root/deso/prebuilts/gcc/linux-x86/arm/arm-eabi-4.8/bin/arm-eabi-"
export ARCH=arm

export version=$(cat version)

if [[ $1 =~ "clean" ]] ; then
	make clean
	make mrproper
fi

make ${makeopts} ${deviceconfig}
make ${makeopts}

if [ -a ${zImagePath} ] ; then
	cp ${zImagePath} zip/zImage
	find -name '*.ko' -exec cp -av {} zip/modules/ \;
    if [ -a ${dtbPath} ] ; then
        cp ${dtbPath} zip/dtb
        dtbargs=dtb
    fi
	cd zip
	zip -q -r ${kernel}-${device}-${version}.zip anykernel.sh  META-INF  modules  ramdisk  tools zImage ${dtbargs}
else
	echo -e "\n\e[31m***** Build Failed *****\e[0m\n"
fi

if ! [ -d ${outdir} ] ; then
	mkdir ${outdir}
fi

if [ -a ${kernel}-${device}-${version}.zip ] ; then
	mv -v ${kernel}-${device}-${version}.zip ${outdir}
fi

rm -f kernel/zImage
rm -f system/lib/modules/*
