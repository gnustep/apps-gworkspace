AC_DEFUN(AC_CHECK_PDFKIT,[
  
  GNUSTEP_SH_EXPORT_ALL_VARIABLES=yes
  . "$GNUSTEP_MAKEFILES/GNUstep.sh"
  unset GNUSTEP_SH_EXPORT_ALL_VARIABLES

  # For backwards compatibility, define GNUSTEP_SYSTEM_HEADERS from
  # GNUSTEP_SYSTEM_ROOT if not set yet.
  if test x"$GNUSTEP_SYSTEM_HEADERS" = x""; then
    GNUSTEP_SYSTEM_HEADERS="$GNUSTEP_SYSTEM_ROOT/Library/Headers"
  fi
  if test x"$GNUSTEP_LOCAL_HEADERS" = x""; then
    GNUSTEP_LOCAL_HEADERS="$GNUSTEP_LOCAL_ROOT/Library/Headers"
  fi

  if test x"$GNUSTEP_SYSTEM_LIBRARIES" = x""; then
    GNUSTEP_SYSTEM_LIBRARIES="$GNUSTEP_SYSTEM_ROOT/Library/Libraries"
  fi
  if test x"$GNUSTEP_LOCAL_LIBRARIES" = x""; then
    GNUSTEP_LOCAL_LIBRARIES="$GNUSTEP_LOCAL_ROOT/Library/Libraries"
  fi
  
  OLD_CFLAGS=$CFLAGS  
  CFLAGS="-xobjective-c"
  PREFIX="-I"
  OLD_CPPFLAGS="$CPPFLAGS"
  CPPFLAGS="$CPPFLAGS $PREFIX$GNUSTEP_SYSTEM_HEADERS $PREFIX$GNUSTEP_LOCAL_HEADERS"

  OLD_LDFLAGS="$LD_FLAGS"
  PREFIX="-L"
  LDFLAGS="$LDFLAGS $PREFIX$GNUSTEP_SYSTEM_LIBRARIES $PREFIX$GNUSTEP_LOCAL_LIBRARIES"
  OLD_LIBS="$LIBS"
  LIBS="-lgnustep-gui"
  AC_MSG_CHECKING([for PDFKit])

  LIBS="$LIBS -lPDFKit"

  AC_LINK_IFELSE(
          AC_LANG_PROGRAM(
                  [[#include <Foundation/Foundation.h>
                    #include <AppKit/AppKit.h>
                    #include <PDFKit/PDFDocument.h>]],
                  [[[[PDFDocument class]];]]),
	  $1;
	  have_pdfkit=yes,
	  $2;
	  have_pdfkit=no)

  LIBS="$OLD_LIBS"
  CPPFLAGS="$OLD_CPPFLAGS"
  LDFLAGS="$OLD_LDFLAGS"
  CFLAGS="$OLD_CFLAGS"

  AC_MSG_RESULT($have_pdfkit)
])


AC_DEFUN(AC_CHECK_PDFKIT_DARWIN,[
  AC_MSG_CHECKING([for PDFKit])
  PDF_H="PDFKit/PDFDocument.h"
  PDF_H_PATH="$GNUSTEP_SYSTEM_HEADERS/$PDF_H"

  if test -e $PDF_H_PATH; then
    have_pdfkit=yes
  else 
    PDF_H_PATH="$GNUSTEP_LOCAL_HEADERS/$PDF_H"
    if test -e $PDF_H_PATH; then
      have_pdfkit=yes
    else 
      have_pdfkit=no
    fi
  fi
  
  AC_MSG_RESULT($have_pdfkit)
])



