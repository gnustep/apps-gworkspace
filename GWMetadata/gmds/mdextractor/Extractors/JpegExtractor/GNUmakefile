
PACKAGE_NAME = gworkspace
include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = JpegExtractor
BUNDLE_EXTENSION = .extr

OBJCFLAGS += -Wall

#
# We are creating a bundle
#
JpegExtractor_OBJC_FILES = JpegExtractor.m \
jhead.m \
jpgfile.m \
exif.m 

JpegExtractor_PRINCIPAL_CLASS = JpegExtractor

JpegExtractor_TOOL_LIBS += -lgnustep-gui

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.preamble
-include GNUmakefile.local
-include GNUmakefile.postamble
