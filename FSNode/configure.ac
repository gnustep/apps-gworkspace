AC_PREREQ(2.52)
AC_INIT

if test -z "$GNUSTEP_MAKEFILES"; then
  AC_MSG_ERROR([You must run the GNUstep initialization script first!])
fi

#--------------------------------------------------------------------
# Use config.guess, config.sub and install-sh provided by gnustep-make
#--------------------------------------------------------------------
AC_CONFIG_AUX_DIR([$GNUSTEP_MAKEFILES])

#--------------------------------------------------------------------
# Support for determining mountpoints
#--------------------------------------------------------------------
AC_CHECK_FUNCS(getmntinfo)

AC_CHECK_HEADERS(mntent.h)
AC_CHECK_HEADERS(sys/types.h sys/mntent.h)

# support for NetBSD > 3.x
AC_CHECK_HEADERS(sys/statvfs.h)

AC_CHECK_MEMBER(struct mntent.mnt_dir,[AC_DEFINE(MNT_FSNAME,mnt_fsname,mntent structure member name)],,[#include <mntent.h>])
AC_CHECK_MEMBER(struct mntent.mnt_mountp,[AC_DEFINE(MNT_FSNAME,mnt_special,mntent structure member name)],,[#include <sys/mntent.h>])

AC_CHECK_MEMBER(struct mntent.mnt_dir,[AC_DEFINE(MNT_DIR,mnt_dir,mntent structure member name)],,[#include <mntent.h>])
AC_CHECK_MEMBER(struct mntent.mnt_mountp,[AC_DEFINE(MNT_DIR,mnt_mountp,mntent structure member name)],,[#include <sys/mntent.h>])

AC_CHECK_MEMBER(struct mntent.mnt_dir,[AC_DEFINE(MNT_FSTYPE,mnt_type,mntent structure member name)],,[#include <mntent.h>])
AC_CHECK_MEMBER(struct mntent.mnt_mountp,[AC_DEFINE(MNT_FSTYPE,mnt_fstype,mntent structure member name)],,[#include <sys/mntent.h>])

AC_FUNC_GETMNTENT

#--------------------------------------------------------------------
# Debug logging
#--------------------------------------------------------------------
AC_ARG_ENABLE(debug_log,
  [  --enable-debug-log  		Enable debug logging],,
      enable_debug_log=no)

if test "$enable_debug_log" = "no"; then
 GW_DEBUG_LOG=0
else
 GW_DEBUG_LOG=1
fi

AC_DEFINE_UNQUOTED([GW_DEBUG_LOG], [$GW_DEBUG_LOG], [debug logging])

AC_CONFIG_HEADER([config.h])


AC_OUTPUT
