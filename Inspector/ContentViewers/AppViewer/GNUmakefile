
PACKAGE_NAME = gworkspace
include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = AppViewer
BUNDLE_EXTENSION=.inspector

OBJCFLAGS += -Wall

AppViewer_HAS_RESOURCE_BUNDLE = yes

#
# We are creating a bundle
#
AppViewer_OBJC_FILES = AppViewer.m 

AppViewer_PRINCIPAL_CLASS = AppViewer

AppViewer_RESOURCE_FILES = Resources/English.lproj \
InspectorInfo.plist 

-include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.postamble

