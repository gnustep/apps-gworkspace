AC_DEFUN(AC_CHECK_PDFKIT,[OLD_CFLAGS=$CFLAGS
  CFLAGS="-xobjective-c"
  PREFIX="-I"
  SUFFIX="Library/Headers/"
  OLD_CPPFLAGS="$CPPFLAGS"
  CPPFLAGS="$CPPFLAGS $PREFIX$GNUSTEP_SYSTEM_ROOT/$SUFFIX $PREFIX$GNUSTEP_LOCAL_ROOT/$SUFFIX"

  OLD_LDFLAGS="$LD_FLAGS"
  PREFIX="-L"
  SUFFIX="Library/Libraries/"
  LDFLAGS="$LDFLAGS $PREFIX$GNUSTEP_SYSTEM_ROOT/$SUFFIX $PREFIX$GNUSTEP_LOCAL_ROOT/$SUFFIX"
  OLD_LIBS="$LIBS"
  LIBS="-lgnustep-gui"
  AC_MSG_CHECKING([for PDFKit])

  AC_LINK_IFELSE(
          AC_LANG_PROGRAM(
                  [[#include <Foundation/Foundation.h>
                    #include <AppKit/AppKit.h>]],
                  [[[[NSImage class]];]]),
	  $1;
	  gui_found=yes,
	  $2;
	  gui_found=no)

  if test "$gui_found" = "no"; then
    LIBS="-lgnustep-gui_d"

    AC_LINK_IFELSE(
          AC_LANG_PROGRAM(
                  [[#include <Foundation/Foundation.h>
                    #include <AppKit/AppKit.h>]],
                  [[[[NSImage class]];]]),
	  $1;
	  gui_found=yes,
	  $2;
	  gui_found=no)
  fi

  if test "$gui_found" = "no"; then
    LIBS="-lgnustep-gui_p"

    AC_LINK_IFELSE(
          AC_LANG_PROGRAM(
                  [[#include <Foundation/Foundation.h>
                    #include <AppKit/AppKit.h>]],
                  [[[[NSImage class]];]]),
	  $1;
	  gui_found=yes,
	  $2;
	  gui_found=no)
  fi

  GUI_LIBS=$LIBS

  LIBS="$GUI_LIBS -lPDFKit"

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

  if test "$have_pdfkit" = "no"; then
    LIBS="$GUI_LIBS -lPDFKit_d"

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
  fi

  if test "$have_pdfkit" = "no"; then
    LIBS="$GUI_LIBS -lPDFKit_p"

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
  fi

  LIBS="$OLD_LIBS"
  CPPFLAGS="$OLD_CPPFLAGS"
  LDFLAGS="$OLD_LDFLAGS"
  CFLAGS="$OLD_CFLAGS"

  AC_MSG_RESULT($have_pdfkit)
])


AC_DEFUN(AC_CHECK_PDFKIT_DARWIN,[
  AC_MSG_CHECKING([for PDFKit])
  H_SUF="Library/Headers/"
  PDF_H="PDFKit/PDFDocument.h"
  PDF_H_PATH="$GNUSTEP_SYSTEM_ROOT/$H_SUF$PDF_H"

  if test -e $PDF_H_PATH; then
    have_pdfkit=yes
  else 
    PDF_H_PATH="$GNUSTEP_LOCAL_ROOT/$H_SUF$PDF_H"
    if test -e $PDF_H_PATH; then
      have_pdfkit=yes
    else 
      have_pdfkit=no
    fi
  fi
  
  AC_MSG_RESULT($have_pdfkit)
])



