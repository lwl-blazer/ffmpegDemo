#!/bin/sh

VERSION="1.0.2r" #指明openssl的版本信息，比如下载的是openssl-1.0.1h.tar.gz那么对于就填写1.0.1h

SDKVERSION="12.2" #指明ios sdk的版本号，目前最新的是7.1，不清楚的同学可以 ls /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS7.1.sdk/ 一下看看自己的iPhoneOS7.1.sdk是不是7.1


CURRENTPATH=`pwd`
ARCHS="i386 armv7 armv7s arm64"
BUILDPATH="${CURRENTPATH}/build"
LIBPATH="${CURRENTPATH}/lib"
INCLUDEPATH="${CURRENTPATH}/include"
SRCPATH="${CURRENTPATH}/src"
LIBSSL="libssl.a"
LIBCRYPTO="libcrypto.a"
DEVELOPER=`xcode-select -print-path`

if [ ! -d "$DEVELOPER" ]; then
echo "xcode path is not set correctly $DEVELOPER does not exist (most likely because of xcode > 4.3)"
echo "run"
echo "sudo xcode-select -switch <xcode path>"
echo "for default installation:"
echo "sudo xcode-select -switch /Applications/Xcode.app/Contents/Developer"
exit 1
fi

set -e
if [ ! -e openssl-${VERSION}.tar.gz ]; then
echo "Downloading openssl-${VERSION}.tar.gz"
curl -O http://www.openssl.org/source/openssl-${VERSION}.tar.gz
else
echo "Using openssl-${VERSION}.tar.gz"

# Remove the source directory if already exist
rm -rf "${SRCPATH}/openssl-${VERSION}"
fi

mkdir -p "${SRCPATH}"
mkdir -p "${BUILDPATH}"
mkdir -p "${LIBPATH}"
mkdir -p "${INCLUDEPATH}"

tar zxf openssl-${VERSION}.tar.gz -C "${SRCPATH}"
cd "${SRCPATH}/openssl-${VERSION}"

LIBSSL_REPO=""
LIBCRYPTO_REPO=""

for ARCH in ${ARCHS}
do
if [ "${ARCH}" == "i386" ];
then
PLATFORM="iPhoneSimulator"
else
sed -ie "s!static volatile sig_atomic_t intr_signal;!static volatile intr_signal;!" "crypto/ui/ui_openssl.c"
PLATFORM="iPhoneOS"
fi
export CROSS_TOP="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
export CROSS_SDK="${PLATFORM}${SDKVERSION}.sdk"
export BUILD_TOOLS="${DEVELOPER}"

echo "Building openssl-${VERSION} for ${PLATFORM} ${SDKVERSION} ${ARCH}"
echo "Please stand by..."

export CC="${BUILD_TOOLS}/usr/bin/gcc -arch ${ARCH}"

OUTPATH="${BUILDPATH}/openssl-${PLATFORM}${SDKVERSION}-${ARCH}.sdk"
mkdir -p "${OUTPATH}"
LOG="${OUTPATH}/build-openssl-${VERSION}.log"

if [[ "$VERSION" =~ 1.0.0. ]]; then
./Configure BSD-generic32 --openssldir="${OUTPATH}" > "${LOG}" 2>&1
else
./Configure iphoneos-cross --openssldir="${OUTPATH}" > "${LOG}" 2>&1
fi

# add -isysroot to CC=
sed -ie "s!^CFLAG=!CFLAG=-isysroot ${CROSS_TOP}/Platforms/${PLATFORM}.platform/Developer/SDKs/${CROSS_SDK} -miphoneos-version-min=7.0 !" "Makefile"

make >> "${LOG}" 2>&1
make install >> "${LOG}" 2>&1
make clean >> "${LOG}" 2>&1

LIBSSL_REPO+="${OUTPATH}/lib/${LIBSSL} "
LIBCRYPTO_REPO+="${OUTPATH}/lib/${LIBCRYPTO} "
done

echo "Build library..."
lipo -create ${LIBSSL_REPO}-output ${LIBPATH}/${LIBSSL}
lipo -create ${LIBCRYPTO_REPO}-output ${LIBPATH}/${LIBCRYPTO}

cp -R ${BUILDPATH}/openssl-iPhoneSimulator${SDKVERSION}-i386.sdk/include/openssl ${INCLUDEPATH}/
echo "Building done."
echo "Cleaning up..."
rm -rf ${SRCPATH}/openssl-${VERSION}
echo "Done."
