AC_PREREQ(2.52)
AC_INIT([GWorkspace], [0.6.1], [enrico@imago.ro])

#--------------------------------------------------------------------
# Use config.guess, config.sub and install-sh provided by gnustep-make
#--------------------------------------------------------------------
AC_CHECK_HEADERS(dir.h unistd.h)
AC_CHECK_FUNCS(getpwnam getpwuid geteuid getlogin)

AC_CONFIG_AUX_DIR([$GNUSTEP_MAKEFILES])
AC_CONFIG_HEADER([GWLib/config.h])
AC_CONFIG_HEADER([ContentViewers/PdfViewer/config.h])
AC_CONFIG_HEADER([GWorkspace/Inspectors/config.h])

#--------------------------------------------------------------------
# We need ghostscript for viewing Pdf's
#--------------------------------------------------------------------
AC_ARG_WITH([ghostscript], [  --with-ghostscript=PROG  Use PROG as ghostscript interpreter], [GS_PATH=$withval], [GS_PATH=none])

if test "x$GS_PATH" = "xnone"; then
	AC_PATH_PROGS([GS_PATH], [gs ghostscript], [none])
fi

AC_DEFINE_UNQUOTED([GSPATH], ["$GS_PATH"], [Path to ghostscript interpreter])

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


AC_CONFIG_FILES([GNUmakefile \
									GWLib/GNUmakefile \
									GWorkspace/GNUmakefile \
									GWorkspace/GWorkspaceInfo.plist \
									gworkspace.make])
AC_OUTPUT
