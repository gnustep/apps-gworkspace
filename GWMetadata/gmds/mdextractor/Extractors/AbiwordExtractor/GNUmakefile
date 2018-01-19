
PACKAGE_NAME = gworkspace
include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = AbiwordExtractor
BUNDLE_EXTENSION = .extr

OBJCFLAGS += -Wall

#
# We are creating a bundle
#
AbiwordExtractor_OBJC_FILES = AbiwordExtractor.m

AbiwordExtractor_PRINCIPAL_CLASS = AbiwordExtractor

AbiwordExtractor_TOOL_LIBS += -lgnustep-gui $(SYSTEM_LIBS)

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.preamble
-include GNUmakefile.local
include GNUmakefile.postamble
