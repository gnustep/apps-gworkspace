include $(GNUSTEP_MAKEFILES)/common.make

GNUSTEP_INSTALLATION_DIR = $(GNUSTEP_SYSTEM_ROOT)

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
