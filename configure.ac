AC_PREREQ(2.52)
AC_INIT([GWorkspace], [0.6.3], [enrico@imago.ro])

if test -z "$GNUSTEP_SYSTEM_ROOT"; then
  AC_MSG_ERROR([You must run the GNUstep initialization script first!])
fi

#--------------------------------------------------------------------
# Use config.guess, config.sub and install-sh provided by gnustep-make
#--------------------------------------------------------------------
AC_CHECK_HEADERS(dir.h unistd.h)
AC_CHECK_FUNCS(getpwnam getpwuid geteuid getlogin)

AC_CONFIG_AUX_DIR([$GNUSTEP_MAKEFILES])
AC_CONFIG_HEADER([GWLib/config.h])

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
PDFKIT="0"

HDIR=$GNUSTEP_LOCAL_ROOT/Library/Headers/PDFKit

if test -d $HDIR; then
  if test -f "$HDIR/PDFDocument.h"; then
    if test -f "$HDIR/PDFImageRep.h"; then
      PDFKIT="1"
    fi
  fi
fi

if test  $PDFKIT = "0"; then
  echo ""
  echo "The PDFKit framework can't be found."
  echo "The pdf viewer will not be built"
  echo ""
fi



AC_CONFIG_FILES([GNUmakefile \
									GWLib/GNUmakefile \
									GWorkspace/GNUmakefile \
									GWorkspace/GWorkspaceInfo.plist \
									gworkspace.make \
                  Inspector/GNUmakefile \
                  Inspector/InspectorInfo.plist \
                  Inspector/inspector.make])
AC_OUTPUT
