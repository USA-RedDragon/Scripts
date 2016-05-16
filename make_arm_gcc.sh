#! /bin/bash

#-------------------------------------------------------------------------------------------
# This script will download packages for, configure, build and install a GCC cross-compiler.
#-------------------------------------------------------------------------------------------

START_DIR=$(pwd)

function version() {
echo -e "CrossCompilerCompiler v0.0.1Beta"
}

function help() {
usage
}

function usage() {
version
echo
echo -e "Usage: $0 -t gcc_target -a linux_arch -o output_dir [-k] [-NUGBXLIY] [-c gcc_config_options] [-j make_jobs] [-g gcc_version] [-l linux_version <-3|-4>] [-b binutils_version] [-x glibc_version] [-l linux_version] [-f mpfr_version] [-m mpc_version] [-z gmp_version] [-i isl_version] [-y cloog_version]"
echo
echo -e "Compiles cross compilers for any gcc-supported platform"
echo
echo -e "-t the target gcc will try to make a compiler for, e.g. arm-eabi"
echo -e "-a the linux kernel arch your platform is, e.g. arm"
echo -e "-o where to output the toolchain"
echo -e "-v show version"
echo -e "-h show help"
echo -e "-k clean workspace"
echo -e "-N use Newlib glibc alternative for embedded platforms"
echo -e "-U use upstreamed versions of the libraries and gcc"
echo -e "-G use upstream gcc"
echo -e "-B use upstream binutils"
echo -e "-X use upstream glibc"
echo -e "-L use upstream linux"
echo -e "-I use upstream isl"
echo -e "-Y use upstream cloog"
echo -e "-3 use a 3.x version of linux"
echo -e "-4 use a 4.x version of linux"
echo -e "-U show this message"
echo -e "-c config options to send to gcc, default is \"--disable-multilib\""
echo -e "-j number of process jobs make will use at once, will default to number of cores"
echo -e "-g gcc version to use"
echo -e "-b binutils version to use"
echo -e "-x glibc version to use"
echo -e "-l linux version to use, must be used with either -3 or -4"
echo -e "-f mpfr version to use"
echo -e "-m mpc version to use"
echo -e "-z gmp version to use"
echo -e "-i isl version to use"
echo -e "-y cloog version to use"
echo
echo
echo -e "To build the latest gcc compiler for arm android kernel targets, use this command:"
echo -e "$0 -t arm-eabi -a arm -o /ABSOLUTE/PATH/TO/TOOLCHAIN/OUT -G -N"
}

function clean() {
    echo "Cleaning..."
    if [ -d "/tmp/cross" ]; then
        rm -r /tmp/cross/*
    fi
    if [ -d $INSTALL_PATH ]; then
        rm -r $INSTALL_PATH/*
    fi
    echo "Done"
}

INSTALL_PATH=
TARGET=
LINUX_ARCH=
CONFIGURATION_OPTIONS="--disable-multilib"
PARALLEL_MAKE=-j$(nproc)
USE_NEWLIB=0
UPSTREAM_ALL=0
UPSTREAM_GCC=0
UPSTREAM_BINUTILS=0
UPSTREAM_GLIBC=0
UPSTREAM_LINUX=0
UPSTREAM_ISL=0
UPSTREAM_CLOOG=0
GCC_VERSION=
BINUTILS_VERSION=
GLIBC_VERSION=
LINUX_KERNEL_VERSION=
MPFR_VERSION=
MPC_VERSION=
GMP_VERSION=
ISL_VERSION=
CLOOG_VERSION=
LINUX_3=
LINUX_4=
CLEAN=0

#Some fallback versions
LATEST_GCC_VERSION=gcc-5.3.0
LATEST_BINUTILS_VERSION=binutils-2.26
LATEST_GLIBC_VERSION=glibc-2.23
LATEST_LINUX_KERNEL_VERSION=linux-4.5
LATEST_MPFR_VERSION=mpfr-3.1.4
LATEST_MPC_VERSION=mpc-1.0.3
LATEST_GMP_VERSION=gmp-6.1.0
LATEST_ISL_VERSION=isl-0.16.1
LATEST_CLOOG_VERSION=cloog-0.18.1


while getopts vhko:t:a:c:j:NUGBXLIYg:b:x:l:f:m:z:i:y:34u FLAG; do
case $FLAG in
    v ) version && exit ;;
    h ) help && exit ;;
    k ) CLEAN=1 ;;
    o ) INSTALL_PATH="$OPTARG" ;;
    t ) TARGET="$OPTARG" ;;
    a ) LINUX_ARCH="$OPTARG" ;;
    c ) CONFIGURATION_OPTIONS="$OPTARG" ;;
    j ) PARALLEL_MAKE="-j$OPTARG" ;;
    N ) USE_NEWLIB=1 ;;
    U ) UPSTREAM_ALL=1 ;;
    G ) UPSTREAM_GCC=1 ;;
    B ) UPSTREAM_BINUTILS=1 ;;
    X ) UPSTREAM_GLIBC=1 ;;
    L ) UPSTREAM_LINUX=1 ;;
    I ) UPSTREAM_ISL=1 ;;
    Y ) UPSTREAM_CLOOG=1 ;;
    g ) GCC_VERSION="gcc-$OPTARG" ;;
    b ) BINUTILS_VERSION="binutils-$OPTARG" ;;
    x ) GLIBC_VERSION="glibc-$OPTARG" ;;
    l ) LINUX_VERSION="linux-$OPTARG" ;;
    f ) MPFR_VERSION="mpfr-$OPTARG" ;;
    m ) MPC_VERSION="mpc-$OPTARG" ;;
    z ) GMP_VERSION="gmp-$OPTARG" ;;
    i ) ISL_VERSION="isl-$OPTARG" ;;
    y ) CLOOG_VERSION="cloog-$OPTARG" ;;
    3 ) LINUX_3=1 ;;
    4 ) LINUX_4=1 ;;
    u ) usage && exit ;;
esac
done

if [[ -z "$TARGET" ]]; then echo "You must specify a target with -t" && exit; fi
if [[ -z "$INSTALL_PATH" ]]; then echo "You must specify an output dir with -o" && exit; fi
if [[ -z "$LINUX_ARCH" ]]; then echo "You must specify a target arch with -a" && exit; fi
if [[ $UPSTREAM_ALL -ne 0 && ( -n "$GCC_VERSION" || -n "$BINUTILS_VERSION" || -n "$GLIBC_VERSION" || -n "$LINUX_VERSION" || -n "$MPFR_VERSION" || -n "$MPC_VERSION" || -n "$GMP_VERSION" || -n "$ISL_VERSION" || -n "$CLOOG_VERSION" || -n "$LINUX_4" || -n "$LINUX_3" ) ]]; then echo "You can't specify a version while upstreaming all" && exit; fi
if [[ $UPSTREAM_GCC -ne 0 && -n "$GCC_VERSION" ]]; then echo "Can't specify gcc version while upstreaming" && exit; fi
if [[ $UPSTREAM_BINUTILS -ne 0 && -n "$BINUTILS_VERSION" ]]; then echo "Can't specify binutils version while upstreaming" && exit; fi
if [[ $UPSTREAM_GLIBC -ne 0 && -n "$GLIBC_VERSION" ]]; then echo "Can't specify glibc version while upstreaming" && exit; fi
if [[ $UPSTREAM_LINUX -ne 0 && -n "$LINUX_VERSION" ]]; then echo "Can't specify linux version while upstreaming" && exit; fi
if [[ $UPSTREAM_LINUX -ne 0 && -n "$LINUX_3" ]]; then echo "Can't specify linux version while upstreaming" && exit; fi
if [[ $UPSTREAM_LINUX -ne 0 && -n "$LINUX_4" ]]; then echo "Can't specify linux version while upstreaming" && exit; fi
if [[ -n "$LINUX_3" && -n "$LINUX_4" ]]; then echo "Can't specify two linux versions" && exit; fi
if [[ $UPSTREAM_ISL -ne 0 && -n "$ISL_VERSION" ]]; then echo "Can't specify isl version while upstreaming" && exit; fi
if [[ $UPSTREAM_CLOOG -ne 0 && -n "$CLOOG_VERSION" ]]; then echo "Can't specify cloog version while upstreaming" && exit; fi

if [[ $CLEAN -ne 0 ]]; then clean; fi

export PATH=$INSTALL_PATH/bin:$PATH

export http_proxy=$HTTP_PROXY https_proxy=$HTTP_PROXY ftp_proxy=$HTTP_PROXY

mkdir -p $INSTALL_PATH
mkdir -p /tmp/cross
cd /tmp/cross

if [[ $UPSTREAM_BINUTILS -ne 0 || $UPSTREAM_ALL -ne 0 ]]; then
    git clone http://sourceware.org/git/binutils-gdb.git binutils-upstream
    BINUTILS_VERSION=binutils-upstream
else
    if [[ -z "$BINUTILS_VERSION" ]]; then
        wget -nc https://ftp.gnu.org/gnu/binutils/$LATEST_BINUTILS_VERSION.tar.gz
    else
        wget -nc https://ftp.gnu.org/gnu/binutils/$BINUTILS_VERSION.tar.gz
    fi
fi

if [[ $UPSTREAM_GCC -ne 0 || $UPSTREAM_ALL -ne 0 ]]; then
    git clone https://github.com/gcc-mirror/gcc gcc-upstream
    GCC_VERSION=gcc-upstream
else
    if [[ -z "$GCC_VERSION" ]]; then
        wget -nc https://ftp.gnu.org/gnu/gcc/$LATEST_GCC_VERSION/$LATEST_GCC_VERSION.tar.gz
    else
        wget -nc https://ftp.gnu.org/gnu/gcc/$GCC_VERSION/$GCC_VERSION.tar.gz
    fi
fi


if [ $USE_NEWLIB -ne 0 ]; then
    wget -nc -O newlib-master.zip https://github.com/bminor/newlib/archive/master.zip || true
    unzip -qo newlib-master.zip
else
    if [[ $UPSTREAM_LINUX -ne 0 || $UPSTREAM_ALL -ne 0 ]]; then
        git clone https://github.com/torvalds/linux linux-upstream
        LINUX_VERSION=linux-upstream
    else
        if [[ -z "$LINUX_VERSION" ]]; then
            wget -nc https://www.kernel.org/pub/linux/kernel/v4.x/$LATEST_LINUX_VERSION.tar.xz
        else
            if [[ $LINUX_3 -ne 0 ]]; then
                wget -nc https://www.kernel.org/pub/linux/kernel/v3.x/$LINUX_VERSION.tar.xz
            else
                if [[ $LINUX_4 -ne 0 ]]; then
                    wget -nc https://www.kernel.org/pub/linux/kernel/v4.x/$LINUX_VERSION.tar.xz
                else
                    wget -nc https://www.kernel.org/pub/linux/kernel/v4.x/$LATEST_LINUX_VERSION.tar.xz
                fi
            fi
        fi
    fi
    if [[ $UPSTREAM_GLIBC -ne 0 || $UPSTREAM_ALL -ne 0 ]]; then
        git clone http://sourceware.org/git/glibc.git glibc-upstream
        GLIBC_VERSION=glibc-upstream
    else
        if [[ -z "$GLIBC_VERSION" ]]; then
            wget -nc https://ftp.gnu.org/gnu/glibc/$LATEST_GLIBC_VERSION.tar.xz
        else
            wget -nc https://ftp.gnu.org/gnu/glibc/$GLIBC_VERSION.tar.xz
        fi
    fi
fi

if [[ -z "$MPFR_VERSION" ]]; then
    wget -nc https://ftp.gnu.org/gnu/mpfr/$LATEST_MPFR_VERSION.tar.xz
else
    wget -nc https://ftp.gnu.org/gnu/mpfr/$MPFR_VERSION.tar.xz
fi

if [[ -z "$GMP_VERSION" ]]; then
    wget -nc https://ftp.gnu.org/gnu/gmp/$LATEST_GMP_VERSION.tar.xz
else
    wget -nc https://ftp.gnu.org/gnu/gmp/$GMP_VERSION.tar.xz
fi

if [[ -z "$MPC_VERSION" ]]; then
    wget -nc https://ftp.gnu.org/gnu/mpc/$LATEST_MPC_VERSION.tar.xz
else
    wget -nc https://ftp.gnu.org/gnu/mpc/$MPC_VERSION.tar.xz
fi

if [[ $UPSTREAM_ISL -ne 0 || $UPSTREAM_ALL -ne 0 ]]; then
    git clone http://repo.or.cz/isl.git isl-upstream
    ISL_VERSION=isl-upstream
else
    if [[ -z "$ISL_VERSION" ]]; then
        wget -nc ftp://gcc.gnu.org/pub/gcc/infrastructure/$LATEST_ISL_VERSION.tar.xz
    else
        wget -nc ftp://gcc.gnu.org/pub/gcc/infrastructure/$ISL_VERSION.tar.xz
    fi
fi

if [[ $UPSTREAM_CLOOG -ne 0 || $UPSTREAM_ALL -ne 0 ]]; then
    git clone http://repo.or.cz/cloog.git cloog-upstream
    ISL_VERSION=cloog-upstream
else
    if [[ -z "$CLOOG_VERSION" ]]; then
        wget -nc ftp://gcc.gnu.org/pub/gcc/infrastructure/$LATEST_CLOOG_VERSION.tar.xz
    else
        wget -nc ftp://gcc.gnu.org/pub/gcc/infrastructure/$CLOOG_VERSION.tar.xz
    fi
fi

# Extract everything
for f in *.tar*; do tar xfk $f; done

# Make symbolic links
cd $GCC_VERSION
ln -sf `ls -1d ../mpfr-*/` mpfr
ln -sf `ls -1d ../gmp-*/` gmp
ln -sf `ls -1d ../mpc-*/` mpc
ln -sf `ls -1d ../isl-*/` isl
ln -sf `ls -1d ../cloog-*/` cloog
cd ..

# Step 1. Binutils
mkdir -p build-binutils
cd build-binutils
../$BINUTILS_VERSION/configure --prefix=$INSTALL_PATH --target=$TARGET $CONFIGURATION_OPTIONS
make $PARALLEL_MAKE
make install
cd ..

# Step 2. Linux Kernel Headers
if [ $USE_NEWLIB -eq 0 ]; then
    cd $LINUX_KERNEL_VERSION
    make ARCH=$LINUX_ARCH INSTALL_HDR_PATH=$INSTALL_PATH/$TARGET headers_install
    cd ..
fi

# Step 3. C/C++ Compilers
mkdir -p build-gcc
cd build-gcc
if [ $USE_NEWLIB -ne 0 ]; then
    NEWLIB_OPTION=--with-newlib
fi
../$GCC_VERSION/configure --prefix=$INSTALL_PATH --target=$TARGET --enable-languages=c,c++ $CONFIGURATION_OPTIONS $NEWLIB_OPTION
make $PARALLEL_MAKE all-gcc
make install-gcc
cd ..

if [ $USE_NEWLIB -ne 0 ]; then
    # Steps 4-6: Newlib
    mkdir -p build-newlib
    cd build-newlib
    ../newlib-master/configure --prefix=$INSTALL_PATH --target=$TARGET $CONFIGURATION_OPTIONS
    make $PARALLEL_MAKE
    make install
    cd ..
else
    # Step 4. Standard C Library Headers and Startup Files
    mkdir -p build-glibc
    cd build-glibc
    ../$GLIBC_VERSION/configure --prefix=$INSTALL_PATH/$TARGET --build=$MACHTYPE --host=$TARGET --target=$TARGET --with-headers=$INSTALL_PATH/$TARGET/include $CONFIGURATION_OPTIONS libc_cv_forced_unwind=yes
    make install-bootstrap-headers=yes install-headers
    make $PARALLEL_MAKE csu/subdir_lib
    install csu/crt1.o csu/crti.o csu/crtn.o $INSTALL_PATH/$TARGET/lib
    $TARGET-gcc -nostdlib -nostartfiles -shared -x c /dev/null -o $INSTALL_PATH/$TARGET/lib/libc.so
    touch $INSTALL_PATH/$TARGET/include/gnu/stubs.h
    cd ..

    # Step 5. Compiler Support Library
    cd build-gcc
    make $PARALLEL_MAKE all-target-libgcc
    make install-target-libgcc
    cd ..

    # Step 6. Standard C Library & the rest of Glibc
    cd build-glibc
    make $PARALLEL_MAKE
    make install
    cd ..
fi

# Step 7. Standard C++ Library & the rest of GCC
cd build-gcc
make $PARALLEL_MAKE all
make install
cd ..

cd $START_DIR
echo 'Success!'
