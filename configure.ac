AC_INIT(gworkspace, 1.1.0)
AC_PREREQ(2.71)

if test -z "$GNUSTEP_MAKEFILES"; then
  AC_MSG_ERROR([You must run the GNUstep initialization script first!])
fi

#--------------------------------------------------------------------
# Find the compiler
#--------------------------------------------------------------------
MAKECC=`gnustep-config --variable=CC`
MAKECPP=`gnustep-config --variable=CPP`
MAKECXX=`gnustep-config --variable=CXX`
if test "$CC" = ""; then
  CC=$MAKECC
  export CC
else
  if test "$CC" != "$MAKECC"; then
    AC_MSG_WARN([You are running configure with the compiler ($CC) set to a different value from that used by gnustep-make ($MAKECC).  To avoid conflicts/problems, reconfigure/reinstall gnustep-make to use CC=$CC or run the gnustep-base configure again with your CC environment variable set to $MAKECC])
  fi
fi
if test "$CPP" = ""; then
  CPP=$MAKECPP
  export CPP
else
  if test "$CPP" != "$MAKECPP"; then
    AC_MSG_WARN([You are running configure with the preprocessor ($CPP) set to a different value from that used by gnustep-make ($MAKECPP).  To avoid conflicts/problems, reconfigure/reinstall gnustep-make to use CPP=$CPP or run the gnustep-base configure again with your CPP environment variable set to $MAKECPP])
  fi
fi
if test "$CXX" = ""; then
  CXX=$MAKECXX
  export CXX
else
  if test "$CXX" != "$MAKECXX"; then
    AC_MSG_WARN([You are running configure with the compiler ($CXX) set to a different value from that used by gnustep-make ($MAKECXX).  To avoid conflicts/problems, reconfigure/reinstall gnustep-make to use CXX=$CXX or run the gnustep-base configure again with your CXX environment variable set to $MAKECXX])
  fi
fi
AC_PROG_CC
AC_PROG_CPP

AC_SUBST(CC)
AC_SUBST(CPP)
AC_SUBST(CXX)

#--------------------------------------------------------------------
# Use config.guess, config.sub and install-sh provided by gnustep-make
#--------------------------------------------------------------------
AC_CONFIG_AUX_DIR([$GNUSTEP_MAKEFILES])

AC_CHECK_HEADERS(dir.h unistd.h sys/resource.h)
AC_CHECK_FUNCS(getpwnam getpwuid geteuid getlogin)

AC_CONFIG_AUX_DIR([$GNUSTEP_MAKEFILES])

AC_CONFIG_SUBDIRS([FSNode Inspector])


AC_ARG_ENABLE(gwmetadata,
  [  --enable-gwmetadata     Enable GWMetadata], , [enable_gwmetadata=no])

if test "x$enable_gwmetadata" = "xyes"; then
  AC_CONFIG_SUBDIRS([GWMetadata])
  BUILD_GWMETADATA=1
else
  BUILD_GWMETADATA=0
fi
AC_SUBST(BUILD_GWMETADATA)

AC_CONFIG_HEADERS([GWorkspace/config.h])


#--------------------------------------------------------------------
# Debug logging
#--------------------------------------------------------------------
AC_ARG_ENABLE(debug_log,
  [  --enable-debug-log      Enable debug logging],,
      enable_debug_log=no)

if test "$enable_debug_log" = "yes"; then
 GW_DEBUG_LOG=1
else
 GW_DEBUG_LOG=0
fi

AC_DEFINE_UNQUOTED([GW_DEBUG_LOG], [$GW_DEBUG_LOG], [debug logging])

#--------------------------------------------------------------------
# fswatcher-inotify
#--------------------------------------------------------------------
AC_ARG_WITH(inotify,
  [  --with-inotify  Build fswatcher-inotify],
  with_inotify=yes, with_inotify=no)
  
AC_SUBST(with_inotify)

AC_CONFIG_FILES([
  GNUmakefile
  GWorkspace/GNUmakefile
  Tools/fswatcher/GNUmakefile
  ])

AC_OUTPUT
