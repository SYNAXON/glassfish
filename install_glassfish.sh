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
    echo -e "$1"
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



