AC_PREREQ(2.52)
AC_INIT([Inspector], [0.3.0], [enrico@imago.ro])

if test -z "$GNUSTEP_SYSTEM_ROOT"; then
  AC_MSG_ERROR([You must run the GNUstep initialization script first!])
fi

#--------------------------------------------------------------------
# Use config.guess, config.sub and install-sh provided by gnustep-make
#--------------------------------------------------------------------
AC_CONFIG_AUX_DIR([$GNUSTEP_MAKEFILES])

PDFKIT="0"

HDIR=$GNUSTEP_LOCAL_ROOT/Library/Headers/PDFKit

if test -d $HDIR; then
  if test -f "$HDIR/PDFDocument.h"; then
    if test -f "$HDIR/PDFImageRep.h"; then
      PDFKIT="1"
    fi
  fi
fi

if test  $PDFKIT = "0"; then
  echo ""
  echo "The PDFKit framework can't be found."
  echo "The pdf viewer will not be built"
  echo ""
fi

AC_SUBST(PDFKIT)

AC_CONFIG_FILES([GNUmakefile \
									InspectorInfo.plist \
									inspector.make])
AC_OUTPUT
