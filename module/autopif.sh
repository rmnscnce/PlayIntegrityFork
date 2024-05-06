#!/system/bin/sh

if [ "$USER" != "root" -o "$(whoami 2>/dev/null)" != "root" ]; then
  echo "autopif: need root permissions";
  exit 1;
fi;

echo "Xiaomi.eu pif.json extractor script \
  \n  by osm0sis @ xda-developers";

case "$0" in
  *.sh) DIR="$0";;
  *) DIR="$(lsof -p $$ 2>/dev/null | grep -o '/.*autopif.sh$')";;
esac;
DIR=$(dirname "$(readlink -f "$DIR")");

if [ "$DIR" = /data/adb/modules/playintegrityfix ]; then
  DIR=$DIR/autopif;
  mkdir -p $DIR;
fi;
cd "$DIR";

if ! which wget >/dev/null; then
  if [ -f /data/adb/magisk/busybox ]; then
    wget() { /data/adb/magisk/busybox wget "$@"; }
  elif [ -f /data/adb/ksu/bin/busybox ]; then
    wget() { /data/adb/ksu/bin/busybox wget "$@"; }
  elif [ -f /data/adb/ap/bin/busybox ]; then
    wget() { /data/adb/ap/bin/busybox wget "$@"; }
  else
    echo "autopif: wget not found";
    exit 1;
  fi;
fi;

item() { echo "\n- $@"; }

if [ ! -f apktool_2.0.3-dexed.jar ]; then
  item "Downloading Apktool ...";
  wget --no-check-certificate -O apktool_2.0.3-dexed.jar https://github.com/osm0sis/APK-Patcher/raw/master/tools/apktool_2.0.3-dexed.jar 2>&1 || exit 1;
fi;

item "Finding latest APK from RSS feed ...";
APKURL=$(wget -q -O - --no-check-certificate https://sourceforge.net/projects/xiaomi-eu-multilang-miui-roms/rss?path=/xiaomi.eu/Xiaomi.eu-app | grep -o '<link>.*' | head -n 2 | tail -n 1 | sed 's;<link>\(.*\)</link>;\1;g');
APKNAME=$(echo $APKURL | sed 's;.*/\(.*\)/download;\1;g');
echo "$APKNAME";

if [ ! -f $APKNAME ]; then
  item "Downloading $APKNAME ...";
  wget --no-check-certificate -O $APKNAME $APKURL 2>&1 || exit 1;
fi;

OUT=$(basename $APKNAME .apk);
if [ ! -d $OUT ]; then
  item "Extracting APK files with Apktool ...";
  DALVIKVM=dalvikvm;
  [ "$TERMUX_VERSION" -a "$PREFIX" ] && DALVIKVM=$PREFIX/bin/dalvikvm;
  $DALVIKVM -Xnoimage-dex2oat -cp apktool_2.0.3-dexed.jar brut.apktool.Main d -f --no-src -p $OUT -o $OUT $APKNAME || exit 1;
fi;

item "Converting inject_fields.xml to pif.json ...";
(echo '{';
grep -o '<field.*' $OUT/res/xml/inject_fields.xml | sed 's;.*name=\(".*"\) type.* value=\(".*"\).*;  \1: \2,;g';
echo '  "FIRST_API_LEVEL": "25",' ) | sed '$s/,/\n}/' | tee pif.json;

if [ -f /data/adb/modules/playintegrityfix/migrate.sh ]; then
  item "Converting pif.json to custom.pif.json with migrate.sh:";
  rm -f custom.pif.json;
  sh /data/adb/modules/playintegrityfix/migrate.sh -i pif.json;
  cat custom.pif.json;
fi;

if [ "$DIR" = /data/adb/modules/playintegrityfix/autopif ]; then
  item "Installing new json ...";
  if [ -f /data/adb/modules/playintegrityfix/migrate.sh ]; then
    cp -fv custom.pif.json "$DIR/..";
  else
    cp -fv pif.json "$DIR/..";
  fi;
fi;

if [ -f /data/adb/modules/playintegrityfix/killgms.sh ]; then
  item "Killing any running GMS DroidGuard process ...";
  sh /data/adb/modules/playintegrityfix/killgms.sh 2>&1;
fi;
