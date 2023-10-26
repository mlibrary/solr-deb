#!/bin/sh

PACKAGE_NAME="solr"
# upstream solr version
SOLR_VERSION="6.6.5"
# serial number for locally applied patch
PATCH_NUMBER=1
SOLR_DIR="${PACKAGE_NAME}-${SOLR_VERSION}"
SOLR_ZIP="${PACKAGE_NAME}-${SOLR_VERSION}.zip"
ARCH="all"
ROOT_DIR="${PACKAGE_NAME}_${SOLR_VERSION}-${PATCH_NUMBER}_${ARCH}"
DEB="${ROOT_DIR}.deb"

# Always use 24h clock
export LANG=C
# Prevent unzip from setting wrong timestamps
export TZ=UTC

if git diff-index --quiet HEAD --
then
  BUILD_TIME=`git show --no-patch --format=%ct`
else
  echo >&2 "WARNING: you have uncommited changes, this build will not be reproducible!"
  BUILD_TIME=`date '+%s'`
fi
DATE=`date -d @${BUILD_TIME}`
echo "Setting build time: ${BUILD_TIME} (${DATE})"
TOUCH_CMD="touch --no-create --date=@${BUILD_TIME}"

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

if ! sha1sum -c "checksum/${SOLR_ZIP}.sha1"; then
  exit 1
fi

echo "Extracting: ${SOLR_ZIP}"
unzip -q $SOLR_ZIP

patch --forward --reject-file=- $SOLR_DIR/bin/solr bin-solr.diff
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
echo "Depends: default-jre-headless"                                           >> $CONTROL_FILE
echo "Description: Enterprise search server based on Lucene3 - common files"   >> $CONTROL_FILE
echo " Solr is an open source enterprise search server based on the Lucene"    >> $CONTROL_FILE
echo " Java search library, with XML/HTTP and JSON APIs, hit highlighting,"    >> $CONTROL_FILE
echo " faceted search, caching, replication, and a web administration"         >> $CONTROL_FILE
echo " interface."                                                             >> $CONTROL_FILE
echo                                                                           >> $CONTROL_FILE

if which dpkg-deb > /dev/null; then
  $TOUCH_CMD $ROOT_DIR/opt
  $TOUCH_CMD $ROOT_DIR
  $TOUCH_CMD $CONTROL_FILE
  $TOUCH_CMD $ROOT_DIR/DEBIAN

  SOURCE_DATE_EPOCH=$BUILD_TIME dpkg-deb -Zxz --build --root-owner-group $ROOT_DIR
  sha1sum $DEB

  if ! [ -z $GITHUB_ENV ]; then
    # publish the deb name to GH env if we're running in a GH Action
    echo DEB=$DEB >> $GITHUB_ENV
  fi
else
  echo >&2 "dpkg-deb not found"
  exit 1
fi
