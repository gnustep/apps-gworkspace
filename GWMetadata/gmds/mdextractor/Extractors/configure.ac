AC_PREREQ(2.52)
AC_INIT

if test -z "$GNUSTEP_MAKEFILES"; then
  AC_MSG_ERROR([You must set GNUSTEP_MAKEFILES or run the GNUstep initialization script first!])
fi

AC_CONFIG_AUX_DIR([$GNUSTEP_MAKEFILES])

AC_CONFIG_SUBDIRS([AbiwordExtractor JpegExtractor PdfExtractor TextExtractor AppExtractor HtmlExtractor OpenOfficeExtractor RtfExtractor XmlExtractor])

AC_CANONICAL_TARGET([])

#--------------------------------------------------------------------
# We need unzip
#--------------------------------------------------------------------
AC_ARG_WITH([unzip], [  --with-unzip=PROG  Use PROG as unzip], [UNZ_PATH=$withval], [UNZ_PATH=none])

if test "x$UNZ_PATH" = "xnone"; then
	AC_PATH_PROGS([UNZ_PATH], [unzip unzip], [none])
fi

AC_DEFINE_UNQUOTED([UNZIP_PATH], ["$UNZ_PATH"], [Path to unzip])

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

AC_CONFIG_FILES([GNUmakefile])

AC_OUTPUT




