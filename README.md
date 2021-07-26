# docker-lineage-cicd

Docker microservice for LineageOS Continuous Integration and Continuous Deployment

## Note: different version

This version is not the original made by lineageos4microg.

The __`pakaoraki/docker-lineage-cicd`__ is a partly re-write docker image of the original [lineageos4microg/docker-lineage-cicd][lineageos4microg_docker], base on [this sources][lineageos4microg_src].

The original docker image was targeting MicroG spoofing modification for Lineageos. This re-writed version is focus for a pure vanilla Lineageos build. 
However, all MicroG patches options are still available as original lineageos4microg.

The sources scripts have been made by following the best practices from <https://github.com/ralish/bash-script-template>.

* Github sources: [pakaoraki/docker-lineage-cicd](#pakaoraki_src)
* DockerHub image: [docker_link](#pakaoraki_image)

## New features

List of changes made:

1. Add new options for building:
   * __`BUILD_VARIANT`__ : allow to choose buildtype (userdebug, release...).
   * __`SILENT`__, __`SILENT_BUILD`__, __`SILENT_REPO`__: mute print on terminal.
   * __`DEBUG_MODE`__, __`TRACE_MODE`__: debug options.
   * __`TEST_SCRIPT`__: ability to exec custom script without building for testing purpose.
2. Improve logs and screen visibility (add color, detect warning and errors, add new TIMESTAMP).
3. Do not create 'microg' overlay if not needed (for people who don't use MicroG spoofing patches).

Please read below for more details.

## Why Docker?

A fair number of dependencies is needed to build LineageOS, plus a Linux system
(and a discrete knowledge of it). With Docker we give you a minimal Linux build
system with all the tools and scripts already integrated, easing considerably
the creation of your own LineageOS build.

Moreover Docker runs also on Microsoft Windows and Mac OS, which means that
LineageOS can be built on such platforms without requiring a dual boot system
or a manual set up of a Virtual Machine.

## How do I install Docker?

The official Docker guides are well-written:

* Linux [Ubuntu](#docker-ubuntu), [Debian](#docker-debian),
   [CentOS][docker-centos] and [Fedora][docker-fedora] are officially
   supported)
* [Windows 10/Windows Server 2016 64bit](#docker-win)
* [Mac OS El Capitan 10.11 or newer](#docker-mac)

If your Windows or Mac system doesn't satisfy the requirements (or if you have
Oracle VirtualBox installed, you can use [Docker Toolbox][docker-toolbox].
Docker Toolbox is not described in this guide, but it should be very similar to
the standard Docker installation.

Once you can run the [`hello-world` image](#docker-helloworld) you're ready to
start!

## How can I build LineageOS?

This Docker image contains a great number of settings, to allow you to fully
customize your LineageOS build. Here you can find all of them, with the default
values between the brackets.

TL;DR - go to the [Examples](#examples)

### Fundamental settings

The two fundamental settings are:

* `BRANCH_NAME (lineage-17.1)`: LineageOS branch, see the branch list
   [here](#los-branches) (multiple comma-separated branches can be specified)
* `DEVICE_LIST`: comma-separated list of devices to build

Running a build with only these two set will create a ZIP file almost identical
to the LineageOS official builds, just signed with the test keys.

When multiple branches are selected, use `DEVICE_LIST_<BRANCH_NAME>` to specify
the list of devices for each specific branch (see [the examples](#examples)).

### Signature spoofing

There are two options for the [signature spoofing patch](#signature-spoofing)
required for [microG](#microg):

* "Original" [patches](#signature-spoofing-patches)
* Restricted patches

With the "original" patch the FAKE_SIGNATURE permission can be granted to any
user app: while it may seem handy, this is considered dangerous by a great
number of people, as the user could accidentally give this permission to rogue
apps.

A more strict option is the restricted patch, where the FAKE_SIGNATURE
permission can be obtained only by privileged system apps, embedded in the ROM
during the build process.

The signature spoofing patch can be optionally included with:

* `SIGNATURE_SPOOFING (no)`: `yes` to use the original patch, `restricted` for
   the restricted one, `no` for none of them

If in doubt, use `restricted`: note that packages that requires the
FAKE_SIGNATURE permission must be embedded in the build by adding them in

* `CUSTOM_PACKAGES`

Extra packages can be included in the tree by adding the corresponding manifest
XML to the local_manifests volume.

### Proprietary files

Some proprietary files are needed to create a LineageOS build, but they're not
included in the LineageOS repo for legal reasons. You can obtain these blobs in
three ways:

* by [pulling them from a running LineageOS](#blobs-pull)
* by [extracting them from a LineageOS ZIP](#blobs-extract)
* by downloading them from TheMuppets [GitHub](#blobs-themuppets) and
  [GitLab](#blobs-the-muppets) repositories (unofficial)

The third way is the easiest one and is enabled by default; if you're OK with
that just move on, otherwise set `INCLUDE_PROPRIETARY (true)` to `false` and
manually provide the blobs (not explained in this guide).

### Over the Air updates

To enable OTA for you builds, you need to run a server that speaks the protocol
understood by the [LineageOS updater app][updater] and provide the URL to this
server as `OTA_URL` variable for the build.

One implementation is [LineageOTA][lineageota], which is also available as Docker
image. Follow these steps to prepare your builds for OTA:

* Run the Docker image `julianxhokaxhiu/lineageota`
  * Port 80 exposed to the internet (might want to add an HTTPS reverse proxy)
  * The `/srv/zips` directory/volume of the CICD image mounted at
    `/var/www/html/builds/full` (can be read-only)
* Set environment variables when building
  * `ZIP_SUBDIR` to `false`
  * `OTA_URL` to the address of the OTA server, with `/api` appended

If you don't setup a OTA server you won't be able to update the device from the
updater app (but you can still update it manually with the recovery of course).

### Signing

By default, builds are signed with the Android test keys. If you want to sign
your builds with your own keys (**highly recommended**):

* __`SIGN_BUILDS (false)`__: set to `true` to sign the builds with the keys
   contained in `/srv/keys`; if no keys are present, a new set will be generated

### Userscripts

You can use custom scripts that can be executed at different specific time during the process.

1. Provide the volume with `-v "<folder>:/srv/userscripts"`
2. Add your custom scripts in your script directory corresponding to the userscipt volume.
3. Create the needed following file for calling your custom scripts:  
   * __`test.sh`__: for testing purpose (see below).
   * __`begin.sh`__: execute before repo sync and building.
   * __`before.sh`__: execute after repo sync and before building.
   * __`pre-build`__: execute just before each building images.
   * __`post-build`__: execute just after each building is done.
   * __`end.sh`__: execute at the end of the process.

Dev option:

* __`TEST_SCRIPT (false)`__: set to `true` to execute any scripts before syncing repo data and compiling. This allow you to test quickly your scripts: the dokcer image will stop just after. This can be useful in case of testing scripts before prod.

### Variant

There is 3 differents variants that you can chose to build an android.

| Buildtype | Use                                                                          |
| --------- | ---------------------------------------------------------------------------- |
| user      | Limited access; suited for production                                        |
| userdebug | Like user but with root access and debug capability; preferred for debugging |
| eng       | Development configuration with additional debugging tools                    |

*More information: [source](#android_build_source)*

You can specify buildtype with:

* **`BUILD_VARIANT (userdebug)`** : set to `eng`, `user` or `userdebug`(default).

### Other settings

Other useful settings are:

* __`CCACHE_SIZE (50G)`__: change this if you want to give more (or less) space to
   ccache
* **`WITH_SU (false)`**: set to `true` to embed `su` in the build (note that, even
   when set to `false`, you can still enable root by flashing the
   [su installable ZIP][los-extras])
* **`RELEASE_TYPE (UNOFFICIAL)`**: change the release type of your builds
* **`BUILD_OVERLAY (false)`**: normally each build is done on the source tree, then
   the tree is cleaned with `mka clean`. If you want to be sure that each build
   is isolated from the others, set `BUILD_OVERLAY` to `true` (longer build
   time). Requires `--cap-add=SYS_ADMIN`.
* **`LOCAL_MIRROR (false)`**: change this to `true` if you want to create a local
   mirror of the LineageOS source (> 200 GB)
* **`CRONTAB_TIME (now)`:** instead of building immediately and exit, build at the
   specified time (uses standard cron format)
* **`ZIP_SUBDIR (true)`**: Move the resulting zips to $ZIP_DIR/$codename instead of $ZIP_DIR/
* __`SILENT (false)`__: Don not print anything on terminal (does not affect logs). 
* **`SILENT_REPO_ (false)`**: Do not print any `repo` related operations on terminal (does not affect logs).
* **`SILENT_BUILD (false)`**: Do not print any buildind informations on terminal (does not affect logs).

  For dev pupose only:

* **`DEBUG_MODE (false)`**: Print some debug informations.
* **`TRACE_MODE (false)`**: Activate `set -o xtrace` inside scripts.

The full list of settings, including the less interesting ones not mentioned in
this guide, can be found in the [Dockerfile](#dockerfile).

## Volumes

You also have to provide Docker some volumes, where it'll store the source, the
resulting builds, the cache and so on. The volumes are:

* `/srv/src`, for the LineageOS sources
* `/srv/zips`, for the output builds
* `/srv/logs`, for the output logs
* `/srv/ccache`, for the ccache
* `/srv/local_manifests`, for custom manifests (optional)
* `/srv/userscripts`, for the user scripts (optional)

When `SIGN_BUILDS` is `true`

* `/srv/keys`, for the signing keys

When `BUILD_OVERLAY` is `true`

* `/srv/tmp`, for temporary files

When `LOCAL_MIRROR` is `true`:

* `/srv/mirror`, for the LineageOS mirror

## Examples

### Build for river (lineage-18.1, officially supported), test keys, no patches

```
docker run \
    -e "BRANCH_NAME=lineage-18.1" \
    -e "DEVICE_LIST=river" \
    -v "/home/user/lineage:/srv/src" \
    -v "/home/user/zips:/srv/zips" \
    -v "/home/user/logs:/srv/logs" \
    -v "/home/user/cache:/srv/ccache" \
    pakaoraki/docker-lineage-cicd
```

### Build for bacon (lineage-17.1, officially supported), custom keys, restricted signature spoofing with integrated microG and FDroid

```
docker run \
    -e "BRANCH_NAME=lineage-17.1" \
    -e "DEVICE_LIST=bacon" \
    -e "SIGN_BUILDS=true" \
    -e "SIGNATURE_SPOOFING=restricted" \
    -e "CUSTOM_PACKAGES=GmsCore GsfProxy FakeStore MozillaNlpBackend NominatimNlpBackend com.google.android.maps.jar FDroid FDroidPrivilegedExtension " \
    -v "/home/user/lineage:/srv/src" \
    -v "/home/user/zips:/srv/zips" \
    -v "/home/user/logs:/srv/logs" \
    -v "/home/user/cache:/srv/ccache" \
    -v "/home/user/keys:/srv/keys" \
    -v "/home/user/manifests:/srv/local_manifests" \
    pakaoraki/docker-lineage-cicd
```

If there are already keys in `/home/user/keys` they will be used, otherwise a
new set will be generated before starting the build (and will be used for every
subsequent build).

The microG and FDroid packages are not present in the LineageOS repositories,
and must be provided through an XML in the `/home/user/manifests`.
[This][prebuiltapks] repo contains some of the most common packages for these
kind of builds: to include it create an XML (the name is irrelevant, as long as
it ends with `.xml`) in the `/home/user/manifests` folder with this content:

```
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <project name="lineageos4microg/android_prebuilts_prebuiltapks" path="prebuilts/prebuiltapks" remote="github" revision="master" />
</manifest>
```

### Build for four devices on lineage-17.1 and lineage-18.1 (officially supported), custom keys, restricted signature spoofing with integrated microG and FDroid, custom OTA server

```
docker run \
    -e "BRANCH_NAME=lineage-17.1,lineage-18.1" \
    -e "DEVICE_LIST_LINEAGE_17_1=bacon,oneplus2" \
    -e "DEVICE_LIST_LINEAGE_18_1=river,lake" \
    -e "SIGN_BUILDS=true" \
    -e "SIGNATURE_SPOOFING=restricted" \
    -e "CUSTOM_PACKAGES=GmsCore GsfProxy FakeStore MozillaNlpBackend NominatimNlpBackend com.google.android.maps.jar FDroid FDroidPrivilegedExtension " \
    -e "OTA_URL=https://api.myserver.com/" \
    -v "/home/user/lineage:/srv/src" \
    -v "/home/user/zips:/srv/zips" \
    -v "/home/user/logs:/srv/logs" \
    -v "/home/user/cache:/srv/ccache" \
    -v "/home/user/keys:/srv/keys" \
    -v "/home/user/manifests:/srv/local_manifests" \
    pakaoraki/docker-lineage-cicd
```

### Build for a6000 (not officially supported), custom keys, restricted signature spoofing with integrated microG and FDroid

As there is no official support for this device, we first have to include the
sources in the source tree through an XML in the `/home/user/manifests` folder;
from [this](#a6000-xda) thread we get the links of:

* Device tree: https://github.com/dev-harsh1998/android_device_lenovo_a6000
* Common Tree: https://github.com/dev-harsh1998/android_device_lenovo_msm8916-common
* Kernel: https://github.com/dev-harsh1998/kernel_lenovo_msm8916
* Vendor blobs: https://github.com/dev-harsh1998/proprietary-vendor_lenovo

Then, with the help of lineage.dependencies from the
[device tree](#a6000-device-tree-deps) and the
[common tree](#a6000-common-tree-deps) we create an XML
`/home/user/manifests/a6000.xml` with this content:

```
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <project name="dev-harsh1998/android_device_lenovo_a6000" path="device/lenovo/a6000" remote="github" />
  <project name="dev-harsh1998/android_device_lenovo_msm8916-common" path="device/lenovo/msm8916-common" remote="github" />
  <project name="dev-harsh1998/kernel_lenovo_msm8916" path="kernel/lenovo/a6000" remote="github" />
  <project name="dev-harsh1998/proprietary-vendor_lenovo" path="vendor/lenovo" remote="github" />
  <project name="LineageOS/android_device_qcom_common" path="device/qcom/common" remote="github" />
</manifest>
```

We also want to include our custom packages so, like before, create an XML (for
example `/home/user/manifests/custom_packages.xml`) with this content:

```
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <project name="lineageos4microg/android_prebuilts_prebuiltapks" path="prebuilts/prebuiltapks" remote="github" revision="master" />
</manifest>
```

We also set `INCLUDE_PROPRIETARY=false`, as the proprietary blobs are already
provided by the repo
https://github.com/dev-harsh1998/prorietary_vendor_lenovo (so we
don't have to include the TheMuppets repo).

Now we can just run the build like it was officially supported:

```
docker run \
    -e "BRANCH_NAME=lineage-15.1" \
    -e "DEVICE_LIST=a6000" \
    -e "SIGN_BUILDS=true" \
    -e "SIGNATURE_SPOOFING=restricted" \
    -e "CUSTOM_PACKAGES=GmsCore GsfProxy FakeStore MozillaNlpBackend NominatimNlpBackend com.google.android.maps.jar FDroid FDroidPrivilegedExtension " \
    -e "INCLUDE_PROPRIETARY=false" \
    -v "/home/user/lineage:/srv/src" \
    -v "/home/user/zips:/srv/zips" \
    -v "/home/user/logs:/srv/logs" \
    -v "/home/user/cache:/srv/ccache" \
    -v "/home/user/keys:/srv/keys" \
    -v "/home/user/manifests:/srv/local_manifests" \
    pakaoraki/docker-lineage-cicd
```

## Build for starlte, star2lte (aka S9/S9+, not officially supported), custom keys, variant "user", mute repo verbose

As there is no official support for this device, we first have to include the
sources in the source tree through an XML in the `/home/user/manifests` folder;
from [this](#da_starlte) and [this](#xda2_starlte) threads we get the links of:

- Device tree: [GitHub - pakaoraki/android_device_samsung_starlte](https://github.com/pakaoraki/android_device_samsung_starlte)
- Common Tree: [GitHub - pakaoraki/android_device_samsung_universal9810-common](https://github.com/pakaoraki/android_device_samsung_universal9810-common)
- Kernel: [GitHub - pakaoraki/android_kernel_samsung_universal9810](https://github.com/pakaoraki/android_kernel_samsung_universal9810)
- Vendor blobs: [GitHub - pakaoraki/proprietary_vendor_samsung](https://github.com/pakaoraki/proprietary_vendor_samsung)

Then, with the help of lineage.dependencies we create an XML (available [here](#pakaoraki_local_manifest)) `/home/user/manifests/local_manifest.xml` with this content:

```
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
    <project name="pakaoraki/android_kernel_samsung_universal9810" path="kernel/samsung/universal9810" remote="github" revision="4.9.118" />
    <project name="pakaoraki/android_device_samsung_universal9810-common" path="device/samsung/universal9810-common" remote="github" revision="lineage-18.1" />
    <project name="pakaoraki/android_device_samsung_crownlte" path="device/samsung/crownlte" remote="github" revision="lineage-18.1" />
    <project name="pakaoraki/android_device_samsung_star2lte" path="device/samsung/star2lte" remote="github" revision="lineage-18.1" />
    <project name="pakaoraki/android_device_samsung_starlte" path="device/samsung/starlte" remote="github" revision="lineage-18.1" />
    <project name="pakaoraki/proprietary_vendor_samsung" path="vendor/samsung" remote="github" revision="lineage-18.1" />
    <project name="LineageOS/android_hardware_samsung" path="hardware/samsung" remote="github" revision="lineage-18.1" />
</manifest>
```

We also set `INCLUDE_PROPRIETARY=false`, as the proprietary blobs are already
provided by the repo https://github.com/pakaoraki/proprietary_vendor_samsung (so we don't have to include the TheMuppets repo).

```
docker run \
    -e "BRANCH_NAME=lineage-18.1" \
    -e "BUILD_VARIANT=user"
    -e "DEVICE_LIST=starlte" \
    -e "SIGN_BUILDS=true" \
    -e "SILENT_REPO=true"
    -e "INCLUDE_PROPRIETARY=false" \
    -v "/home/user/lineage:/srv/src" \
    -v "/home/user/zips:/srv/zips" \
    -v "/home/user/logs:/srv/logs" \
    -v "/home/user/cache:/srv/ccache" \
    -v "/home/user/keys:/srv/keys" \
    -v "/home/user/manifests:/srv/local_manifests" \
    pakaoraki/docker-lineage-cicd
```

[lineageos4microg_src]: https://github.com/lineageos4microg/docker-lineage-cicd (lineageos4microg Github sources)
[lineageos4microg_docker]: https://hub.docker.com/r/lineageos4microg/docker-lineage-cicd/Dockerfile (lineageos4microg Docker image)
[pakaoraki_src]: https://github.com/pakaoraki/docker-lineage-cicd (pakaoraki Github sources)
[pakaoraki_local_manifest]: https://github.com/pakaoraki/local_manifests (pakaoraki Github manifest)
[android_build_source]: https://developer.android.com/reference/tools/gradle-api/4.1/com/android/build/api/variant/Variant
[xda_starlte]: https://forum.xda-developers.com/t/rom-s9-s9-unofficial-lineageos-18-1-21-03-2021.4203777/ (XDA Forum S9/S9+ Lineage 18.1)
[xda2_starlte]: https://forum.xda-developers.com/t/rom-s9-s9-unofficial-lineageos-18-1-weekly.4302901/ (XDA Forum S9/S9+ - weekly - Lineage 18.1)
[docker-ubuntu]: https://docs.docker.com/install/linux/docker-ce/ubuntu/
[docker-debian]: https://docs.docker.com/install/linux/docker-ce/debian/
[docker-centos]: https://docs.docker.com/install/linux/docker-ce/centos/
[docker-fedora]: https://docs.docker.com/install/linux/docker-ce/fedora/
[docker-win]: https://docs.docker.com/docker-for-windows/install/
[docker-mac]: https://docs.docker.com/docker-for-mac/install/
[docker-toolbox]: https://docs.docker.com/toolbox/overview/
[docker-helloworld]: https://docs.docker.com/get-started/#test-docker-installation
[los-branches]: https://github.com/LineageOS/android/branches
[signature-spoofing]: https://github.com/microg/android_packages_apps_GmsCore/wiki/Signature-Spoofing
[microg]: https://microg.org/
[signature-spoofing-patches]: src/signature_spoofing_patches/
[blobs-pull]: https://wiki.lineageos.org/devices/bacon/build#extract-proprietary-blobs
[blobs-extract]: https://wiki.lineageos.org/extracting_blobs_from_zips.html
[blobs-themuppets]: https://github.com/TheMuppets/manifests
[blobs-the-muppets]: https://gitlab.com/the-muppets/manifest
[lineageota]: https://github.com/julianxhokaxhiu/LineageOTA
[updater]: https://github.com/LineageOS/android_packages_apps_Updater
[los-extras]: https://download.lineageos.org/extras
[dockerfile]: Dockerfile
[prebuiltapks]: https://github.com/lineageos4microg/android_prebuilts_prebuiltapks
[a6000-xda]: https://forum.xda-developers.com/lenovo-a6000/development/rom-lineageos-15-1-t3733747
[a6000-device-tree-deps]: https://github.com/dev-harsh1998/android_device_lenovo_a6000/blob/lineage-15.1/lineage.dependencies
[a6000-common-tree-deps]: https://github.com/dev-harsh1998/android_device_lenovo_msm8916-common/blob/lineage-15.1/lineage.dependencies
