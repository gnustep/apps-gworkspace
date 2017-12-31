AC_PREREQ(2.52)
AC_INIT(gworkspace, 0.9.4)

if test -z "$GNUSTEP_MAKEFILES"; then
  AC_MSG_ERROR([You must run the GNUstep initialization script first!])
fi

#--------------------------------------------------------------------
# Use config.guess, config.sub and install-sh provided by gnustep-make
#--------------------------------------------------------------------
AC_CONFIG_AUX_DIR([$GNUSTEP_MAKEFILES])
AC_CONFIG_HEADER([FSNode/config.h])

AC_CANONICAL_HOST

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
case "$host_os" in
  darwin*)
    AC_CHECK_PDFKIT_DARWIN(have_pdfkit=yes, have_pdfkit=no)
    ;;
  *)
    AC_CHECK_PDFKIT(have_pdfkit=yes, have_pdfkit=no)
    ;;
esac

if test "$have_pdfkit" = "no"; then
  AC_MSG_NOTICE([The PDFKit framework can't be found.])
  AC_MSG_NOTICE([The pdf viewer/extractor will not be built.])
fi

AC_SUBST(have_pdfkit)

AC_CHECK_HEADERS(dir.h)
AC_CHECK_FUNCS(getpwnam getpwuid geteuid getlogin)

#--------------------------------------------------------------------
# Support for determining mountpoints
#--------------------------------------------------------------------
AC_CHECK_FUNCS(getmntinfo)

AC_CHECK_HEADERS([mntent.h sys/types.h sys/mntent.h sys/resource.h])

# support for NetBSD > 3.x
AC_CHECK_HEADERS(sys/statvfs.h)

AC_CHECK_MEMBER([struct mntent.mnt_dir],
  [AC_DEFINE([MNT_FSNAME], [mnt_fsname], [mntent structure member name])]
  [AC_DEFINE([MNT_DIR], [mnt_dir], [mntent structure member name])]
  [AC_DEFINE([MNT_FSTYPE], [mnt_type], [mntent structure member name])],
  [], [#include <mntent.h>])
AC_CHECK_MEMBER([struct mntent.mnt_mountp],
  [AC_DEFINE([MNT_FSNAME], [mnt_special], [mntent structure member name])]
  [AC_DEFINE([MNT_DIR], [mnt_mountp], [mntent structure member name])]
  [AC_DEFINE([MNT_FSTYPE], [mnt_fstype], [mntent structure member name])],
  [], [#include <sys/mntent.h>])

AC_FUNC_GETMNTENT

AC_ARG_ENABLE(gwmetadata,
  [  --enable-gwmetadata     Enable GWMetadata], , [enable_gwmetadata=no])

if test "x$enable_gwmetadata" = "xyes"; then
  BUILD_GWMETADATA=1

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

case "$host_os" in
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

  AC_RUN_IFELSE([AC_LANG_SOURCE([[
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
  ]])],[],[sqlite_version_ok=no],[echo "wrong sqlite3 version"])

  if test "$have_sqlite" = yes; then
    ADDITIONAL_LIB_DIRS="$ADDITIONAL_LIB_DIRS $with_sqlite_library -lsqlite3"
    ADDITIONAL_INCLUDE_DIRS="$ADDITIONAL_INCLUDE_DIRS $with_sqlite_include"
    SQLITE_LIB_DIRS="$with_sqlite_library -lsqlite3"
    SQLITE_INCLUDE_DIRS="$with_sqlite_include"
  fi
fi

if test "$have_sqlite" = no; then
  AC_MSG_WARN(Cannot find libsqlite3 header and/or library)
  echo "* The MDKit library requires the sqlite3 library"
  echo "* Use --with-sqlite-library and --with-sqlite-include"
  echo "* to specify the sqlite3 library directory if it is not"
  echo "* in the usual place(s)"
  AC_MSG_ERROR(MDKit will not compile without sqlite)
else
  if test "$sqlite_version_ok" = no; then
    AC_MSG_WARN(Wrong libsqlite3 version)
    echo "* The MDKit framework requires libsqlite3 >= 3002006 *"
    AC_MSG_ERROR(The MDKit framework will not compile without sqlite)
  fi
fi

AC_SUBST(ADDITIONAL_LIB_DIRS)
AC_SUBST(ADDITIONAL_INCLUDE_DIRS)
AC_SUBST(SQLITE_LIB_DIRS)
AC_SUBST(SQLITE_INCLUDE_DIRS)

#--------------------------------------------------------------------
# We need unzip
#--------------------------------------------------------------------
AC_ARG_WITH([unzip], [  --with-unzip=PROG  Use PROG as unzip], [UNZ_PATH=$withval], [UNZ_PATH=none])

if test "x$UNZ_PATH" = "xnone"; then
	AC_PATH_PROGS([UNZ_PATH], [unzip unzip], [none])
fi

AC_DEFINE_UNQUOTED([UNZIP_PATH], ["$UNZ_PATH"], [Path to unzip])

else
  BUILD_GWMETADATA=0
fi
AC_SUBST(BUILD_GWMETADATA)

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

#--------------------------------------------------------------------
# fswatcher-fam
#--------------------------------------------------------------------
AC_ARG_WITH(fam,
  [  --with-fam  Build fswatcher-fam],
  with_fam=yes, with_fam=no)

AC_SUBST(with_fam)

AC_CONFIG_FILES([
  GNUmakefile
  GWorkspace/GNUmakefile
  Tools/fswatcher/GNUmakefile
  Inspector/inspector.make
  GWMetadata/MDKit/GNUmakefile
  GWMetadata/gmds/gmds/GNUmakefile
  GWMetadata/gmds/gmds/GNUmakefile.preamble
  GWMetadata/gmds/mdextractor/Extractors/GNUmakefile])

AC_OUTPUT
