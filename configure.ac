AC_PREREQ(2.52)
AC_INIT

if test -z "$GNUSTEP_SYSTEM_ROOT"; then
  AC_MSG_ERROR([You must run the GNUstep initialization script first!])
fi

#--------------------------------------------------------------------
# Use config.guess, config.sub and install-sh provided by gnustep-make
#--------------------------------------------------------------------
AC_CHECK_HEADERS(dir.h unistd.h)
AC_CHECK_FUNCS(getpwnam getpwuid geteuid getlogin)

AC_CONFIG_AUX_DIR([$GNUSTEP_MAKEFILES])

AC_CONFIG_SUBDIRS(Inspector)

AC_CONFIG_FILES([GNUmakefile \
									Tools/ddbd/GNUmakefile \
									GWorkspace/GNUmakefile \
									GWorkspace/GWorkspaceInfo.plist \
									gworkspace.make])
AC_OUTPUT


