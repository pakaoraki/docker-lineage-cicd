#!/usr/bin/env bash

# Docker build script
# Copyright (C) 2021 Pakaoraki <pakaoraki@gmx.com>
#
# From https://github.com/ralish/bash-script-template/blob/main/template.sh
#      by Ralish
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
#                                 SOURCE.SH                                   #
#                                                                             #
###############################################################################

#-----------------------------------------------------------------------------#
#     Author(s): Ralish, Pakaoraki
#     Version: 1.0
#     Date: 23/07/2021
#     Description: Base functions for better class of scripts.
#                 
#-----------------------------------------------------------------------------#

###############################################################################
#     CONST
###############################################################################

###############################################################################
#     FUNCTIONS
###############################################################################

# A best practices Bash script template with many useful functions. This file
# is suitable for sourcing into other scripts and so only contains functions
# which are unlikely to need modification. It omits the following functions:
# - main()
# - parse_params()
# - script_usage()

# script_trap_err()
#----------------------------
# DESC: Handler for unexpected errors
# ARGS: $1 (optional): Exit code (defaults to 1)
# OUTS: None
function script_trap_err() {
    local exit_code=1

    # Disable the error trap handler to prevent potential recursion
    trap - ERR

    # Consider any further errors non-fatal to ensure we run to completion
    set +o errexit
    set +o pipefail

    # Validate any provided exit code
    if [[ ${1-} =~ ^[0-9]+$ ]]; then
        exit_code="$1"
    fi
    
    # Output error log
    print_log "***** Abnormal termination of script *****"  "ERROR"
    print_log "Script Path:            $script_path"        "ERROR"
    print_log "Script Parameters:      $script_params"      "ERROR"
    print_log "Script Exit Code:       $exit_code"          "ERROR"

    # Output debug data if in Cron mode
    if [[ -n ${cron-} ]]; then
        # Restore original file output descriptors
        if [[ -n ${script_output-} ]]; then
            exec 1>&3 2>&4
        fi

        # Print basic debugging information
        printf '%b\n' "$ta_none"
        printf '***** Abnormal termination of script *****\n'
        printf 'Script Path:            %s\n' "$script_path"
        printf 'Script Parameters:      %s\n' "$script_params"
        printf 'Script Exit Code:       %s\n' "$exit_code"

        # Print the script log if we have it. It's possible we may not if we
        # failed before we even called cron_init(). This can happen if bad
        # parameters were passed to the script so we bailed out very early.
        if [[ -n ${script_output-} ]]; then
            printf 'Script Output:\n\n%s' "$(cat "$script_output")"
        else
            printf 'Script Output:          None (failed before log init)\n'
        fi
    fi

    # Exit with failure status
    exit "$exit_code"
}

# script_trap_exit()
#----------------------------
# DESC: Handler for exiting the script
# ARGS: None
# OUTS: None
function script_trap_exit() {
    cd "$orig_cwd"

    # Remove Cron mode script log
    if [[ -n ${cron-} && -f ${script_output-} ]]; then
        rm "$script_output"
    fi

    # Remove script execution lock
    if [[ -d ${script_lock-} ]]; then
        rmdir "$script_lock"
    fi

    # Restore terminal colours
    printf '%b' "$ta_none"
}

# script_exit()
#----------------------------
# DESC: Exit script with the given message
# ARGS: $1 (required): Message to print on exit
#       $2 (optional): Exit code (defaults to 0)
# OUTS: None
# NOTE: The convention used in this script for exit codes is:
#       0: Normal exit
#       1: Abnormal exit due to external error
#       2: Abnormal exit due to script error
function script_exit() {
    if [[ $# -eq 1 ]]; then
        printf '%s\n' "$1"
        exit 0
    fi

    if [[ ${2-} =~ ^[0-9]+$ ]]; then
        printf '%b\n' "$1"
        # If we've been provided a non-zero exit code run the error trap
        if [[ $2 -ne 0 ]]; then
            script_trap_err "$2"
        else
            exit 0
        fi
    fi

    script_exit 'Missing required argument to script_exit()!' 2
}

# script_init()
#----------------------------
# DESC: Generic script initialisation
# ARGS: $@ (optional): Arguments provided to the script
# OUTS: $orig_cwd: The current working directory when the script was run
#       $script_path: The full path to the script
#       $script_dir: The directory path of the script
#       $script_name: The file name of the script
#       $script_params: The original parameters provided to the script
#       $ta_none: The ANSI control code to reset all text attributes
# NOTE: $script_path only contains the path that was used to call the script
#       and will not resolve any symlinks which may be present in the path.
#       You can use a tool like realpath to obtain the "true" path. The same
#       caveat applies to both the $script_dir and $script_name variables.
# shellcheck disable=SC2034
function script_init() {
    # Useful variables
    readonly orig_cwd="$PWD"
    readonly script_params="$*"
    readonly script_path="${BASH_SOURCE[1]}"
    script_dir="$(dirname "$script_path")"
    script_name="$(basename "$script_path")"
    readonly script_dir script_name

    # Important to always set as we use it in the exit handler
    # shellcheck disable=SC2155
    readonly ta_none="$(tput sgr0 2> /dev/null || true)"
}

# colour_init()
#----------------------------
# DESC: Initialise colour variables
# ARGS: None
# OUTS: Read-only variables with ANSI control codes
# NOTE: If --no-colour was set the variables will be empty. The output of the
#       $ta_none variable after each tput is redundant during normal execution,
#       but ensures the terminal output isn't mangled when running with xtrace.
# shellcheck disable=SC2034,SC2155
function colour_init() {
    if [[ -z ${no_colour-} ]]; then
        # Text attributes
        readonly ta_bold="$(tput bold 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly ta_uscore="$(tput smul 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly ta_blink="$(tput blink 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly ta_reverse="$(tput rev 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly ta_conceal="$(tput invis 2> /dev/null || true)"
        printf '%b' "$ta_none"

        # Foreground codes
        readonly fg_black="$(tput setaf 0 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly fg_blue="$(tput setaf 4 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly fg_cyan="$(tput setaf 6 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly fg_green="$(tput setaf 2 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly fg_magenta="$(tput setaf 5 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly fg_red="$(tput setaf 1 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly fg_white="$(tput setaf 7 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly fg_yellow="$(tput setaf 3 2> /dev/null || true)"
        printf '%b' "$ta_none"

        # Background codes
        readonly bg_black="$(tput setab 0 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly bg_blue="$(tput setab 4 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly bg_cyan="$(tput setab 6 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly bg_green="$(tput setab 2 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly bg_magenta="$(tput setab 5 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly bg_red="$(tput setab 1 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly bg_white="$(tput setab 7 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly bg_yellow="$(tput setab 3 2> /dev/null || true)"
        printf '%b' "$ta_none"
    else
        # Text attributes
        readonly ta_bold=''
        readonly ta_uscore=''
        readonly ta_blink=''
        readonly ta_reverse=''
        readonly ta_conceal=''

        # Foreground codes
        readonly fg_black=''
        readonly fg_blue=''
        readonly fg_cyan=''
        readonly fg_green=''
        readonly fg_magenta=''
        readonly fg_red=''
        readonly fg_white=''
        readonly fg_yellow=''

        # Background codes
        readonly bg_black=''
        readonly bg_blue=''
        readonly bg_cyan=''
        readonly bg_green=''
        readonly bg_magenta=''
        readonly bg_red=''
        readonly bg_white=''
        readonly bg_yellow=''
    fi
}

# cron_init()
#----------------------------
# DESC: Initialise Cron mode
# ARGS: None
# OUTS: $script_output: Path to the file stdout & stderr was redirected to
function cron_init() {
    if [[ -n ${cron-} ]]; then
        # Redirect all output to a temporary file
        script_output="$(mktemp --tmpdir "$script_name".XXXXX)"
        readonly script_output
        exec 3>&1 4>&2 1> "$script_output" 2>&1
    fi
}

# lock_init()
#----------------------------
# DESC: Acquire script lock
# ARGS: $1 (optional): Scope of script execution lock (system or user)
# OUTS: $script_lock: Path to the directory indicating we have the script lock
# NOTE: This lock implementation is extremely simple but should be reliable
#       across all platforms. It does *not* support locking a script with
#       symlinks or multiple hardlinks as there's no portable way of doing so.
#       If the lock was acquired it's automatically released on script exit.
function lock_init() {
    local lock_dir
    if [[ $1 = 'system' ]]; then
        lock_dir="/tmp/$script_name.lock"
    elif [[ $1 = 'user' ]]; then
        lock_dir="/tmp/$script_name.$UID.lock"
    else
        script_exit 'Missing or invalid argument to lock_init()!' 2
    fi

    if mkdir "$lock_dir" 2> /dev/null; then
        readonly script_lock="$lock_dir"
        verbose_print "Acquired script lock: $script_lock"
    else
        script_exit "Unable to acquire script lock: $lock_dir" 1
    fi
}

# pretty_print()
#----------------------------
# DESC: Pretty print the provided string
# ARGS: $1 (required): Message to print (defaults to a green foreground)
#       $2 (optional): Colour to print the message with. This can be an ANSI
#                      escape code or one of the prepopulated colour variables.
#       $3 (optional): Set to any value to not append a new line to the message
# OUTS: None
function pretty_print() {
    if [[ $# -lt 1 ]]; then
        script_exit 'Missing required argument to pretty_print()!' 2
    fi

    if [[ -z ${no_colour-} ]]; then
        if [[ -n ${2-} ]]; then
            printf '%b' "$2"
        else
            printf '%b' "$fg_green"
        fi
    fi

    # Print message & reset text attributes
    if [[ -n ${3-} ]]; then
        printf '%s%b' "$1" "$ta_none"
    else
        printf '%s%b\n' "$1" "$ta_none"
    fi
}

# print_log()
#----------------------------
# DESC: print text to a log file and terminal
# ARGS: $1 (required): "TEXT" to write
#       $2 (required): TYPE, see below
#           "INFO" : some info message"
#           "DEBUG": some debug message"
#           "WARN" : some warning message"
#           "ERROR": some really ERROR message"
#           "FATAL": some really fatal message"
#       
#       $3 (optional): force color format (fg_black/fg_green...)
# OUTS: None
function print_log() {

    # Test if required param are missing
    if [[ $# -lt 1 ]]; then
        script_exit 'Missing required argument to print_log()!' 2
    fi
    
    # Get the param Text, type and optional format text
    local msg=$1    
    local type_of_msg=$2    
    local logs_file=$LOG_FILE  
    local format_color=""

    # Show debug only if --debug option set, otherise quit function
    #[[ $type_of_msg == DEBUG ]] && [[ -z ${debug-} ]] && return;
    [[ $type_of_msg == DEBUG ]] && [[ "$DEBUG_MODE" = false ]] && return;

    # Personalize format text for each Type of log
    case $type_of_msg in
        "INFO")
            type_of_msg="INFO " # Extra blank to match max lenght
            format_color=$fg_cyan # Color Cyan                    
            ;;
        "ERROR")
            format_color=$fg_red$ta_bold # Color red and bold                    
            ;;        
        "WARN")
            type_of_msg="WARN " # Extra blank to match max lenght
            format_color=$fg_yellow$ta_bold # Color Yellow and bold
            ;;
        "DEBUG")
            format_color=$fg_black$bg_yellow # Black font on yellow color
            ;;
        "FATAL")
            # Color black, background red and bold
            format_color=$fg_black$bg_red$ta_bold 
            ;;
        *)
            # If no param set or wrong, default INFO
            type_of_msg="INFO " # Extra blank to match max lenght
            format_color=$fg_cyan # Color Cyan 
            ;;
    esac

    # if specific logs file provide
    [[ -n ${3-} ]] && [[ $3 != "" ]] && logs_file=$3
    
    # if format is given, erase it with the new value
    [[ -n ${4-} ]] && format_color=$4
 
    # Print to the terminal if we have one
    #test -t 1 && echo " [$type_of_msg] `date "+%Y.%m.%d-%H:%M:%S %Z"` [$run_unit]  [@$host_name] [$$] ""$msg"
    #if [[ -z ${quiet-} ]]; then 
    if [[ $PRINT_TERMINAL = true ]]; then
        pretty_print "[$type_of_msg][`date $TIMESTAMP`]: ""$msg" $format_color           
    fi
    
    # Write line to log file (if --no-log param not present)
    if ! $NO_LOGS; then  
        echo "[$type_of_msg][`date $TIMESTAMP`]: ""$msg" >> $logs_file
    fi
}

# log_rotate()
#----------------------------
# DESC: Change name of the log file if needed
# ARGS: $1 (required): Log file var name.
# OUTS: None
function log_rotate() {

    # Check
    if [[ $# -lt 1 ]]; then
        script_exit 'Missing required argument to log_rotate()!' 2
    fi

    # local
    local int=0
    local max_file=50
    local __log_file=$1
    local log_full_name=${!1}
    local name_pattern=$log_full_name
    
    while test -f "$log_full_name" && [ $int -le $max_file ]
    do  
        log_full_name=${name_pattern/.log/}"_$int.log"
        int=$((int+1))
    done
    
    # Update log var with new value
    eval $__log_file="'$log_full_name'"
}

# verbose_print()
#----------------------------
# DESC: Only pretty_print() the provided string if verbose mode is enabled
# ARGS: $@ (required): Passed through to pretty_print() function
# OUTS: None
function verbose_print() {
    if [[ -n ${verbose-} ]]; then
        pretty_print "$@"
    fi
}

# build_path()
#----------------------------
# DESC: Combines two path variables and removes any duplicates
# ARGS: $1 (required): Path(s) to join with the second argument
#       $2 (optional): Path(s) to join with the first argument
# OUTS: $build_path: The constructed path
# NOTE: Heavily inspired by: https://unix.stackexchange.com/a/40973
function build_path() {
    if [[ $# -lt 1 ]]; then
        script_exit 'Missing required argument to build_path()!' 2
    fi

    local new_path path_entry temp_path

    temp_path="$1:"
    if [[ -n ${2-} ]]; then
        temp_path="$temp_path$2:"
    fi

    new_path=
    while [[ -n $temp_path ]]; do
        path_entry="${temp_path%%:*}"
        case "$new_path:" in
            *:"$path_entry":*) ;;
            *)
                new_path="$new_path:$path_entry"
                ;;
        esac
        temp_path="${temp_path#*:}"
    done

    # shellcheck disable=SC2034
    build_path="${new_path#:}"
}

# DESC: Check a binary exists in the search path
# ARGS: $1 (required): Name of the binary to test for existence
#       $2 (optional): Set to any value to treat failure as a fatal error
# OUTS: None
function check_binary() {
    if [[ $# -lt 1 ]]; then
        script_exit 'Missing required argument to check_binary()!' 2
    fi

    if ! command -v "$1" > /dev/null 2>&1; then
        if [[ -n ${2-} ]]; then
            script_exit "Missing dependency: Couldn't locate $1." 1
        else
            verbose_print "Missing dependency: $1" "${fg_red-}"
            return 1
        fi
    fi

    verbose_print "Found dependency: $1"
    return 0
}

# check_binary()
#----------------------------
# DESC: Validate we have superuser access as root (via sudo if requested)
# ARGS: $1 (optional): Set to any value to not attempt root access via sudo
# OUTS: None
function check_superuser() {
    local superuser
    if [[ $EUID -eq 0 ]]; then
        superuser=true
    elif [[ -z ${1-} ]]; then
        if check_binary sudo; then
            verbose_print 'Sudo: Updating cached credentials ...'
            if ! sudo -v; then
                verbose_print "Sudo: Couldn't acquire credentials ..." \
                    "${fg_red-}"
            else
                local test_euid
                test_euid="$(sudo -H -- "$BASH" -c 'printf "%s" "$EUID"')"
                if [[ $test_euid -eq 0 ]]; then
                    superuser=true
                fi
            fi
        fi
    fi

    if [[ -z ${superuser-} ]]; then
        verbose_print 'Unable to acquire superuser credentials.' "${fg_red-}"
        return 1
    fi

    verbose_print 'Successfully acquired superuser credentials.'
    return 0
}

# check_superuser()
#----------------------------
# DESC: Run the requested command as root (via sudo if requested)
# ARGS: $1 (optional): Set to zero to not attempt execution via sudo
#       $@ (required): Passed through for execution as root user
# OUTS: None
function run_as_root() {
    if [[ $# -eq 0 ]]; then
        script_exit 'Missing required argument to run_as_root()!' 2
    fi

    if [[ ${1-} =~ ^0$ ]]; then
        local skip_sudo=true
        shift
    fi

    if [[ $EUID -eq 0 ]]; then
        "$@"
    elif [[ -z ${skip_sudo-} ]]; then
        sudo -H -- "$@"
    else
        script_exit "Unable to run requested command as root: $*" 1
    fi
}

# create_user()
#----------------------------
# DESC: Create a local user with given uid, guid and username.
# ARGS: $1 (required): username
#       $2 (required): uid
#       $3 (required): guid
#       $4 (optional): groupname
# OUTS: None
function create_user() {

    # Check
    if [[ $# -lt 3 ]]; then
        script_exit 'Missing required argument to create_user()!' 2
    fi
    
    # Local
    local local_username="$1"
    local local_uid="$2"
    local local_guid="$3"
    local local_group=$local_username
    [[ $# -eq 4 ]] && local_group="$4"
    
    # check to see if group exists; if not, create it
	if grep -q -E "^${local_group}:" /etc/group > /dev/null 2>&1; then
        print_log "Create group: Group exists; skipping creation" "DEBUG"
	else
        print_log "Create group: Group doesn't exist; creating..." "DEBUG"
        # create the group
        addgroup --gid "${local_guid}" "${local_group}" \
            || (print_log "Group exists but with a different name" "DEBUG"; \
            print_log "Renaming..." "DEBUG"; \
            groupmod --gid "${local_guid}" -n "${local_group}" \
            "$(awk -F ':' '{print $1":"$3}' < /etc/group \
            | grep ":${local_guid}$" | awk -F ":" '{print $1}')")
	fi

	# check to see if user exists; if not, create it
	if id -u "${local_username}" > /dev/null 2>&1; then
        print_log "INFO: User exists; skipping creation" ""
	else
        print_log "INFO: User doesn't exist; creating..." ""
	  
        # create the user
        adduser --gecos "" --uid "${local_uid}" \
            --ingroup "${local_group}" \
            --home "/home/${local_username}" \
            --shell "/bin/sh" \
            --disabled-password \
            "${local_username}"
	fi    
}

# print_log_catcher()
#----------------------------
# DESC: use while to send text piped in print_log()
# ARGS: $1 (optional): logs file
#       $2 (optional): set category of logs (<none>|REPO|BUILD)
#       $3 (optional): set type of logs (INFO|DEBUG|WARN|ERROR|FATAL)
# OUTS: None
function print_log_catcher() {
    
    # local
    local log_file=$LOG_FILE
    local category=""
    local type_of_log="INFO" # Force type to INFO if param is forgotten
    local type_of_log_line=""
    local print_term=$PRINT_TERMINAL
        
    # Check and get param
    if [[ $# -ge 1 ]] && [[ $1 != "" ]]; then    
        log_file=$1
    fi
    if [[ $# -ge 2 ]] && [[ $2 != "" ]]; then
        category=$2
    fi
    if [[ $# -gt 2 ]] && [[ $3 != "" ]]; then
        type_of_log=$3
    fi
    
    # Disbale print on screen if set
    [[ $category = "REPO" ]] && [[ $SILENT_REPO = true ]] \
        && PRINT_TERMINAL=false
    [[ $category = "BUILD" ]] && [[ $SILENT_BUILD = true ]] \
        && PRINT_TERMINAL=false
            
    # Get input lines
    while IFS= read -r line; do
        
        type_of_log_line=$type_of_log
        
        # Clean string
        line=${line//[$'\t\r\n']}
        
        # Detect Warning and errors in logs
        if [[ $category = "BUILD" ]]; then
            
            # Tag errors build
            [[ $line == *"fatal "* ]] \
                || [[ $line == *"failed "* ]]  \
                || [[ $line == *"error:"* ]] \
                || [[ $line == *" Error "* ]] \
                || [[ $line == *"Segmentation fault (core dumped)"* ]] \
                && type_of_log_line="ERROR"
                
            # Tag warning
            [[ $line == *"warning:"* ]] \
                && type_of_log_line="WARN"
        else        
            # Tag errors
            [[ $line == *"fatal"* ]] \
                || [[ $line == *"failed"* ]]  \
                || [[ $line == *"error"* ]] \
                && type_of_log_line="ERROR"
                
            # Tag warning
            [[ $line == *"warning"* ]] \
                && type_of_log_line="WARN"
        fi
        
        # Check print mode 
        if [[ $category = "BUILD" ]] && [[ "$SHOW_ERRORS_ONLY" = true ]]; then
 
            PRINT_TERMINAL=false
            
            # Print only
            [[ "$type_of_log_line" = "ERROR" ]] \
                || [[ "$type_of_log_line" = "WARN" ]] \
                && PRINT_TERMINAL=true 
                
            # Print logs
            print_log "$line" "$type_of_log_line" $log_file
            
            PRINT_TERMINAL=true
            
        else
            # Print logs
            print_log "$line" "$type_of_log_line" $log_file 
        fi
              
        #print_log "|$line|" "DEBUG" $log_file        
    done
    
    # set flad to previous state
    PRINT_TERMINAL=$print_term
}

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
