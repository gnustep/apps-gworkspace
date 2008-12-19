
PACKAGE_NAME = gworkspace
include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = NSRTFViewer
BUNDLE_EXTENSION = .inspector

NSRTFViewer_HAS_RESOURCE_BUNDLE = yes

OBJCFLAGS += -Wall

#
# We are creating a bundle
#
NSRTFViewer_OBJC_FILES = NSRTFViewer.m

NSRTFViewer_PRINCIPAL_CLASS = NSRTFViewer

NSRTFViewer_RESOURCE_FILES = Resources/English.lproj \
InspectorInfo.plist 

-include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.postamble

