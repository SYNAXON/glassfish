#!/bin/bash

VER="0.2.7"

# check the --fqdn version, if it's absent fall back to hostname
HOSTNAME=$(hostname --fqdn 2>/dev/null)
if [[ $HOSTNAME == "" ]]; then
  HOSTNAME=$(hostname)
fi

# common ############################################################### START #
sp="/-\|"
log="${PWD}/`basename ${0}`.log"

function error_msg() {
    local MSG="${1}"
    echo "${MSG}"
    exit 1
}

function cecho() {
    echo -e "[x] $1"
    echo -e "$1" >>"$log"
    tput sgr0;
}


function check_root() {
    if [ "$(id -u)" != "0" ]; then
        error_msg "ERROR! You must execute the script as the 'root' user."
    fi
}

function check_sudo() {
    if [ ! -n ${SUDO_USER} ]; then
        error_msg "ERROR! You must invoke the script using 'sudo'."
    fi
}

function check_ubuntu() {
    if [ "${1}" != "" ]; then
        SUPPORTED_CODENAMES="${1}"
    else
        SUPPORTED_CODENAMES="all"
    fi

    # Source the lsb-release file.
    lsb

    # Check if this script is supported on this version of Ubuntu.
    if [ "${SUPPORTED_CODENAMES}" == "all" ]; then
        SUPPORTED=1
    else
        SUPPORTED=0
        for CHECK_CODENAME in `echo ${SUPPORTED_CODENAMES}`
        do
            if [ "${LSB_CODE}" == "${CHECK_CODENAME}" ]; then
                SUPPORTED=1
            fi
        done
    fi

    if [ ${SUPPORTED} -eq 0 ]; then
        error_msg "ERROR! ${0} is not supported on this version of Ubuntu."
    fi
}

function lsb() {
    local CMD_LSB_RELEASE=`which lsb_release`
    if [ "${CMD_LSB_RELEASE}" == "" ]; then
	    error_msg "ERROR! 'lsb_release' was not found. I can't identify your distribution."
    fi
    LSB_ID=`lsb_release -i | cut -f2 | sed 's/ //g'`
    LSB_REL=`lsb_release -r | cut -f2 | sed 's/ //g'`
    LSB_CODE=`lsb_release -c | cut -f2 | sed 's/ //g'`
    LSB_DESC=`lsb_release -d | cut -f2`
    LSB_ARCH=`dpkg --print-architecture`
    LSB_MACH=`uname -m`
    LSB_NUM=`echo ${LSB_REL} | sed s'/\.//g'`
}

function apt_update() {
    ncecho " [x] Update package list "
    apt-get -y update >>"$log" 2>&1 &
    pid=$!;progress $pid
}

#### COMMON ENDE ####

check_root
check_sudo
check_ubuntu "all"

GLASSFISH_USER=$1
GLASSFISH_PASS=$2
GLASSFISH_ADMIN=$3
GLASSFISH_ADMIN_PASSWORD=$4
GLASSFISH_ADMIN_PORT=4848
GLASSFISH_VERSION=3.1.2.2
GLASSFISH_PORT=8080
GLASSFISH_HOME="/opt/glassfish3"
GLASSFISH_DOMAIN="domain1"
PASSWORD_FILE=gfpass
ASADMIN="asadmin --user $GLASSFISH_ADMIN --passwordfile $PASSWORD_FILE "
PROFILE="/etc/profile"

cecho "creating glassfish user"
useradd -m -p $2 $1

cecho "installing java as local apt-get repo"
bash ./java/oab-java.sh -s -7

apt_update

apt-get -y install oracle-java7-jdk >>"$log" 2>&1 &

cecho "create JAVA_HOME"
export JAVA_HOME="/usr/lib/jvm/java-7-oracle"
echo "export JAVA_HOME=\"/usr/lib/jvm/java-7-oracle\"" >> $PROFILE

cecho "download glassfish"
wget http://download.java.net/glassfish/$GLASSFISH_VERSION/release/glassfish-$GLASSFISH_VERSION-unix.sh
chmod 755 glassfish-$GLASSFISH_VERSION-unix.sh

cecho "create glassfish answer file"
rm -f answer.file > /dev/null 2>&1
echo "Domain.Configuration.ADMIN_PASSWORD=$GLASSFISH_ADMIN_PASSWORD" >> answer.file
echo "Domain.Configuration.ADMIN_PASSWORD_REENTER=$GLASSFISH_ADMIN_PASSWORD" >> answer.file
echo "Domain.Configuration.ADMIN_PORT=$GLASSFISH_ADMIN_PORT" >> answer.file
echo "Domain.Configuration.ADMIN_USER=$GLASSFISH_ADMIN" >> answer.file
echo "Domain.Configuration.DOMAIN_NAME=$GLASSFISH_DOMAIN" >> answer.file
echo "Domain.Configuration.HTTP_PORT=$GLASSFISH_PORT" >> answer.file
echo "InstallHome.directory.INSTALL_HOME=$GLASSFISH_HOME" >> answer.file
echo "UpdateTool.Configuration.ALLOW_UPDATE_CHECK=true" >> answer.file
echo "UpdateTool.Configuration.BOOTSTRAP_UPDATETOOL=true" >> answer.file
echo "UpdateTool.Configuration.PROXY_HOST=" >> answer.file
echo "UpdateTool.Configuration.PROXY_PORT=8888" >> answer.file

./glassfish-$GLASSFISH_VERSION-unix.sh -s -a answer.file

cecho "create DAS password file"
rm -f $PASSWORD_FILE > /dev/null 2>&1
echo "AS_ADMIN_PASSWORD=adminadmin" >> $PASSWORD_FILE

cecho "configure glassfish"
$ASADMIN create-service --serviceuser $GLASSFISH_USER

cecho "start DAS of Glassfish"
$ASADMIN start-domain

cecho "securing DAS"
$ASADMIN enable-secure-admin 


