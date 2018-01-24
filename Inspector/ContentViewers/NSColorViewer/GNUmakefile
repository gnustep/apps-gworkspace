
PACKAGE_NAME = gworkspace
include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = NSColorViewer
BUNDLE_EXTENSION = .inspector

NSColorViewer_HAS_RESOURCE_BUNDLE = yes

OBJCFLAGS += -Wall

#
# We are creating a bundle
#
NSColorViewer_OBJC_FILES = NSColorViewer.m

NSColorViewer_PRINCIPAL_CLASS = NSColorViewer

NSColorViewer_RESOURCE_FILES = Resources/English.lproj \
InspectorInfo.plist 

-include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.postamble

