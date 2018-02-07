AC_PREREQ(2.52)
AC_INIT

if test -z "$GNUSTEP_MAKEFILES"; then
  AC_MSG_ERROR([You must run the GNUstep initialization script first!])
fi

#--------------------------------------------------------------------
# Use config.guess, config.sub and install-sh provided by gnustep-make
#--------------------------------------------------------------------
AC_CHECK_HEADERS(dir.h unistd.h)
AC_CHECK_FUNCS(getpwnam getpwuid geteuid getlogin)

AC_CONFIG_AUX_DIR([$GNUSTEP_MAKEFILES])


#--------------------------------------------------------------------
# Determine the host, build, and target systems
#--------------------------------------------------------------------
AC_CANONICAL_TARGET([])

#--------------------------------------------------------------------
# Find sqlite
#--------------------------------------------------------------------
AC_ARG_WITH(sqlite_library, 
           [  --with-sqlite-library=DIR sqlite library files are in DIR], ,
           with_sqlite_library=)
AC_ARG_WITH(sqlite_include,  
 [  --with-sqlite-include=DIR sqlite include files are in DIR], ,
        with_sqlite_include=)

if test -n "$with_sqlite_library"; then
  with_sqlite_library="-L$with_sqlite_library"
fi
if test -n "$with_sqlite_include"; then
  with_sqlite_include="-I$with_sqlite_include"
fi

CPPFLAGS="$with_sqlite_include ${CPPFLAGS}"
LDFLAGS="$with_sqlite_library -lsqlite3 ${LDFLAGS}"

case "$target_os" in
  freebsd* | openbsd* )	
	        CPPFLAGS="$CPPFLAGS -I/usr/local/include"
		LDFLAGS="$LDFLAGS -L/usr/local/lib";;
  netbsd*)	CPPFLAGS="$CPPFLAGS -I/usr/pkg/include"
		LDFLAGS="$LDFLAGS -Wl,-R/usr/pkg/lib -L/usr/pkg/lib";;
esac

AC_CHECK_HEADER(sqlite3.h, have_sqlite=yes, have_sqlite=no)
if test "$have_sqlite" = yes; then
  AC_CHECK_LIB(sqlite3, sqlite3_get_table)  
  if test "$ac_cv_lib_sqlite3_sqlite3_get_table" = no; then
     have_sqlite=no
  fi
fi

if test "$have_sqlite" = yes; then
  sqlite_version_ok=yes
  
  AC_TRY_RUN([
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>
    #include <sqlite3.h>

int main ()
{
  unsigned vnum = sqlite3_libversion_number();
  
  printf("sqlite3 version number %d\n", vnum);
  return !(vnum >= 3002006);
}
  ],, sqlite_version_ok=no,[echo "wrong sqlite3 version"])

  if test "$have_sqlite" = yes; then
    SQLITE_LIB_DIRS="$with_sqlite_library -lsqlite3"
    SQLITE_INCLUDE_DIRS="$with_sqlite_include"
  fi

fi

if test "$have_sqlite" = no; then
  AC_MSG_WARN(Cannot find libsqlite3 header and/or library)
  echo "* GWMetadata requires the sqlite3 library"
  echo "* Use --with-sqlite-library and --with-sqlite-include"
  echo "* to specify the sqlite library directory if it is not"
  echo "* in the usual place(s)"
  AC_MSG_ERROR(GWMetadata will not compile without sqlite)
else
  if test "$sqlite_version_ok" = no; then
    AC_MSG_WARN(Wrong libsqlite3 version)
    echo "* GWMetadata requires libsqlite3 >= 3002006 *"
    AC_MSG_ERROR(GWMetadata will not compile without sqlite)
  fi
fi

AC_SUBST(SQLITE_LIB_DIRS)
AC_SUBST(SQLITE_INCLUDE_DIRS)


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
  AC_MSG_NOTICE([The pdf extractor will not be built.])  
fi

AC_SUBST(have_pdfkit)

#--------------------------------------------------------------------
# We need unzip
#--------------------------------------------------------------------
AC_ARG_WITH([unzip], [  --with-unzip=PROG  Use PROG as unzip], [UNZ_PATH=$withval], [UNZ_PATH=none])

if test "x$UNZ_PATH" = "xnone"; then
	AC_PATH_PROGS([UNZ_PATH], [unzip unzip], [none])
fi

AC_DEFINE_UNQUOTED([UNZIP_PATH], ["$UNZ_PATH"], [Path to unzip])

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

AC_CONFIG_HEADERS([MDKit/config.h gmds/mdextractor/Extractors/extractors.h])

AC_CONFIG_FILES([
  GNUmakefile
  MDKit/GNUmakefile
  gmds/gmds/GNUmakefile
  gmds/gmds/GNUmakefile.preamble
  gmds/mdextractor/Extractors/GNUmakefile
  ])

AC_OUTPUT
