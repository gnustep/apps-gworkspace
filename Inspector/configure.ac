AC_PREREQ(2.52)
AC_INIT

if test -z "$GNUSTEP_MAKEFILES"; then
  AC_MSG_ERROR([You must set GNUSTEP_MAKEFILES or run the GNUstep initialization script first!])
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
AC_CHECK_HEADERS(dir.h unistd.h)
AC_CHECK_FUNCS(getpwnam getpwuid geteuid getlogin)

AC_CONFIG_AUX_DIR([$GNUSTEP_MAKEFILES])
AC_CONFIG_HEADER([config.h])


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

#--------------------------------------------------------------------
# We need sh
#--------------------------------------------------------------------
AC_ARG_WITH([sh], [  --with-sh=PROG  Use PROG as sh interpreter], [SH_PATH=$withval], [SH_PATH=none])

if test "x$SH_PATH" = "xnone"; then
	AC_PATH_PROGS([SH_PATH], [sh bash], [none])
fi

AC_DEFINE_UNQUOTED([SHPATH], ["$SH_PATH"], [Path to sh interpreter])

#--------------------------------------------------------------------
# We need file
#--------------------------------------------------------------------
AC_ARG_WITH([file], [  --with-file=PROG  Use PROG as file], [FILE_PATH=$withval], [FILE_PATH=none])

if test "x$FILE_PATH" = "xnone"; then
	AC_PATH_PROGS([FILE_PATH], [file file], [none])
fi

AC_DEFINE_UNQUOTED([FILEPATH], ["$FILE_PATH"], [Path to file])

#--------------------------------------------------------------------
# We need PDFKit
#--------------------------------------------------------------------
case "$target_os" in
  darwin*)
    AC_CHECK_PDFKIT_DARWIN(have_pdfkit=yes, have_pdfkit=no)
    ;;
  *)	
    AC_CHECK_PDFKIT(have_pdfkit=yes, have_pdfkit=no)
    ;;
esac

if test "$have_pdfkit" = "no"; then
  AC_MSG_NOTICE([The PDFKit framework can't be found.])
  AC_MSG_NOTICE([The pdf viewer will not be built.])  
fi

AC_SUBST(have_pdfkit)

AC_CONFIG_FILES([
  GNUmakefile
  ContentViewers/GNUmakefile
  ])
AC_OUTPUT

