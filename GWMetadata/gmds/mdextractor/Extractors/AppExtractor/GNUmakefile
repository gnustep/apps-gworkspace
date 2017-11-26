
PACKAGE_NAME = gworkspace
include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = AppExtractor
BUNDLE_EXTENSION = .extr

OBJCFLAGS += -Wall

#
# We are creating a bundle
#
AppExtractor_OBJC_FILES = AppExtractor.m

AppExtractor_PRINCIPAL_CLASS = AppExtractor

AppExtractor_TOOL_LIBS += -lgnustep-gui $(SYSTEM_LIBS)

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.preamble
-include GNUmakefile.local
-include GNUmakefile.postamble
