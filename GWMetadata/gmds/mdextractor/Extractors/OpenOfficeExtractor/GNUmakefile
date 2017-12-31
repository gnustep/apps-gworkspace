
PACKAGE_NAME = gworkspace
include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = OpenOfficeExtractor
BUNDLE_EXTENSION = .extr

OBJCFLAGS += -Wall

#
# We are creating a bundle
#
OpenOfficeExtractor_OBJC_FILES = OpenOfficeExtractor.m

OpenOfficeExtractor_PRINCIPAL_CLASS = OpenOfficeExtractor

OpenOfficeExtractor_TOOL_LIBS += -lgnustep-gui $(SYSTEM_LIBS)

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.preamble
-include GNUmakefile.local
-include GNUmakefile.postamble
