
AC_INIT

#--------------------------------------------------------------------
# Use config.guess, config.sub and install-sh provided by gnustep-make
#--------------------------------------------------------------------

AC_CONFIG_AUX_DIR($GNUSTEP_MAKEFILES)
AC_CONFIG_HEADER(config.h)

AC_PATH_PROGS(GS_PATH, gs ghostscript, none) 

AC_DEFINE_UNQUOTED(GSPATH, "$GS_PATH") 

AC_OUTPUT

