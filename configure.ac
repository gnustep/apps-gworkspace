AC_PREREQ(2.52)
AC_INIT([GWorkspace], [0.6.5], [enrico@imago.ro])

if test -z "$GNUSTEP_SYSTEM_ROOT"; then
  AC_MSG_ERROR([You must run the GNUstep initialization script first!])
fi

#--------------------------------------------------------------------
# Use config.guess, config.sub and install-sh provided by gnustep-make
#--------------------------------------------------------------------
AC_CHECK_HEADERS(dir.h unistd.h)
AC_CHECK_FUNCS(getpwnam getpwuid geteuid getlogin)

AC_CONFIG_AUX_DIR([$GNUSTEP_MAKEFILES])
AC_CONFIG_HEADER([Finder/config.h])

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
save_CPPFLAGS="$CPPFLAGS"
CPPFLAGS="$CPPFLAGS -x objective-c -I$GNUSTEP_SYSTEM_ROOT/Library/Headers -I$GNUSTEP_LOCAL_ROOT/Library/Headers"

AC_CHECK_HEADERS(PDFKit/PDFDocument.h, have_pdfkit=yes, have_pdfkit=no)

if test "$have_pdfkit" = no; then
  AC_MSG_NOTICE([The PDFKit framework can't be found.])
  AC_MSG_NOTICE([The pdf viewer will not be built.])  
fi

AC_SUBST(have_pdfkit)

CPPFLAGS="$save_CPPFLAGS"


#--------------------------------------------------------------------
# We need SQLite
#--------------------------------------------------------------------
AC_CHECK_HEADERS(asdasdasd.h, have_sqlite=yes, have_sqlite=no)
if test "$have_sqlite" = yes; then
  AC_CHECK_LIB(sqlite3, sqlite3_open, have_sqlite=yes, have_sqlite=no)
fi

if test "$have_sqlite" = yes; then
  AC_DEFINE_UNQUOTED([SQLITE], [1], [])
else
  AC_DEFINE_UNQUOTED([SQLITE], [0], [])
  AC_MSG_NOTICE([The SQLite library can't be found.])
  AC_MSG_NOTICE([The live search folders will not be built.])  
fi

AC_SUBST(have_sqlite)


AC_CONFIG_FILES([GNUmakefile \
									GWorkspace/GNUmakefile \
									GWorkspace/GWorkspaceInfo.plist \
									gworkspace.make \
                  Inspector/GNUmakefile \
                  Inspector/InspectorInfo.plist \
                  Inspector/inspector.make \
                  Finder/GNUmakefile])
AC_OUTPUT
