
PACKAGE_NAME = gworkspace
include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = RtfViewer
BUNDLE_EXTENSION = .inspector

RtfViewer_HAS_RESOURCE_BUNDLE = yes

OBJCFLAGS += -Wall

#
# We are creating a bundle
#
RtfViewer_OBJC_FILES = RtfViewer.m 

RtfViewer_PRINCIPAL_CLASS = RtfViewer

RtfViewer_RESOURCE_FILES = Resources/English.lproj \
InspectorInfo.plist 

-include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.postamble

