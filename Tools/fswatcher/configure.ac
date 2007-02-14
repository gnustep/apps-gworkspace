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

#--------------------------------------------------------------------
# fswatcher-inotify
#--------------------------------------------------------------------
AC_ARG_WITH(inotify,
  [  --with-inotify  Build fswatcher-inotify],
  with_inotify=yes, with_inotify=no)
  
AC_SUBST(with_inotify)

#--------------------------------------------------------------------
# fswatcher-fam
#--------------------------------------------------------------------
AC_ARG_WITH(fam,
  [  --with-fam  Build fswatcher-fam],
  with_fam=yes, with_fam=no)
  
AC_SUBST(with_fam)


AC_DEFINE_UNQUOTED([GW_DEBUG_LOG], [$GW_DEBUG_LOG], [debug logging])

AC_CONFIG_HEADER([config.h])

AC_CONFIG_FILES([GNUmakefile])

AC_OUTPUT
