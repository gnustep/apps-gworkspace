
PACKAGE_NAME = gworkspace
include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = HtmlExtractor
BUNDLE_EXTENSION = .extr

OBJCFLAGS += -Wall

#
# We are creating a bundle
#
HtmlExtractor_OBJC_FILES = HtmlExtractor.m

HtmlExtractor_PRINCIPAL_CLASS = HtmlExtractor

HtmlExtractor_TOOL_LIBS += -lgnustep-gui

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.preamble
-include GNUmakefile.local
include GNUmakefile.postamble
