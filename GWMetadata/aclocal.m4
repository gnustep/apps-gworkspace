AC_DEFUN(AC_CHECK_PDFKIT,[
  
  GNUSTEP_SH_EXPORT_ALL_VARIABLES=yes
  . "$GNUSTEP_MAKEFILES/GNUstep.sh"
  unset GNUSTEP_SH_EXPORT_ALL_VARIABLES

  OLD_CFLAGS=$CFLAGS  
  CFLAGS="-xobjective-c `gnustep-config --objc-flags`"

  OLD_LDFLAGS="$LD_FLAGS"
  LDFLAGS="$LDFLAGS `gnustep-config --gui-libs`"
  OLD_LIBS="$LIBS"
  LIBS="$LIBS -lPDFKit"

  AC_MSG_CHECKING([for PDFKit])

  AC_LINK_IFELSE(
          [AC_LANG_PROGRAM(
                  [[#include <Foundation/Foundation.h>
                    #include <AppKit/AppKit.h>
                    #include <PDFKit/PDFDocument.h>]],
                  [[[PDFDocument class];]])],
	  $1;
	  have_pdfkit=yes,
	  $2;
	  have_pdfkit=no)

  LIBS="$OLD_LIBS"
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



