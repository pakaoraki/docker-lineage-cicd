FROM ubuntu:20.04
LABEL maintainer="Pakaoraki <pakaoraki@gmx.com>"

# Environment variables
#######################

ENV MIRROR_DIR /srv/mirror
ENV SRC_DIR /srv/src
ENV TMP_DIR /srv/tmp
ENV CCACHE_DIR /srv/ccache
ENV ZIP_DIR /srv/zips
ENV LMANIFEST_DIR /srv/local_manifests
ENV KEYS_DIR /srv/keys
ENV LOGS_DIR /srv/logs
ENV USERSCRIPTS_DIR /srv/userscripts

ENV DEBIAN_FRONTEND noninteractive
ENV USER root
#ENV USER lineage_builder

# Enable color in terminal
ENV TERM xterm-256color

# Main log file: will be init in script
ENV LOG_FILE ''

# Configurable environment variables
####################################

# ******* DEV *******

# Debug mode
ENV DEBUG_MODE false

# Trace mode
ENV TRACE_MODE false

# DEV MODE ONLY: use to test custom scripts at startup (after Init.sh script).
# You need to create a test.sh script in custom script directory.
# NO BUILD WILL BE PROCESSING: it will exit after executing custom script. 
ENV TEST_SCRIPT false

# *******************

# Local username to create and use (default 'false': use root).
ENV LOCAL_USER 'false'

# If local username is used, need local uid and guid (<UID>:<GUID>).
ENV LOCAL_UID '1001:1001'

# Default user dir
ENV USER_DIR '/root'

# Enable repo sync before building
ENV REPO_SYNC 'true'

# Select what to print on the screen (does not apply to logs)
# all|silent|no_repo|no_build|no_repo_build|build_errors
ENV PRINT_MODE 'all'

# Format date timestamp used in logs and generated by 'date' command.
# default: +%d/%m/%Y-%T,  will print "...[03/08/2021-14:02:43]...".
# (see man date for more details: https://man7.org/linux/man-pages/man1/date.1.html)
ENV TIMESTAMP '+%d/%m/%Y-%T'
    
# By default we want to use CCACHE, you can disable this
# WARNING: disabling this may slow down a lot your builds!
ENV USE_CCACHE 1

# ccache maximum size. It should be a number followed by an optional suffix: k,
# M, G, T (decimal), Ki, Mi, Gi or Ti (binary). The default suffix is G. Use 0
# for no limit.
ENV CCACHE_SIZE 50G

# We need to specify the ccache binary since it is no longer packaged along with AOSP
ENV CCACHE_EXEC /usr/bin/ccache

# Environment for the LineageOS branches name
# See https://github.com/LineageOS/android/branches for possible options
ENV BRANCH_NAME 'lineage-17.1'

# Environment for the device list (separate by comma if more than one)
# eg. DEVICE_LIST=hammerhead,bullhead,angler
ENV DEVICE_LIST ''

# Release type string
ENV RELEASE_TYPE 'UNOFFICIAL'

# Type of build
# Possible values: 'user|userdebug|eng', default is 'userdebug'
ENV BUILD_VARIANT 'userdebug'

# OTA URL that will be used inside CMUpdater
# Use this in combination with LineageOTA to make sure your device can auto-update itself from this buildbot
ENV OTA_URL ''

# User identity
ENV USER_NAME 'LineageOS Buildbot'
ENV USER_MAIL 'lineageos-buildbot@docker.host'

# Include proprietary files, downloaded automatically from github.com/TheMuppets/ and gitlab.com/the-muppets/
# Only some branches are supported
ENV INCLUDE_PROPRIETARY true

# Mount an overlay filesystem over the source dir to do each build on a clean source
ENV BUILD_OVERLAY false

# Clone the full LineageOS mirror (> 200 GB)
ENV LOCAL_MIRROR false

# If you want to preserve old ZIPs set this to 'false'
ENV CLEAN_OUTDIR false

# Change this cron rule to what fits best for you
# Use 'now' to start the build immediately
# For example, '0 10 * * *' means 'Every day at 10:00 UTC'
ENV CRONTAB_TIME 'now'

# Clean artifacts output after each build
ENV CLEAN_AFTER_BUILD true

# Provide root capabilities builtin inside the ROM (see http://lineageos.org/Update-and-Build-Prep/)
ENV WITH_SU false

# Provide a default JACK configuration in order to avoid out-of-memory issues
ENV ANDROID_JACK_VM_ARGS "-Dfile.encoding=UTF-8 -XX:+TieredCompilation -Xmx4G"

# Custom packages to be installed
ENV CUSTOM_PACKAGES ''

# Sign the builds with the keys in $KEYS_DIR
ENV SIGN_BUILDS false

# When SIGN_BUILDS = true but no keys have been provided, generate a new set with this subject
ENV KEYS_SUBJECT '/C=US/ST=California/L=Mountain View/O=Android/OU=Android/CN=Android/emailAddress=android@android.com'

# Move the resulting zips to $ZIP_DIR/$codename instead of $ZIP_DIR/
ENV ZIP_SUBDIR true

# Write the verbose logs to $LOGS_DIR/$codename instead of $LOGS_DIR/
ENV LOGS_SUBDIR true

# Apply the MicroG's signature spoofing patch
# Valid values are "no", "yes" (for the original MicroG's patch) and
# "restricted" (to grant the permission only to the system privileged apps).
#
# The original ("yes") patch allows user apps to gain the ability to spoof
# themselves as other apps, which can be a major security threat. Using the
# restricted patch and embedding the apps that requires it as system privileged
# apps is a much secure option. See the README.md ("Custom mode") for an
# example.
ENV SIGNATURE_SPOOFING "no"

# Delete old zips in $ZIP_DIR, keep only the N latest one (0 to disable)
ENV DELETE_OLD_ZIPS 0

# Delete old logs in $LOGS_DIR, keep only the N latest one (0 to disable)
ENV DELETE_OLD_LOGS 0

# You can optionally specify a USERSCRIPTS_DIR volume containing these scripts:
#  * begin.sh, run at the very beginning
#  * before.sh, run after the syncing and patching, before starting the builds
#  * pre-build.sh, run before the build of every device
#  * post-build.sh, run after the build of every device
#  * end.sh, run at the very end
# Each script will be run in $SRC_DIR and must be owned and writeable only by
# root

# Create Volume entry points
############################
VOLUME $MIRROR_DIR
VOLUME $SRC_DIR
VOLUME $TMP_DIR
VOLUME $CCACHE_DIR
VOLUME $ZIP_DIR
VOLUME $LMANIFEST_DIR
VOLUME $KEYS_DIR
VOLUME $LOGS_DIR
VOLUME $USERSCRIPTS_DIR

# Create missing directories
############################
RUN mkdir -p $MIRROR_DIR $SRC_DIR $TMP_DIR $CCACHE_DIR $ZIP_DIR $LMANIFEST_DIR \
      $KEYS_DIR $LOGS_DIR $USERSCRIPTS_DIR

# Install build dependencies
############################
RUN apt-get -qq update && \
      apt-get install -y sudo tzdata jq bc bison bsdmainutils build-essential ccache cgpt clang \
      cron curl flex g++-multilib gcc-multilib git gnupg gperf imagemagick \
      kmod lib32ncurses5-dev lib32readline-dev lib32z1-dev liblz4-tool \
      libncurses5 libncurses5-dev libsdl1.2-dev libssl-dev libxml2 \
      libxml2-utils lsof lzop maven openjdk-8-jdk pngcrush procps \
      python rsync schedtool squashfs-tools wget xdelta3 xsltproc yasm zip \
      zlib1g-dev \
      && rm -rf /var/lib/apt/lists/*

RUN curl https://storage.googleapis.com/git-repo-downloads/repo > /usr/local/bin/repo && \
      chmod a+x /usr/local/bin/repo

# Copy required files
#####################
COPY src/ /$USER_DIR/

# Allow redirection of stdout to docker logs
############################################
RUN ln -sf /proc/1/fd/1 /var/log/docker.log

# Set the work directory
########################
WORKDIR $SRC_DIR

# Set the entry point to init.sh
################################
ENTRYPOINT /$USER_DIR/init.sh
