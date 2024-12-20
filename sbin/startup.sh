#!/bin/sh

#===========================================================================================
# 环境变量
#===========================================================================================

APP_NAME="<按实际情况填写>"
APP_FORMAT="jar"

ENABLE_GC_LOG="false"
GC_LOG_DIR="<按需要填写>"

ENABLE_HEAP_DUMP="false"
HEAP_DUMP_DIR="<按需要填写>"

#===========================================================================================
# 找到应用程序安装目录
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
  if [ -n "$JAVA_HOME" ]; then
    JAVA_HOME=$JAVA_HOME
    return
  fi

  case "$(uname)" in
  Darwin)
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

#===========================================================================================
# JVM参数 按需要更改
#===========================================================================================

JAVA_OPT="${JAVA_OPT} -server -Xmixed"
JAVA_OPT="${JAVA_OPT} -XX:-PrintCommandLineFlags -XX:-PrintFlagsInitial -XX:-PrintFlagsFinal"
JAVA_OPT="${JAVA_OPT} -XX:ThreadStackSize=512k"
JAVA_OPT="${JAVA_OPT} -XX:InitialHeapSize=1g -XX:MinHeapSize=1g -XX:NewRatio=2 -XX:SurvivorRatio=8 -XX:+UseTLAB"
JAVA_OPT="${JAVA_OPT} -XX:MetaspaceSize=128m -XX:MaxMetaspaceSize=320m -XX:+UseCompressedOops"
JAVA_OPT="${JAVA_OPT} -XX:MaxDirectMemorySize=1g"
JAVA_OPT="${JAVA_OPT} -XX:+UseG1GC -XX:MaxGCPauseMillis=300"
JAVA_OPT="${JAVA_OPT} -XX:+UsePerfData"

# 堆内存Dump
if [ x"$ENABLE_HEAP_DUMP" = "xtrue" ]; then
  JAVA_OPT="${JAVA_OPT} -XX:+HeapDumpOnOutOfMemoryError -XX:+HeapDumpBeforeFullGC -XX:HeapDumpPath=${HEAP_DUMP_DIR}/${APP_NAME}.hprof"
fi

# GC日志
if [ x"$ENABLE_GC_LOG" = "xtrue" ]; then
  JAVA_OPT="${JAVA_OPT} -verbose:gc -Xlog:gc*:file=${GC_LOG_DIR}/${APP_NAME}_gc_%p_%t.log:time,tags:filecount=5,filesize=32M"
fi

#===========================================================================================
# System Properties
#===========================================================================================

JAVA_OPT_EXT="${JAVA_OPT_EXT} -Djava.security.egd=file:/dev/./urandom"
JAVA_OPT_EXT="${JAVA_OPT_EXT} -Dloader.system=false"
JAVA_OPT_EXT="${JAVA_OPT_EXT} -Dloader.path=${BASE_DIR}/libs,${BASE_DIR}/config"

if [ -e "$BASE_DIR/config/logback.xml" ]; then
  JAVA_OPT_EXT="${JAVA_OPT_EXT} -Dlogging.config=$BASE_DIR/config/logback.xml"
fi

#===========================================================================================
# 启动应用程序
#===========================================================================================

# 执行初始化脚本
if [ -x "$BASE_DIR/sbin/init.sh" ]; then
    "$BASE_DIR/sbin/init.sh"
fi

JAR_FILE="${BASE_DIR}/app/${APP_NAME}.${APP_FORMAT}"

${JAVA} \
  ${JAVA_OPT} \
  ${JAVA_OPT_EXT} \
  -cp "$CLASSPATH:${JAR_FILE}" \
  org.springframework.boot.loader.launch.PropertiesLauncher \
  "$@"
