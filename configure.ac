AC_PREREQ(2.52)
AC_INIT(gworkspace, 0.9.4)

if test -z "$GNUSTEP_MAKEFILES"; then
  AC_MSG_ERROR([You must run the GNUstep initialization script first!])
fi


#--------------------------------------------------------------------
# Find the compiler
#--------------------------------------------------------------------
if test "$CC" = ""; then
  CC=`gnustep-config --variable=CC`
fi
if test "$CPP" = ""; then
  CPP=`gnustep-config --variable=CPP`
fi
if test "$CXX" = ""; then
  CXX=`gnustep-config --variable=CXX`
fi
AC_PROG_CC
AC_PROG_CPP

MAKECC=`gnustep-config --variable=CC`
if test "$CC" != "$MAKECC"; then
  AC_MSG_ERROR([You are running configure with the compiler ($CC) set to a different value from that used by gnustep-make ($MAKECC).  Please run configure again with your environment set to match your gnustep-make])
  exit 1
fi

#--------------------------------------------------------------------
# Use config.guess, config.sub and install-sh provided by gnustep-make
#--------------------------------------------------------------------
AC_CONFIG_AUX_DIR([$GNUSTEP_MAKEFILES])

AC_CHECK_HEADERS(dir.h unistd.h sys/resource.h)
AC_CHECK_FUNCS(getpwnam getpwuid geteuid getlogin)

AC_CONFIG_AUX_DIR([$GNUSTEP_MAKEFILES])

AC_CONFIG_SUBDIRS([FSNode DBKit Inspector])


AC_ARG_ENABLE(gwmetadata,
  [  --enable-gwmetadata     Enable GWMetadata], , [enable_gwmetadata=no])

if test "x$enable_gwmetadata" = "xyes"; then
  AC_CONFIG_SUBDIRS([GWMetadata])
  BUILD_GWMETADATA=1
else
  BUILD_GWMETADATA=0
fi
AC_SUBST(BUILD_GWMETADATA)

AC_CONFIG_HEADER([GWorkspace/config.h])


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
  GWorkspace/Finder/Modules/FModuleAnnotations/GNUmakefile
  GWorkspace/Finder/Modules/FModuleContents/GNUmakefile
  GWorkspace/Finder/Modules/FModuleCrDate/GNUmakefile
  GWorkspace/Finder/Modules/FModuleKind/GNUmakefile
  GWorkspace/Finder/Modules/FModuleModDate/GNUmakefile
  GWorkspace/Finder/Modules/FModuleName/GNUmakefile
  GWorkspace/Finder/Modules/FModuleOwner/GNUmakefile
  GWorkspace/Finder/Modules/FModuleSize/GNUmakefile
  Operation/GNUmakefile
  Recycler/GNUmakefile
  Tools/fswatcher/GNUmakefile
  ])

AC_OUTPUT
