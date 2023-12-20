#!/bin/sh

PACKAGE_NAME="solr"
# upstream solr version
SOLR_VERSION="6.6.5"
# serial number for locally applied patch
PATCH_NUMBER=3
SOLR_DIR="${PACKAGE_NAME}-${SOLR_VERSION}"
SOLR_ZIP="${PACKAGE_NAME}-${SOLR_VERSION}.zip"
ARCH="all"
ROOT_DIR="${PACKAGE_NAME}_${SOLR_VERSION}-${PATCH_NUMBER}_${ARCH}"
DEB="${ROOT_DIR}.deb"

# use consistant build env
# https://wiki.debian.org/ReproducibleBuilds/Howto
# especially important are the notes on `unzip` and `umask`
export LC_ALL=C
export TZ=UTC
umask 0022

export SOURCE_DATE_EPOCH=`git show --no-patch --format=%ct`
# use POSIX touch syntax for maximum compatibility
SOURCE_DATE_TOUCH_STAMP_FMT=`git show --no-patch --format=%cd --date=format:%C%y%m%d%H%M.%S`
TOUCH_CMD="touch -c -t ${SOURCE_DATE_TOUCH_STAMP_FMT}"

if [ ! -f $SOLR_ZIP ]; then
  URL="https://archive.apache.org/dist/lucene/solr/${SOLR_VERSION}/${SOLR_ZIP}"
  echo "Fetching: ${URL}"
  wget -q $URL
fi

if [ -d $SOLR_DIR ]; then
  echo  "Extracted solr already present, removing"
  rm -r $SOLR_DIR
fi

if [ -d $ROOT_DIR ]; then
  echo  "Build dir already present, removing"
  rm -r $ROOT_DIR
fi

if command -v shasum > /dev/null; then
  SHA_CMD="shasum"
elif command -v sha1sum > /dev/null; then
  SHA_CMD="sha1sum"
else
  echo >&2 "shasum/sha1sum not found"
  exit 1
fi

if ! $SHA_CMD -c "checksum/${SOLR_ZIP}.sha1"; then
  exit 1
fi

echo "Extracting: ${SOLR_ZIP}"
unzip -q $SOLR_ZIP || exit 1

patch --forward --reject-file=- $SOLR_DIR/bin/solr bin-solr.diff || exit 1
$TOUCH_CMD $SOLR_DIR/bin/solr
$TOUCH_CMD $SOLR_DIR/bin/

echo "Moving $SOLR_DIR to $ROOT_DIR/opt/solr"
mkdir -p $ROOT_DIR/opt
mv $SOLR_DIR $ROOT_DIR/opt/solr

mkdir $ROOT_DIR/DEBIAN
CONTROL_FILE=$ROOT_DIR/DEBIAN/control
echo "Generating .deb metadata: ${CONTROL_FILE}"
echo "Package: solr"                                                           >> $CONTROL_FILE
echo "Version: ${SOLR_VERSION}-${PATCH_NUMBER}"                                >> $CONTROL_FILE
echo "Architecture: all"                                                       >> $CONTROL_FILE
echo "Section: web"                                                            >> $CONTROL_FILE
echo "Priority: optional"                                                      >> $CONTROL_FILE
echo 'Maintainer: "University of Michigan Library IT" <lit-noreply@umich.edu>' >> $CONTROL_FILE
echo "Depends: default-jre-headless | java8-runtime-headless | java8-runtime"  >> $CONTROL_FILE
echo "Description: Enterprise search server based on Lucene3 - common files"   >> $CONTROL_FILE
echo " Solr is an open source enterprise search server based on the Lucene"    >> $CONTROL_FILE
echo " Java search library, with XML/HTTP and JSON APIs, hit highlighting,"    >> $CONTROL_FILE
echo " faceted search, caching, replication, and a web administration"         >> $CONTROL_FILE
echo " interface."                                                             >> $CONTROL_FILE
echo                                                                           >> $CONTROL_FILE

if command -v dpkg-deb > /dev/null; then
  $TOUCH_CMD $ROOT_DIR/opt
  $TOUCH_CMD $ROOT_DIR
  $TOUCH_CMD $CONTROL_FILE
  $TOUCH_CMD $ROOT_DIR/DEBIAN

  dpkg-deb -Zxz --build --root-owner-group $ROOT_DIR
  $SHA_CMD $DEB

  if ! [ -z $GITHUB_ENV ]; then
    # publish the deb name to GH env if we're running in a GH Action
    echo DEB=$DEB >> $GITHUB_ENV
  fi
else
  echo >&2 "dpkg-deb not found"
  exit 1
fi
