#!/usr/bin/env bash

# Docker build script
# Copyright (C) 2021 Pakaoraki <pakaoraki@gmx.com>
#
# Based on
# https://github.com/lineageos4microg/docker-lineage-cicd 
#   by Julian Xhokaxhiu, Nicola Corna <nicola@corna.info>
#
# Script-template from:
# https://github.com/ralish/bash-script-template/blob/main/template.sh
#   by Ralish
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

###############################################################################
#                                                                             #
#                                  INIT.SH                                    #
#                                                                             #
###############################################################################

#-----------------------------------------------------------------------------#
#     Author(s): Pakaoraki
#     Version: 1.0
#     Date: 19/07/2021
#     Last Modif. Date: 24/07/2021
#     Description: Init script for buildind Lineageos.
#                 From https://github.com/lineageos4microg/docker-lineage-cicd
#
#-----------------------------------------------------------------------------#

###############################################################################
#     INIT & IMPORT
###############################################################################

# A better class of script...
#----------------------------
    # Enable xtrace if the DEBUG environment variable is set
    #if [[ ${DEBUG-} =~ ^1|yes|true$ ]]; then
    if [[ $TRACE_MODE = true ]]; then
        set -o xtrace       # Trace the execution of the script (debug)
    fi

    # Only enable these shell behaviours if we're not being sourced
    # Approach via: https://stackoverflow.com/a/28776166/8787985
    if ! (return 0 2> /dev/null); then
        # A better class of script...
        set -o errexit      # Exit on most errors (see the manual)
        set -o nounset      # Disallow expansion of unset variables
        set -o pipefail     # Use last non-zero exit code in a pipeline
    fi

    # Enable errtrace or the error trap handler will not work as expected
    set -o errtrace         # Ensure the error trap handler is inherited

# Import sources
#---------------------------- 
    # shellcheck source=source.sh
    source "$(dirname "${BASH_SOURCE[0]}")/source.sh"
    
###############################################################################
#     CONST
###############################################################################
    
# Common
#----------------------------
    VERSION="1.0"

# Path
#----------------------------
    PATH_USERSCRIPTS="/root/userscripts"
    GEN_KEY_SCRIPT="/root/make_key"
    BUILD_SCRIPT="/root/build.sh"

# Logs
#----------------------------
    DOCKER_LOG="/var/log/docker.log"
    LOG_NAME="Lineage_docker_$(date +%Y%m%d).log"
    LOG_FILE=$LOGS_DIR/$LOG_NAME


###############################################################################
#     VARIABLES
###############################################################################

# Common
#----------------------------
    PRINT_TERMINAL=true
    SILENT_REPO=""
    SILENT_BUILD=""
    SHOW_ERRORS_ONLY=""
    EXIT_CODE=""
    
###############################################################################
#     FUNCTIONS
###############################################################################


# script_usage()
#----------------------------
# DESC: Usage help
# ARGS: None
# OUTS: None
function script_usage() {
    cat << EOF
Usage:
     -h|--help                  Displays this help
     -v|--version               Displays version
     -V|--verbose               Displays verbose output
     -D|--debug                 Displays debug output
    -nc|--no-colour             Disables colour output
    -cr|--cron                  Run silently unless we encounter an error
EOF
}

# parse_params()
#----------------------------
# DESC: Parameter parser
# ARGS: $@ (optional): Arguments provided to the script
# OUTS: Variables indicating command-line parameters and options
function parse_params() {
    local param
    while [[ $# -gt 0 ]]; do
        param="$1"
        shift
        case $param in
            -h|--help)
                script_usage
                exit 0
                ;;
            -v|--version)
                echo "Version $VERSION"
                exit 0;
                ;;        
            -V|--verbose)
                verbose=true
                ;;
            -D|--debug)
                debug=true
                ;;
            -nc|--no-colour)
                no_colour=true
                ;;
            -cr|--cron)
                cron=true
                ;;
            *)
                script_exit "Invalid parameter was provided: $param" 1
                ;;
        esac
    done
}

# make_keys()
#----------------------------
# DESC: Usage 'make_keys <name> <subject> [<keytype>]'
#       Creates <name>.pk8 key and <name>.x509.pem cert. Cert contains the
#       given <subject>. A keytype of "rsa" or "ec" is accepted.
# ARGS: $1 (required): name.
#       $2 (required): subject.
#       $3 (optional): password.
#       $4 (optional): keytype [rsa|ec].
# OUTS: Variables indicating command-line parameters and options

function make_keys() {

    # Check 
    if [[ "$#" -lt 2 || "$#" -gt 4 ]]; then
        print_log "makekeys: wrong number of arguments" "ERROR"
        script_exit "wrong args in makekeys" 9
    fi

    # local
    local name=$1
    local subject=$2    
    local keytype="rsa" # Default
    local password=""
    
    # Get password if provided
    [[ "$#" -eq 3 ]] && password=$3
    
    # Get keytype if provided
    [[ "$#" -eq 4 ]] && keytype=$4   
    
    # Debug
    print_log "Name: ------ $name"      "DEBUG"
    print_log "Subject: --- $subject"   "DEBUG"  
    print_log "Password: -- $password"  "DEBUG"  
    print_log "keytype: --- $keytype"   "DEBUG"  
    
    if [[ -e "$name.pk8" || -e "$name.x509.pem" ]]; then
        print_log "$name.pk8 and/or $name.x509.pem already exist !" "WARN"
        print_log "Please delete them first if you want to replace them." "WARN"

        # Exit function
        return 1
    fi

    # Use named pipes to connect get the raw RSA private key to the cert-
    # and .pk8-creating programs, to avoid having the private key ever
    # touch the disk.

    tmpdir=$(mktemp -d)
    trap 'rm -rf ${tmpdir}; echo; exit 1' EXIT INT QUIT

    one=${tmpdir}/one
    two=${tmpdir}/two
    mknod "${one}" p
    mknod "${two}" p
    chmod 0600 "${one}" "${two}"
    
    #print_log "Enter password for '$name' " "INFO"
    #read -rp "(blank for none; password will be visible): " \
    #   password

    if [[ "${keytype}" = "rsa" ]]; then
        ( openssl genrsa -f4 2048 | tee "${one}" > "${two}" ) &> /dev/null &
        hash="-sha256"
    elif [ "${keytype}" = "ec" ]; then
        ( openssl ecparam -name prime256v1 -genkey -noout \
            | tee "${one}" > "${two}" ) &> /dev/null &
        hash="-sha256"
    else
        print_log "makekeys: Only accepts RSA or EC keytypes." "ERROR"
        script_exit "makekeys failed" 9
    fi

    openssl req -new -x509 ${hash} -key "${two}" -out "$name".x509.pem \
        -days 10000 -subj "$2" &> /dev/null &

    if [ "${password}" == "" ]; then
        print_log " makekeys: creating ${name}.pk8 with no password" "INFO"
        openssl pkcs8 \
            -in "${one}" \
            -topk8 -outform DER \
            -out "$name".pk8 \
            -nocrypt \
            &> /dev/null || EXIT_CODE=$?           
    else
        print_log " makekeys: creating ${name}.pk8 with given password." "INFO"
        export password
        openssl pkcs8 \
            -in "${one}" \
            -topk8 -outform DER \
            -out "$name".pk8 \
            -passout env:password \
            &> /dev/null || EXIT_CODE=$? 
        unset password
    fi
    
    # check openssl cmd
    [[ $EXIT_CODE -ne 0 ]] \
        && print_log "ERROR: failed creating ${name}.pk8 !"  "ERROR" \
        && script_exit "makekeys failed" 9 
    
    # Wait for previous background openssl command to end
    wait
    wait
}

###############################################################################
#     MAIN
###############################################################################


# DESC: Main control flow
# ARGS: $@ (optional): Arguments provided to the script
# OUTS: None
function main() {

    # Init
    #----------------------------
    trap script_trap_err ERR
    trap script_trap_exit EXIT

    script_init "$@"
    parse_params "$@"
    cron_init
    colour_init
    #lock_init system

    # logs rotate
    log_rotate LOG_FILE

    # Debug
    #---------------------------- 

    # Display debug info 
    print_log "------------------------------------------------" "DEBUG"
    print_log " -\$DEBUG_MODE: $DEBUG_MODE "                     "DEBUG"
    print_log " -\$TRACE_MODE: $TRACE_MODE "                     "DEBUG"
    print_log " -\$TEST_SCRIPT: $TEST_SCRIPT "                   "DEBUG"
    print_log " -\$PRINT_MODE: $PRINT_MODE "                     "DEBUG"
    print_log " -\$MIRROR_DIR: $MIRROR_DIR "                     "DEBUG"
    print_log " -\$SRC_DIR: $SRC_DIR "                           "DEBUG"
    print_log " -\$TMP_DIR: $TMP_DIR "                           "DEBUG"
    print_log " -\$CCACHE_DIR: $CCACHE_DIR "                     "DEBUG"
    print_log " -\$ZIP_DIR: $ZIP_DIR "                           "DEBUG"
    print_log " -\$LMANIFEST_DIR: $LMANIFEST_DIR "               "DEBUG"
    print_log " -\$KEYS_DIR: $KEYS_DIR "                         "DEBUG"
    print_log " -\$LOGS_DIR: $LOGS_DIR "                         "DEBUG"
    print_log " -\$USERSCRIPTS_DIR: $USERSCRIPTS_DIR "           "DEBUG"
    print_log " -\$DEBIAN_FRONTEND: $DEBIAN_FRONTEND "           "DEBUG"
    print_log " -\$USER: $USER "                                 "DEBUG"
    print_log " -\$TERM: $TERM "                                 "DEBUG"
    print_log " -\$USE_CCACHE: $USE_CCACHE "                     "DEBUG"
    print_log " -\$CCACHE_SIZE: $CCACHE_SIZE "                   "DEBUG"
    print_log " -\$CCACHE_EXEC: $CCACHE_EXEC "                   "DEBUG"
    print_log " -\$BRANCH_NAME: $BRANCH_NAME "                   "DEBUG"
    print_log " -\$DEVICE_LIST: $DEVICE_LIST "                   "DEBUG"
    print_log " -\$RELEASE_TYPE: $RELEASE_TYPE "                 "DEBUG"
    print_log " -\$BUILD_VARIANT: $BUILD_VARIANT "               "DEBUG"    
    print_log " -\$OTA_URL: $OTA_URL "                           "DEBUG"
    print_log " -\$USER_NAME: $USER_NAME "                       "DEBUG"
    print_log " -\$USER_MAIL: $USER_MAIL "                       "DEBUG"
    print_log " -\$INCLUDE_PROPRIETARY: $INCLUDE_PROPRIETARY "   "DEBUG"
    print_log " -\$BUILD_OVERLAY: $BUILD_OVERLAY "               "DEBUG"
    print_log " -\$LOCAL_MIRROR: $LOCAL_MIRROR "                 "DEBUG"
    print_log " -\$CLEAN_OUTDIR: $CLEAN_OUTDIR "                 "DEBUG"
    print_log " -\$CRONTAB_TIME: $CRONTAB_TIME "                 "DEBUG"
    print_log " -\$CLEAN_AFTER_BUILD: $CLEAN_AFTER_BUILD "       "DEBUG"
    print_log " -\$WITH_SU: $WITH_SU "                           "DEBUG"
    print_log " -\$ANDROID_JACK_VM_ARGS: $ANDROID_JACK_VM_ARGS " "DEBUG"
    print_log " -\$CUSTOM_PACKAGES: $CUSTOM_PACKAGES "           "DEBUG"
    print_log " -\$SIGN_BUILDS: $SIGN_BUILDS "                   "DEBUG"
    print_log " -\$KEYS_SUBJECT: $KEYS_SUBJECT "                 "DEBUG"
    print_log " -\$ZIP_SUBDIR: $ZIP_SUBDIR "                     "DEBUG"
    print_log " -\$LOGS_SUBDIR: $LOGS_SUBDIR "                   "DEBUG"
    print_log " -\$SIGNATURE_SPOOFING: $SIGNATURE_SPOOFING "     "DEBUG"
    print_log " -\$DELETE_OLD_ZIPS: $DELETE_OLD_ZIPS "           "DEBUG"
    print_log " -\$DELETE_OLD_LOGS: $DELETE_OLD_LOGS "           "DEBUG"
    print_log "------------------------------------------------" "DEBUG"  
    print_log " -\$BUILD_SCRIPT: $BUILD_SCRIPT "                 "DEBUG"  
    print_log " -\$GEN_KEY_SCRIPT: $GEN_KEY_SCRIPT "             "DEBUG"  
    print_log " -\$PATH_USERSCRIPTS: $PATH_USERSCRIPTS "         "DEBUG"  
    print_log " -\$DOCKER_LOG: $DOCKER_LOG "                     "DEBUG"
 
    # Check Env Variables
    #----------------------------
    
    # VARIANT
    [[ ! "$BUILD_VARIANT" =~ ^(user|userdebug|eng)$ ]] \
        && print_log "Wrong options for \$BUILD_VARIANT: $BUILD_VARIANT" "ERROR" \
        && script_exit "wrong options" 9
        
    # PRINT_MODE
    pattern_options='all|silent|no_repo|no_build|no_repo_build|build_errors'
    if [[ ! "$PRINT_MODE" =~ ^($pattern_options)$ ]]; then
        print_log "Wrong options for \$PRINT_MODE: $PRINT_MODE" "ERROR" \
        script_exit "wrong options" 9
    fi
    [[ "$PRINT_MODE" = "silent" ]] && PRINT_TERMINAL=false
    
    # TIMESTAMP
    ( [[ ! "$TIMESTAMP" = "+"* ]] || [[ ! "$TIMESTAMP" =~ "%" ]]) \
        && [[ "$TIMESTAMP" != "" ]]\
        && print_log "Wrong format for \$TIMESTAMP: $TIMESTAMP" "ERROR" \
        && script_exit "wrong options" 9
    
    
    # Init for build
    #----------------------------
    
    # Copy the user scripts
    mkdir -p $PATH_USERSCRIPTS
    cp -r "$USERSCRIPTS_DIR"/. $PATH_USERSCRIPTS
    find $PATH_USERSCRIPTS ! \
        -type d ! \
        -user root \
        -exec echo " {} is not owned by root, removing." \
        -exec rm {} \; \
        | print_log_catcher

    find $PATH_USERSCRIPTS ! \
        -type d \
        -perm /g=w,o=w \
        -exec echo " {} is writable by non-root users, removing." \
        -exec rm {} \; \
        | print_log_catcher

    # Initialize CCache
    if [ "$USE_CCACHE" = 1 ]; then
        print_log " >> Init CCACHE."    "INFO"
        ccache -M "$CCACHE_SIZE" 2>&1 | print_log_catcher
    fi

    # Initialize Git user information
    git config --global user.name  "$USER_NAME" 2>&1 | print_log_catcher
    git config --global user.email "$USER_MAIL" 2>&1 | print_log_catcher


    # Signing Build
    #----------------------------

    if [ "$SIGN_BUILDS" = true ]; then
        print_log " SIGN_BUILDS = true, build will be signed." "INFO"
        if [ -z "$(ls -A "$KEYS_DIR")" ]; then
            print_log " SIGN_BUILDS : no keys provided..."    "INFO"
            print_log "  => $KEYS_DIR: generating new keys !" "INFO"
            for c in releasekey platform shared media networkstack; do
                print_log " >> Generating $c keys..."     "INFO"
                make_keys "$KEYS_DIR/$c" "$KEYS_SUBJECT"
            done
        else
            for c in releasekey platform shared media networkstack; do
                for e in pk8 x509.pem; do
                    if [ ! -f "$KEYS_DIR/$c.$e" ]; then
                        
                        print_log " SIGN_BUILDS : $KEYS_DIR is not empty, OK." \
                            "INFO"
                        print_log " BUT : $KEYS_DIR/$c.$e is missing ! Abord !" \
                            "ERROR"
                        script_exit "$KEYS_DIR/$c.$e\" is missing" 1
                    fi
                done
            done
        fi
        for c in cyngn{-priv,}-app testkey; do
            for e in pk8 x509.pem; do
                if ! test -f "$KEYS_DIR/$c.$e"; then
                    ln -s releasekey.$e "$KEYS_DIR/$c.$e" \
                        2>&1 | print_log_catcher \
                        || EXIT_CODE=$?
                else
                    print_log "$KEYS_DIR/$c.$e already exist." "INFO"
                fi
            done
        done
    fi

    
    # Building
    #----------------------------

    # Check crontab
    if [ "$CRONTAB_TIME" = "now" ]; then
    
         # Execute build script
         $BUILD_SCRIPT        
    else
    
        # Initialize the cronjob
        cronFile=/tmp/buildcron
        printf "SHELL=/bin/bash\n" > $cronFile
        printenv -0 \
            | sed -e 's/=\x0/=""\n/g'  \
            | sed -e 's/\x0/\n/g' \
            | sed -e "s/_=/PRINTENV=/g" >> $cronFile
        crontab_cmd="\n$CRONTAB_TIME "
        crontab_cmd+="/usr/bin/flock -n /var/lock/build.lock $BUILD_SCRIPT"
        printf "$crontab_cmd >> $DOCKER_LOG 2>&1\n" >> $cronFile
        crontab $cronFile
        rm $cronFile

        # Run crond in foreground
        cron -f 2>&1
    fi
}

# START
#----------------------------

    # Invoke main with args if not sourced
    # Approach via: https://stackoverflow.com/a/28776166/8787985
    if ! (return 0 2> /dev/null); then
        main "$@"
    fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
