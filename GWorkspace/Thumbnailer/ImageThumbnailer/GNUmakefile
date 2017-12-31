
PACKAGE_NAME = gworkspace
include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = ImageThumbnailer
BUNDLE_EXTENSION = .thumb

OBJCFLAGS += -Wall

#
# We are creating a bundle
#
ImageThumbnailer_OBJC_FILES = ImageThumbnailer.m

ImageThumbnailer_PRINCIPAL_CLASS = ImageThumbnailer

-include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.postamble

