
PACKAGE_NAME = gworkspace
include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = PdfExtractor
BUNDLE_EXTENSION = .extr

OBJCFLAGS += -Wall

#
# We are creating a bundle
#
PdfExtractor_OBJC_FILES = PdfExtractor.m

PdfExtractor_PRINCIPAL_CLASS = PdfExtractor

PdfExtractor_TOOL_LIBS += -lPDFKit -lgnustep-gui $(SYSTEM_LIBS)

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.preamble
-include GNUmakefile.local
-include GNUmakefile.postamble
