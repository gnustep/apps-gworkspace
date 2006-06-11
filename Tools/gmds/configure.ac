AC_PREREQ(2.52)
AC_INIT

if test -z "$GNUSTEP_SYSTEM_ROOT"; then
  AC_MSG_ERROR([You must run the GNUstep initialization script first!])
fi

AC_CONFIG_AUX_DIR([$GNUSTEP_MAKEFILES])

AC_CONFIG_HEADER([ddbd/config.h])
AC_CONFIG_HEADER([mdextractor/config.h])

AC_CONFIG_SUBDIRS(gmds)

AC_CANONICAL_TARGET([])
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

AC_OUTPUT




