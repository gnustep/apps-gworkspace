AC_PREREQ(2.52)
AC_INIT

if test -z "$GNUSTEP_SYSTEM_ROOT"; then
  AC_MSG_ERROR([You must run the GNUstep initialization script first!])
fi

AC_CONFIG_AUX_DIR([$GNUSTEP_MAKEFILES])

AC_CHECK_HEADER(sqlite3.h, have_sqlite=yes, have_sqlite=no)
if test "$have_sqlite" = yes; then
  AC_CHECK_LIB(sqlite3, sqlite3_get_table)  
  if test "$ac_cv_lib_sqlite3_sqlite3_get_table" = no; then
     have_sqlite=no
  fi
fi

if test "$have_sqlite" = yes; then
  AC_LANG_SAVE
  AC_LANG_C
  ac_save_CFLAGS="$CFLAGS"
  ac_save_LIBS="$LIBS"
  LIBS="$LIBS -lsqlite3"

  AC_TRY_RUN([
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>
    #include <sqlite3.h>

int main ()
{
  unsigned vnum = sqlite3_libversion_number();
  
  printf("sqlite3 version number %d\n", vnum);
  return !(vnum >= 3002008);
}
  ],, have_sqlite=no,[echo "wrong sqlite3 version"])

  CFLAGS="$ac_save_CFLAGS"
  LIBS="$ac_save_LIBS"
  AC_LANG_RESTORE

  if test "$have_sqlite" = no; then
    AC_MSG_ERROR(wrong sqlite3 version. sqlite3 >= 3.2.8 required.)
  fi

else 
  AC_MSG_WARN(Cannot find sqlite3 header and/or library)
  echo "* The gmds tool reqiures the sqlite3 library"
  AC_MSG_ERROR(gmds will not compile without sqlite3)
fi


# AC_CONFIG_SUBDIRS(Inspector)

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


AC_CONFIG_HEADER([config.h])

AC_CONFIG_FILES([GNUmakefile])

AC_OUTPUT




