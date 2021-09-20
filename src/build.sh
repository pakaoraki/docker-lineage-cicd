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
#                                  BUILD.SH                                   #
#                                                                             #
###############################################################################

#-----------------------------------------------------------------------------#
#     Author(s): Pakaoraki
#     Version: 1.0
#     Date: 19/07/2021
#     Last Modif. Date: 19/07/2021
#     Description: Build script for Lineageos.
#                 From https://github.com/lineageos4microg/docker-lineage-cicd
#
#-----------------------------------------------------------------------------#

###############################################################################
#     INIT & IMPORT
###############################################################################

# A better class of script...
#----------------------------
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

# Logs
#----------------------------
    DOCKER_LOG="/var/log/docker.log"
    LOG_NAME="Lineage_docker_$(date +%Y%m%d).log"
    LOG_REPO="$LOGS_DIR/repo-$(date +%Y%m%d).log"
    LOG_BUILD="" # Init later     
    
# Path
#----------------------------
    PATH_USERSCRIPTS="/root/userscripts"    
    
# Custom scripts
#----------------------------
    CUSTOM_SCRIPT_BEGIN="$PATH_USERSCRIPTS/begin.sh"   # To exec at start  
    CUSTOM_SCRIPT_BEFORE="$PATH_USERSCRIPTS/before.sh" # To exec before building    
    CUSTOM_SCRIPT_AFTER="$PATH_USERSCRIPTS/end.sh"     # To exec after building
    CUSTOM_SCRIPT_TEST="$PATH_USERSCRIPTS/test.sh"     # For testing purpose    
    
    # Pre-build and post-build custom script (exec before each build)
    CUSTOM_SCRIPT_PRE_BUILD="$PATH_USERSCRIPTS/pre-build.sh"
    CUSTOM_SCRIPT_POST_BUILD="$PATH_USERSCRIPTS/post-build.sh"
    
# Github - Gitlab - sources
#----------------------------  
    GITHUB_LINEAGE_MIRR="https://github.com/LineageOS/mirror"
    
    GITHUB_MUPPET_SRC="https://raw.githubusercontent.com/"
    GITHUB_MUPPET_SRC+="TheMuppets/manifests/mirror/default.xml"
    
    GITLAB_MUPPET_SRC="https://gitlab.com/"
    GITLAB_MUPPET_SRC+="the-muppets/manifest/raw/mirror/default.xml"
    
    GITHUB_ANDROID="https://github.com/LineageOS/android.git"
    GITHUB_MUPPET_URL="https://raw.githubusercontent.com/TheMuppets/manifests"
    GITLAB_MUPPET_URL="https://gitlab.com/the-muppets/manifest/raw"    
    
# Patch MicroG spoofing
#----------------------------      
    PATCH_SIGN_SPOOF_DIR="/root/signature_spoofing_patches"
    OVERLAY_MICROG_FRAM="overlay/microg/frameworks/base/core/res/res/values/"    

# Sign Lineagesos build
#---------------------------- 

    # Lower than Android 10
    SIGN_BUILD_LT_Q="1s;^;PRODUCT_DEFAULT_DEV_CERTIFICATE "
    SIGN_BUILD_LT_Q+=":= user-keys/releasekey\nPRODUCT_OTA_PUBLIC_KEYS "
    SIGN_BUILD_LT_Q+=":= user-keys/releasekey\nPRODUCT_EXTRA_RECOVERY_KEYS "
    SIGN_BUILD_LT_Q+=":= user-keys/releasekey\n\n;"
    
    # Greater than Android 10            
    SIGN_BUILD_GT_Q="1s;^;PRODUCT_DEFAULT_DEV_CERTIFICATE "
    SIGN_BUILD_GT_Q+=":= user-keys/releasekey\nPRODUCT_OTA_PUBLIC_KEYS "
    SIGN_BUILD_GT_Q+=":= user-keys/releasekey\n\n;"

# OTA
#---------------------------- 
    OVERLAY_MICROG_UPDATER="overlay/microg/packages/apps/Updater/res/values/"
    OTA_UPDATER_STRING="packages/apps/Updater/res/values/strings.xml" 
           
###############################################################################
#     VARIABLES
###############################################################################

# Common
#----------------------------
    EXIT_CODE=""
    BUILDS_FAILED=false
    PRINT_TERMINAL=true
    SILENT_REPO=""
    SILENT_BUILD=""
    SHOW_ERRORS_ONLY=""
    
# stats
#----------------------------    
    TIME_START=""
    TIME_END=""
    TIME=""
    DUREE=""
    HEURE_END=""
    
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

# microg_signature_spoofing()
#----------------------------
# DESC: use while to send text piped in print_log()
# ARGS: $1 (required): vendor.
#       $2 (required): patch name.
#       $3 (required): permission controller patch
# OUTS: None
function microg_signature_spoofing() {

    local $vendor=$1
    local $patch_name=$2
    local $permissioncontroller_patch=$3
                
    # Set up our overlay
    mkdir -p "vendor/$vendor/overlay/microg/"
    sed -i "1s;^;PRODUCT_PACKAGE_OVERLAYS := vendor/$vendor/overlay/microg\n;" \
        "vendor/$vendor/config/common.mk"

    # Determine which patch should be applied to the current Android source tree
    cd frameworks/base || exit
    if [ "$SIGNATURE_SPOOFING" = "yes" ]; then
        mess_log="Applying the standard signature spoofing patch"
        mess_log+=" ($patch_name) to frameworks/base"
        print_log " >> $mess_log" "INFO"
        
        mess_log="WARNING: the standard signature spoofing patch"
        mess_log+=" introduces a security threat !"
        print_log " $mess_log" "WARN"

        patch \
            --quiet \
            --force \
            -p1 \
            -i "$PATCH_SIGN_SPOOF_DIR/$patch_name" 2>&1 \
            || EXIT_CODE=$?
    else
        mess_log="Applying the restricted signature spoofing patch"
        mess_log+=" (based on $patch_name) to frameworks/base"
        print_log " >> $mess_log" "INFO"
        
        patch_str='s/android:protectionLevel="dangerous"'
        patch_str+='/android:protectionLevel="signature|privileged"/'
        sed $patch_str \
            "/root/signature_spoofing_patches/$patch_name" \
            | patch --quiet --force -p1 2>&1 \
            || EXIT_CODE=$?
    fi
    
    # check patch cmd
    [[ $EXIT_CODE -ne 0 ]] \
        && print_log "ERROR: failed to apply $patch_name"  "ERROR" \
        && script_exit 5 
    git clean -q -f
    cd ../..

    if [ -n "$permissioncontroller_patch" ] \
        && [ "$SIGNATURE_SPOOFING" = "yes" ]; then
        
        cd packages/apps/PermissionController || exit
        mess_log="Applying the PermissionController patch "
        mess_log+="($permissioncontroller_patch)"
        mess_log+=" to packages/apps/PermissionController"
        print_log " >> $mess_log" "INFO"
        patch \
            --quiet \
            --force \
            -p1 \
            -i "$PATCH_SIGN_SPOOF_DIR/$permissioncontroller_patch" \
            2>&1 \
            || EXIT_CODE=$?
                        
        # check patch cmd
        [[ $EXIT_CODE -ne 0 ]] \
            && print_log "ERROR: failed to apply $permissioncontroller_patch" \
                "ERROR" \
            && script_exit 5 
            
        git clean -q -f
        cd ../../..
    fi

    # Override device-specific settings for the location providers
    mkdir -p "vendor/$vendor/$OVERLAY_MICROG_FRAM"
    cp $PATCH_SIGN_SPOOF_DIR/frameworks_base_config.xml \
        "vendor/$vendor/$OVERLAY_MICROG_FRAM/config.xml"
        
        
}

# build_lineageos()
#----------------------------
# DESC: use while to send text piped in print_log()
# ARGS: $1 (required): device codename.
#       $2 (required): build date.
#       $3 (required): branch directory.
#       $4 (required): lineage version (ex: 18.1)
# OUTS: None
function build_lineageos() {
    
    # Check params
    if [[ $# -ne 4 ]]; then
        print_log "Parameters missing in build_lineageos(), Abord !" "ERROR"
        script_exit "" 7
    fi
    
    # Local
    local codename=$1
    local build_date=$2
    local branch_dir=$3
    local los_ver=$4
    local time_start=""
    local heure_start=""
    local time_end=""
    local time=""
    local duree=""
    local heure_end=""  
    local build_name=""  
    
    if [ -n "$codename" ]; then
    
        # Date
        currentdate=$(date +%Y%m%d)        
        
        # Sync repo if needed
        if [[ "$build_date" != "$currentdate" ]] \
            && [[ "$REPO_SYNC" = true ]]; then
                        
            # Sync the source code
            build_date=$currentdate

            if [[ "$LOCAL_MIRROR" = true ]]; then
                print_log " >> Syncing mirror repository" "INFO" $LOG_REPO
                cd "$MIRROR_DIR" || exit
                repo sync --force-sync --no-clone-bundle 2>&1 \
                    | print_log_catcher $LOG_REPO "REPO"             
            fi

            print_log " >> Syncing branch repository" "INFO" $LOG_REPO
            cd "$SRC_DIR/$branch_dir" || exit
            repo sync -c --force-sync 2>&1 \
                | print_log_catcher $LOG_REPO "REPO"
        fi

        if [ "$BUILD_OVERLAY" = true ]; then
            lowerdir="$SRC_DIR/$branch_dir"
            upperdir="$TMP_DIR/device"
            workdir="$TMP_DIR/workdir"
            merged="$TMP_DIR/merged"
            mkdir -p "$upperdir" "$workdir" "$merged"
            mount -t overlay overlay -o \
                lowerdir="$lowerdir",\
                upperdir="$upperdir",\
                workdir="$workdir" "$merged"
            source_dir="$merged"
        else
            source_dir="$SRC_DIR/$branch_dir"
        fi
        cd "$source_dir" || exit

        # Use subdir device folder
        if [ "$ZIP_SUBDIR" = true ]; then
            zipsubdir=$codename
            mkdir -p "$ZIP_DIR/$zipsubdir"
        else
            #zipsubdir=
            zipsubdir=""
        fi
                    
        # Define log subdirectory
        if [ "$LOGS_SUBDIR" = true ]; then
            logsubdir=$codename
            mkdir -p "$LOGS_DIR/$logsubdir"
        else
            #logsubdir=
            logsubdir=""
        fi

        # Define log file for each build
        LOG_BUILD="$LOGS_DIR/$logsubdir/"
        LOG_BUILD+="lineage-$los_ver-$build_date-$RELEASE_TYPE-$codename.log"
        
        # logs rotate
        log_rotate LOG_BUILD

        # Exec custom pre-build scripts
        if [ -f $CUSTOM_SCRIPT_PRE_BUILD ]; then
            mess_log="Running Pre-build custom scripts for "
            mess_log+="$codename: $CUSTOM_SCRIPT_PRE_BUILD"
            print_log " >> $mess_log" "INFO" $LOG_BUILD
            $CUSTOM_SCRIPT_PRE_BUILD "$codename" | print_log_catcher "$LOG_BUILD"
        fi


        # Start the build
        #----------------------------
        
        # Stats
        time_start=$(date +%s)
        heure_start=$( date -d@$time_start +"%H:%M - %S seconde" )
        
        # Init
        build_successful=false           
        build_name="lineage-$los_ver-$build_date-$RELEASE_TYPE-$codename"
        
        # Print
        print_log " ------------------------------------ "  "INFO"  \
            $LOG_BUILD $fg_yellow
        print_log " >> Starting build for $codename, $branch branch" "INFO" \
            $LOG_BUILD $fg_yellow
        print_log "    Time: $heure_start"                  "INFO"  \
            $LOG_BUILD $fg_yellow
        print_log " ------------------------------------ "  "INFO"  \
            $LOG_BUILD $fg_yellow
        
        # Authorize unbound variables for 'brunch' function in envsetup.sh
        set +o nounset 
        
        # Build
        if brunch "$codename" "$BUILD_VARIANT" 2>&1 \
            | print_log_catcher "$LOG_BUILD" "BUILD" ; then
            
            # Exit script if unbound variables (like before)
            set -o nounset             
            
            # End Stats
            time_end=$(date +%s)
            time=$[$time_end-$time_start]
            duree=$(date -d@$time -u +"%Hh%Mm%Ss")
            heure_end=$(date -d@$time_end +"%H:%M - %S seconde")
            print_log " ------------------------------------ "  "INFO"  \
                $LOG_BUILD  $fg_yellow
            print_log " *** BUILD "$build_name" *** "           "INFO"  \
                $LOG_BUILD  $fg_yellow
            print_log " => START:       $heure_start"           "INFO"  \
                $LOG_BUILD  $fg_yellow
            print_log " => END:         $heure_end"             "INFO"  \
                $LOG_BUILD  $fg_yellow
            print_log " => TIME:        $duree"                 "INFO"  \
                $LOG_BUILD  $fg_yellow
            print_log " ------------------------------------ "  "INFO"  \
                $LOG_BUILD  $fg_yellow
       
            # Handle cross date issue 
            currentdate=$(date +%Y%m%d)
            mv_build="mv {} \$(echo {} | sed \"s|$currentdate|$build_date|\")"
            if [ "$build_date" != "$currentdate" ]; then
                find out/target/product/"$codename" \
                    -maxdepth 1 \
                    -name "lineage-*-$currentdate-*.zip*" \
                    -type f \
                    -exec sh -c "$mv_build" \; \
                    2>&1 \
                    | print_log_catcher $LOG_BUILD                 
            fi


            # Move produced images files to the main OUT directory
            #----------------------------
            
            # Main zip image
            mess_log="Moving build artifacts for "
            mess_log+="$codename to '$ZIP_DIR/$zipsubdir'"
            print_log " >> $mess_log" "INFO" $LOG_BUILD
            
            cd out/target/product/"$codename" || exit
            for build in lineage-*.zip; do
                sha256sum "$build" > "$ZIP_DIR/$zipsubdir/$build.sha256sum"
                cp -v system/build.prop "$ZIP_DIR/$zipsubdir/$build.prop" \
                    2>&1 \
                    | print_log_catcher $LOG_BUILD
            done
            
            find . \
                -maxdepth 1 \
                -name 'lineage-*.zip*' \
                -type f -exec mv {} "$ZIP_DIR/$zipsubdir/" \; \
                2>&1 \
                | print_log_catcher $LOG_BUILD
                
            # recovery image file
            recovery_name="lineage-$los_ver-$build_date"
            recovery_name+="-$RELEASE_TYPE-$codename-recovery.img"
            for image in recovery boot; do
                if [ -f "$image.img" ]; then
                        cp -v "$image.img" "$ZIP_DIR/$zipsubdir/$recovery_name" \
                            | print_log_catcher $LOG_BUILD
                    break
                fi
            done            
            
            cd "$source_dir" || exit
            
            # Successfull build
            build_successful=true
        else
            # Build failed
            print_log " >> Failed build for $codename" "ERROR" $LOG_BUILD
            
            # Add name to the list of failed build
            if [[ $BUILDS_FAILED = false ]]; then
                BUILDS_FAILED="lineage-$los_ver-"                     
            else
                BUILDS_FAILED+=", lineage-$los_ver-"
            fi            
            BUILDS_FAILED+="$build_date-$RELEASE_TYPE-$codename"
        fi

        # Remove old zips
        if [ "$DELETE_OLD_ZIPS" -gt "0" ]; then
            if [ "$ZIP_SUBDIR" = true ]; then
                /usr/bin/python /root/clean_up.py \
                    -n "$DELETE_OLD_ZIPS" \
                    -V "$los_ver" \
                    -N 1 \
                    "$ZIP_DIR/$zipsubdir"
            else
                /usr/bin/python /root/clean_up.py \
                    -n "$DELETE_OLD_ZIPS" \
                    -V "$los_ver" \
                    -N 1 \
                    -c "$codename" \
                    "$ZIP_DIR"
            fi
        fi
        
        # Remove old logs
        if [ "$DELETE_OLD_LOGS" -gt "0" ]; then
            if [ "$LOGS_SUBDIR" = true ]; then
                /usr/bin/python /root/clean_up.py \
                    -n "$DELETE_OLD_LOGS" \
                    -V "$los_ver" \
                    -N 1 \
                    "$LOGS_DIR/$logsubdir"
            else
                /usr/bin/python /root/clean_up.py \
                    -n "$DELETE_OLD_LOGS" \
                    -V "$los_ver" \
                    -N 1 \
                    -c "$codename" \
                    "$LOGS_DIR"
            fi
        fi
                
        # Exec custom post build scripts
        if [ -f $CUSTOM_SCRIPT_POST_BUILD ]; then
            mess_log="Running post-build custom scripts:"
            mess_log+=" $CUSTOM_SCRIPT_POST_BUILD"
            print_log " >> $mess_log" "INFO"
            
            $CUSTOM_SCRIPT_POST_BUILD "$codename" $build_successful \
                | print_log_catcher $LOG_BUILD
        fi
        print_log " >> Finishing build for $codename" $LOG_BUILD

        if [ "$BUILD_OVERLAY" = true ]; then
                    
            # The Jack server must be stopped manually, 
            # as we want to unmount $TMP_DIR/merged
            cd "$TMP_DIR" || exit
            if [ -f "$TMP_DIR/merged/prebuilts/sdk/tools/jack-admin" ]; then
                "$TMP_DIR/merged/prebuilts/sdk/tools/jack-admin kill-server" \
                    &> /dev/null || true
            fi
            lsof | grep "$TMP_DIR/merged" \
                | awk '{ print $2 }' \
                | sort -u \
                | xargs -r kill \
                &> /dev/null

            while lsof | grep -q "$TMP_DIR"/merged; do
                sleep 1
            done

            umount "$TMP_DIR/merged"
        fi

        # Clean files
        if [ "$CLEAN_AFTER_BUILD" = true ]; then
            print_log " >> Cleaning source dir for device $codename" "INFO" \
                $LOG_BUILD
            if [ "$BUILD_OVERLAY" = true ]; then
                cd "$TMP_DIR" || exit
                rm -rf ./*
            else
                cd "$source_dir" || exit
                
                # Authorize unbound variables for 'brunch' function in envsetup.sh
                set +o nounset 
                
                # Clean cmd from envsetup.sh
                mka clean | print_log_catcher "$LOG_BUILD" "BUILD"
                
                # Exit script if unbound variables (like before)
                set -o nounset
            fi
        fi
    fi
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
    log_rotate LOG_REPO

    # Set PRINT_MODE    
    case $PRINT_MODE in 
        all)
            PRINT_TERMINAL=true
            ;;
        silent)
            PRINT_TERMINAL=false
            ;;
        no_repo)
            SILENT_REPO=true
            ;;
        no_build)
            SILENT_BUILD=true
            ;;
        no_repo_build)
            SILENT_REPO=true
            SILENT_BUILD=true
            ;;
        build_errors)
            SHOW_ERRORS_ONLY=true
            ;;
        *)
            script_exit "Invalid parameter \$PRINT_MODE: $PRINT_MODE" 1
            ;;
    esac
    
    # cd to working directory
    cd "$SRC_DIR" || script_exit 0
    
    # stats
    TIME_START=$(date +%s)
    HEURE_START=$( date -d@$TIME_START +"%H:%M - %S seconde" )
    
    # DEV ONLY - custom scripts
    #----------------------------
    if [ "$TEST_SCRIPT" = true ]; then
        if [ -f $CUSTOM_SCRIPT_TEST ]; then
            pretty_print ">> Running begin custom scripts: $CUSTOM_SCRIPT_TEST"
            $CUSTOM_SCRIPT_TEST
        else
            #print_log " TEST: logs !!!!" "WARN"
            pretty_print "WARNING: $CUSTOM_SCRIPT_TEST: not found !" \
                "$fg_yellow$ta_bold"           
        fi
        
        # Exit
        script_exit 0
    fi

    # Begin custom scripts
    #----------------------------
    if [ -f $CUSTOM_SCRIPT_BEGIN ]; then
        print_log "Running begin custom scripts: $CUSTOM_SCRIPT_BEGIN" "INFO"
        $CUSTOM_SCRIPT_BEGIN
    fi
    
    # Init build
    #----------------------------

    # If requested, clean the OUT dir in order to avoid clutter
    if [ "$CLEAN_OUTDIR" = true ]; then
        print_log "Cleaning '$ZIP_DIR': $ZIP_DIR" "INFO"
        rm -rf "${ZIP_DIR:?}/"*
    fi

    # Treat DEVICE_LIST as DEVICE_LIST_<first_branch>
    first_branch=$(cut -d ',' -f 1 <<< "$BRANCH_NAME")
    if [ -n "$DEVICE_LIST" ]; then
        device_list_first_branch="DEVICE_LIST_${first_branch//[^[:alnum:]]/_}"
        device_list_first_branch=${device_list_first_branch^^}

        # Test if DEVICE_LIST_<BRANCH> exist
        if [ ! -z ${!device_list_first_branch+x} ]; then
            read -r "${device_list_first_branch?}" \
                <<< "$DEVICE_LIST,${!device_list_first_branch}"
        else
            read -r "${device_list_first_branch?}" <<< "$DEVICE_LIST"
        fi
    fi

    # If needed, migrate from the old SRC_DIR structure
    if [ -d "$SRC_DIR/.repo" ]; then
        branch_dir=$(repo info -o \
            | sed -ne 's/Manifest branch: refs\/heads\///p' \
            | sed 's/[^[:alnum:]]/_/g')
            
        branch_dir=${branch_dir^^}
        
        branch_mess="Old source dir detected, moving source from"
        branch_mess+="\"\$SRC_DIR\" to \"\$SRC_DIR/$branch_dir\""
        print_log "WARNING: $branch_mess" "WARN"
        
        if [ -d "$branch_dir" ] && [ -z "$(ls -A "$branch_dir")" ]; then
            print_log "ERROR: $branch_dir already exists and is not empty!"\
                "ERROR"
            print_log "=> aborting !" "ERROR"
            script_exit 2 # new
        fi
        
        # Create branch directory and move files
        mkdir -p "$branch_dir"
        find . -maxdepth 1 ! \
            -name "$branch_dir" ! \
            -path . \
            -exec mv {} "$branch_dir" \;
    fi

    # If mirror used
    if [ "$LOCAL_MIRROR" = true ]; then

        cd "$MIRROR_DIR" || exit

        if [ ! -d .repo ]; then
            print_log ">> Initializing mirror repository..."  "INFO"
            print_log "See $LOG_REPO file for more details. " "INFO"
            print_log ">> Initializing mirror repository" "INFO" $LOG_REPO

            # Init repo
            yes | repo init -u $GITHUB_LINEAGE_MIRR \
                --mirror \
                --no-clone-bundle \
                -p linux \
                2>&1 \
                | print_log_catcher $LOG_REPO "REPO" \
                || EXIT_CODE=$?
 
            [[ $EXIT_CODE -ne 0 ]] \
                && print_log "repo init --mirror failed ! see $LOG_REPO"  \
                    "ERROR" \
                && script_exit 3            
        fi

        # Copy local manifests to the appropriate folder
        # in order take them into consideration
        print_log "Copying '$LMANIFEST_DIR/*.xml' to '.repo/local_manifests/'"\
            "INFO"
        mkdir -p .repo/local_manifests
        rsync -a \
            --delete \
            --include '*.xml' \
            --exclude '*' \
            "$LMANIFEST_DIR/" .repo/local_manifests/ \
            | print_log_catcher $LOG_REPO "REPO"\
            || EXIT_CODE=$?

        [[ $EXIT_CODE -ne 0 ]] \
            && print_log "rsync failed ! see $LOG_REPO" "ERROR" \
            && script_exit 8 

        rm -f .repo/local_manifests/proprietary.xml

        # Include proprietary
        if [ "$INCLUDE_PROPRIETARY" = true ]; then
            wget -q -O .repo/local_manifests/proprietary.xml \
                "$GITHUB_MUPPET_SRC"
            /root/build_manifest.py \
                --remote "https://gitlab.com" \
                --remotename "gitlab_https" "$GITLAB_MUPPET_SRC" \
                .repo/local_manifests/proprietary_gitlab.xml
        fi
        
        # Sync repo
        if [[ "$REPO_SYNC" = true ]]; then
            print_log ">> Syncing mirror repository" $LOG_REPO
            repo sync \
                --force-sync \
                --no-clone-bundle 2>&1 \
                | print_log_catcher $LOG_REPO "REPO" \
                || EXIT_CODE=$?

            [[ $EXIT_CODE -ne 0 ]] \
                && print_log "repo sync failed ! see $LOG_REPO"  "ERROR" \
                && script_exit 3 
        fi
    fi

    # Build for each branch
    #----------------------------
    for branch in ${BRANCH_NAME//,/ }; do
        #branch_dir=$(sed 's/[^[:alnum:]]/_/g' <<< "$branch")
        branch_dir=${branch//[^[:alnum:]]/_}
        branch_dir=${branch_dir^^}
        device_list_cur_branch="DEVICE_LIST_$branch_dir"
        devices=${!device_list_cur_branch}

        if [ -n "$branch" ] && [ -n "$devices" ]; then
            vendor=lineage
            permissioncontroller_patch=""
            case "$branch" in
                cm-14.1*)
                    vendor="cm"
                    themuppets_branch="cm-14.1"
                    android_version="7.1.2"
                    patch_name="android_frameworks_base-N.patch"
                    ;;
                lineage-15.1*)
                    themuppets_branch="lineage-15.1"
                    android_version="8.1"
                    patch_name="android_frameworks_base-O.patch"
                    ;;
                lineage-16.0*)
                    themuppets_branch="lineage-16.0"
                    android_version="9"
                    patch_name="android_frameworks_base-P.patch"
                    ;;
                lineage-17.1*)
                    themuppets_branch="lineage-17.1"
                    android_version="10"
                    patch_name="android_frameworks_base-Q.patch"
                    ;;
                lineage-18.1*)
                    themuppets_branch="lineage-18.1"
                    android_version="11"
                    patch_name="android_frameworks_base-R.patch"
                    permissioncontroller_patch="packages_apps_PermissionController-R.patch"
                    ;;
                *)
                    print_log " >> Building branch $branch is not (yet) suppported"\
                        "ERROR"
                    script_exit 4
                    ;;
            esac

            android_version_major=$(cut -d '.' -f 1 <<< $android_version)

            mkdir -p "$SRC_DIR/$branch_dir"
            cd "$SRC_DIR/$branch_dir" || exit

            print_log " >> Branch:  $branch" "INFO"
            print_log " >> Devices: $branch" "INFO"

            # Remove previous changes of vendor/cm,
            # vendor/lineage and frameworks/base (if they exist)
            path_list=()
            path_list+=( "vendor/cm" )
            path_list+=( "vendor/lineage" )
            path_list+=( "frameworks/base" )
            path_list+=( "packages/apps/PermissionController" )
            for path in ${path_list[@]}; do
                if [ -d "$path" ]; then
                    cd "$path" || exit
                    git reset -q --hard
                    git clean -q -fd
                    cd "$SRC_DIR/$branch_dir" || exit
                fi
            done


            print_log " >> (Re)initializing branch repository" "INFO" $LOG_REPO
            if [ "$LOCAL_MIRROR" = true ]; then
                (yes || true) | repo init \
                    -u $GITHUB_ANDROID \
                    --reference "$MIRROR_DIR" \
                    -b "$branch" 2>&1 \
                   | print_log_catcher $LOG_REPO "REPO" \
                   || EXIT_CODE=$?
            else   
                (yes || true) | repo init \
                    -u $GITHUB_ANDROID \
                    -b "$branch" 2>&1 \
                   | print_log_catcher $LOG_REPO "REPO" \
                   || EXIT_CODE=$?
            fi

            [[ $EXIT_CODE -ne 0 ]] \
                && print_log "repo init  failed ! see $LOG_REPO"  "ERROR" \
                && script_exit 3 

            # Copy local manifests to the appropriate folder
            # in order take them into consideration
            mess_log="Copying '$LMANIFEST_DIR/*.xml' "
            mess_log+="to '.repo/local_manifests/'"
            print_log " >> $mess_log" "INFO"
            mkdir -p .repo/local_manifests
            rsync -a \
                --delete \
                --include '*.xml' \
                --exclude '*' \
                "$LMANIFEST_DIR/" .repo/local_manifests/ 2>&1 \
                | print_log_catcher $LOG_REPO "REPO" \
                || EXIT_CODE=$?
            
            [[ $EXIT_CODE -ne 0 ]] \
                && print_log "rsync manifest failed ! see $LOG_REPO"  "ERROR" \
                && script_exit 3 
                
            rm -f .repo/local_manifests/proprietary.xml
          
            # Include proprietary
            if [ "$INCLUDE_PROPRIETARY" = true ]; then
                wget -q -O .repo/local_manifests/proprietary.xml \
                    "$GITHUB_MUPPET_URL/$themuppets_branch/muppets.xml"
                /root/build_manifest.py \
                    --remote "https://gitlab.com" \
                    --remotename "gitlab_https" \
                    "$GITLAB_MUPPET_URL/$themuppets_branch/muppets.xml" \
                    .repo/local_manifests/proprietary_gitlab.xml 
            fi
            
            # Init buildate
            builddate=$(date +%Y%m%d)
            
            # Sync repo
            if [[ "$REPO_SYNC" = true ]]; then
                print_log " >> Syncing branch repository" "INFO" $LOG_REPO                
                repo sync -c --force-sync 2>&1 \
                        | print_log_catcher $LOG_REPO "REPO" \
                        || EXIT_CODE=$?
                 
                [[ $EXIT_CODE -ne 0 ]] \
                    && print_log "repo sync  failed ! see $LOG_REPO"  "ERROR" \
                    && script_exit 3 
            fi
            
            if [ ! -d "vendor/$vendor" ]; then
                print_log " >> Missing \"vendor/$vendor\", aborting"  "ERROR"
                script_exit 4
            fi

            # Set up MicroG overlay
            #mkdir -p "vendor/$vendor/overlay/microg/"
            #sed -i "1s;^;PRODUCT_PACKAGE_OVERLAYS := vendor/$vendor/overlay/microg\n;" "vendor/$vendor/config/common.mk"

            # Get Lineage version
            los_ver_major=$(sed -n -e 's/^\s*PRODUCT_VERSION_MAJOR = //p'\
                 "vendor/$vendor/config/common.mk")
            los_ver_minor=$(sed -n -e 's/^\s*PRODUCT_VERSION_MINOR = //p'\
                 "vendor/$vendor/config/common.mk")
            los_ver="$los_ver_major.$los_ver_minor"
            
            # MicroG
            #----------------------------

            # If needed, apply the microG's signature spoofing patch
            if [ "$SIGNATURE_SPOOFING" = "yes" ] \
                || [ "$SIGNATURE_SPOOFING" = "restricted" ]; then
                
                microg_signature_spoofing \
                    $vendor \
                    $patch_name \
                    $permissioncontroller_patch
            fi

            print_log " >> Setting \"$RELEASE_TYPE\" as release type" "INFO"
            sed -i "/\$(filter .*\$(${vendor^^}_BUILDTYPE)/,+2d" \
                "vendor/$vendor/config/common.mk"

            # OTA
            #----------------------------
            
            # Set a custom updater URI if a OTA URL is provided            
            if [ -n "$OTA_URL" ]; then
                print_log " >> Adding OTA URL overlay (for custom URL $OTA_URL)" \
                "INFO"

                updater_url_overlay_dir="vendor/$vendor/$OVERLAY_MICROG_UPDATER"
                mkdir -p "$updater_url_overlay_dir"

                if grep -q updater_server_url $OTA_UPDATER_STRING; then
        
                    # "New" updater configuration: 
                    # full URL (with placeholders {device}, {type} and {incr})
                    ota_new_conf="s|{name}|updater_server_url|g; s|{url}"
                    ota_new_conf+="|$OTA_URL/v1/{device}/{type}/{incr}|g"
                    sed $ota_new_conf /root/packages_updater_strings.xml \
                        > "$updater_url_overlay_dir/strings.xml"
                        
                elif grep -q conf_update_server_url_def $OTA_UPDATER_STRING; then
 
                    # "Old" updater configuration: just the URL
                    ota_old_conf="s|{name}|conf_update_server_url_def"
                    ota_old_conf+="|g; s|{url}|$OTA_URL|g"      
                    sed "$ota_old_conf" /root/packages_updater_strings.xml \
                        > "$updater_url_overlay_dir/strings.xml"
                else
                    print_og " >> ERROR: no known Updater URL property found" \
                        "ERROR"
                    script_exit 6
                fi
            fi

            # Custom packages
            #----------------------------
    
            # Add custom packages to be installed
            if [ -n "$CUSTOM_PACKAGES" ]; then
                print_log " >> Adding custom packages ($CUSTOM_PACKAGES)" "INFO"
                sed -i "1s;^;PRODUCT_PACKAGES += $CUSTOM_PACKAGES\n\n;" \
                    "vendor/$vendor/config/common.mk"
            fi

            # Signing build
            #----------------------------            
            if [ "$SIGN_BUILDS" = true ]; then
                print_log " >> Adding keys path ($KEYS_DIR)" "INFO"
                
                # Soong (Android 9+) complains if the signing keys are 
                # outside the build path
                ln -sf "$KEYS_DIR" user-keys
                if [ "$android_version_major" -lt "10" ]; then
                    sed -i "$SIGN_BUILD_LT_Q" "vendor/$vendor/config/common.mk"
                fi

                if [ "$android_version_major" -ge "10" ]; then
                    sed -i "$SIGN_BUILD_GT_Q" "vendor/$vendor/config/common.mk"
                fi
            fi
            
            # Pre-build 
            #----------------------------
             
            # Prepare the environment
            print_log " >> Preparing build environment" "INFO"           
            set +o nounset # Authorize unbound variables for envsetup.sh
            source build/envsetup.sh > /dev/null
            set -o nounset # Exit script if unbound variables (like before)
           
            # Exec custom scripts before building
            if [ -f $CUSTOM_SCRIPT_BEFORE ]; then
                mess_log="Running before custom scripts:"
                mess_log+="$CUSTOM_SCRIPT_BEFORE"
                print_log " >> $mess_log" "INFO"
                $CUSTOM_SCRIPT_BEFORE
            fi            
        
            # Build for every devices
            #----------------------------               
            for codename in ${devices//,/ }; do
                
                print_log " >> Starting build for $codename, $branch branch" \
                    "INFO"
                   
                # Build
                build_lineageos $codename $builddate $branch_dir $los_ver
            done
        fi
    done

    # Clean old logs
    if [ "$DELETE_OLD_LOGS" -gt "0" ]; then
        find "$LOGS_DIR" -maxdepth 1 -name 'repo-*.log' \
            | sort | head -n -"$DELETE_OLD_LOGS" | xargs -r rm
    fi

    # Exec custom scripts after building
    if [ -f $CUSTOM_SCRIPT_AFTER ]; then
        print_log " >> Running end custom scripts: $CUSTOM_SCRIPT_AFTER" "INFO"
        $CUSTOM_SCRIPT_AFTER
    fi
    
    # End
    #----------------------------
            
    # Stats
    TIME_END=$(date +%s)
    TIME=$[$TIME_END-$TIME_START]
    DUREE=$(date -d@$TIME -u +"%Hh%Mm%Ss")
    HEURE_END=$(date -d@$TIME_END +"%H:%M - %S seconde")
    print_log " ------------------------------------ "  "INFO"  "" $fg_yellow
    print_log " *** TOTAL BUILD PROCESS *** "           "INFO"  "" $fg_yellow
    print_log " => START:       $HEURE_START"           "INFO"  "" $fg_yellow
    print_log " => END:         $HEURE_END"             "INFO"  "" $fg_yellow
    print_log " => TIME:        $DUREE"                 "INFO"  "" $fg_yellow
    print_log " ------------------------------------ "  "INFO"  "" $fg_yellow
    
    # Conclusion
    if [[ $BUILDS_FAILED = false ]]; then
        print_log "ALL BUILD SUCCESSFUL" "INFO" "" $fg_green$ta_bold 
    else
        print_log "Some builds failed: $BUILDS_FAILED" "ERROR"
        print_log "Please see Builds logs for more details." "ERROR"
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
