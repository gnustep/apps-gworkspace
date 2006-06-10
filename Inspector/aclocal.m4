
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
	have_pdf_kit=yes,
	$2;
	have_pdf_kit=no)

if test "$have_pdf_kit" = "no"; then
  LIBS="$GUI_LIBS -lPDFKit_d"

  AC_LINK_IFELSE(
        AC_LANG_PROGRAM(
                [[#include <Foundation/Foundation.h>
                  #include <AppKit/AppKit.h>
                  #include <PDFKit/PDFDocument.h>]],
                [[[[PDFDocument class]];]]),
	$1;
	have_pdf_kit=yes,
	$2;
	have_pdf_kit=no)
fi

if test "$have_pdf_kit" = "no"; then
  LIBS="$GUI_LIBS -lPDFKit_p"

  AC_LINK_IFELSE(
        AC_LANG_PROGRAM(
                [[#include <Foundation/Foundation.h>
                  #include <AppKit/AppKit.h>
                  #include <PDFKit/PDFDocument.h>]],
                [[[[PDFDocument class]];]]),
	$1;
	have_pdf_kit=yes,
	$2;
	have_pdf_kit=no)
fi

if test "$have_pdf_kit" = "yes"; then
 AC_MSG_RESULT(yes)
else
 AC_MSG_RESULT(no)
fi

LIBS="$OLD_LIBS"
CPPFLAGS="$OLD_CPPFLAGS"
LDFLAGS="$OLD_LDFLAGS"
CFLAGS="$OLD_CFLAGS"])

