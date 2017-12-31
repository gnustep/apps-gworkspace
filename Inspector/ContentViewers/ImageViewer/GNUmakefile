
PACKAGE_NAME = gworkspace
include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = ImageViewer
BUNDLE_EXTENSION = .inspector

ImageViewer_HAS_RESOURCE_BUNDLE = yes

OBJCFLAGS += -Wall

#
# We are creating a bundle
#
ImageViewer_OBJC_FILES = ImageViewer.m \
	Resizer.m

ImageViewer_PRINCIPAL_CLASS = ImageViewer

ImageViewer_RESOURCE_FILES = Resources/English.lproj \
InspectorInfo.plist 

-include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/aggregate.make

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.postamble

