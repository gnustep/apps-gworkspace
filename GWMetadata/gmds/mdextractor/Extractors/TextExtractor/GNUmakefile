
PACKAGE_NAME = gworkspace
include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = TextExtractor
BUNDLE_EXTENSION = .extr
TextExtractor_HAS_RESOURCE_BUNDLE = yes

OBJCFLAGS += -Wall

#
# We are creating a bundle
#
TextExtractor_OBJC_FILES = TextExtractor.m

TextExtractor_PRINCIPAL_CLASS = TextExtractor

TextExtractor_TOOL_LIBS += -lgnustep-gui

#TextExtractor_RESOURCE_FILES = stopwords.plist

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.preamble
-include GNUmakefile.local
-include GNUmakefile.postamble
