#!/bin/sh

APP_NAME="myapp"
APP_FORMAT="jar"

ENABLE_GC_LOG="false"
GC_LOG_DIR=""

ENABLE_HEAP_DUMP="false"
HEAP_DUMP_DIR=""

#===========================================================================================
# Environment Setting
#===========================================================================================
export BASE_DIR=$(dirname "$0")/..

if [ -f "$BASE_DIR/sbin/env.sh" ]; then
    source "$BASE_DIR/sbin/env.sh"
fi

error_exit() {
  echo "ERROR: $1 !!"
  exit 1
}

find_java_home() {
  case "$(uname)" in
  Darwin)
    if [ -n "$JAVA_HOME" ]; then
      JAVA_HOME=$JAVA_HOME
      return
    fi
    JAVA_HOME=$(/usr/libexec/java_home)
    ;;
  *)
    JAVA_HOME=$(dirname $(dirname $(readlink -f $(which javac))))
    ;;
  esac
}

find_java_home

[ ! -e "$JAVA_HOME/bin/java" ] && JAVA_HOME=/usr/java
[ ! -e "$JAVA_HOME/bin/java" ] && JAVA_HOME=/opt/java
[ ! -e "$JAVA_HOME/bin/java" ] && JAVA_HOME=/opt/java-home
[ ! -e "$JAVA_HOME/bin/java" ] && JAVA_HOME=/opt/java_home
[ ! -e "$JAVA_HOME/bin/java" ] && error_exit "Please set the JAVA_HOME variable in your environment, We need java(x64)!"

export JAVA_HOME
export JAVA="$JAVA_HOME/bin/java"

choose_gc_log_directory() {
  if [ -n "$GC_LOG_DIR" ]; then
    GC_LOG_DIR=$GC_LOG_DIR
  else
    GC_LOG_DIR=$BASE_DIR
  fi
}

choose_heap_dump_directory() {
  if [ -n "$HEAP_DUMP_DIR" ]; then
    HEAP_DUMP_DIR=$HEAP_DUMP_DIR
  else
    HEAP_DUMP_DIR=$BASE_DIR
  fi
}

check_java_version() {
  # Example of JAVA_MAJOR_VERSION value : '1', '9', '10', '11', ...
  # '1' means releases before Java 9
  JAVA_MAJOR_VERSION=$("$JAVA" -version 2>&1 | awk -F '"' '/version/ {print $2}' | awk -F '.' '{print $1}')
  if [ -z "$JAVA_MAJOR_VERSION" ] || [ "$JAVA_MAJOR_VERSION" -lt "17" ]; then
    error_exit "Oops! We need Java17+"
  fi
}

check_java_version
choose_gc_log_directory
choose_heap_dump_directory

JAVA_OPT="${JAVA_OPT} -server -Xmixed"
JAVA_OPT="${JAVA_OPT} -XX:+PrintCommandLineFlags -XX:-PrintFlagsInitial -XX:+PrintFlagsFinal"
JAVA_OPT="${JAVA_OPT} -XX:ThreadStackSize=512k"
JAVA_OPT="${JAVA_OPT} -XX:InitialHeapSize=1g -XX:MinHeapSize=1g -XX:NewRatio=2 -XX:SurvivorRatio=8 -XX:+UseTLAB"
JAVA_OPT="${JAVA_OPT} -XX:MetaspaceSize=128m -XX:MaxMetaspaceSize=320m"
JAVA_OPT="${JAVA_OPT} -XX:MaxDirectMemorySize=1g"
JAVA_OPT="${JAVA_OPT} -XX:+UseG1GC -XX:MaxGCPauseMillis=200"
JAVA_OPT="${JAVA_OPT} -XX:+UsePerfData"

if [ x"$ENABLE_HEAP_DUMP" = "xtrue" ]; then
  JAVA_OPT="${JAVA_OPT} -XX:+HeapDumpOnOutOfMemoryError -XX:+HeapDumpBeforeFullGC -XX:HeapDumpPath=${HEAP_DUMP_DIR}/${APP_NAME}.hprof"
fi

if [ x"$ENABLE_GC_LOG" = "xtrue" ]; then
  JAVA_OPT="${JAVA_OPT} -verbose:gc -Xlog:gc*:file=${GC_LOG_DIR}/${APP_NAME}_gc_%p_%t.log:time,tags:filecount=5,filesize=32M"
fi

JAVA_OPT_EXT="-Djava.security.egd=file:/dev/./urandom"

if [ -f "$BASE_DIR/sbin/before-startup.sh" ]; then
    /bin/sh "$BASE_DIR/sbin/before-startup.sh"
fi

#===========================================================================================
# Starup the Shit
#===========================================================================================
"$JAVA" ${JAVA_OPT} ${JAVA_OPT_EXT} -jar ${BASE_DIR}/app/${APP_NAME}.${APP_FORMAT} "$@"
