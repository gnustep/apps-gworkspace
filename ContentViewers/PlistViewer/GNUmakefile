
include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = PlistViewer
BUNDLE_EXTENSION = .inspector

PlistViewer_HAS_RESOURCE_BUNDLE = yes

OBJCFLAGS += -Wall

#
# Additional libraries
#
ifeq ($(FOUNDATION_LIB), apple)
  ADDITIONAL_GUI_LIBS += -framework GWorkspace
else
  ADDITIONAL_GUI_LIBS += -lGWorkspace
endif

#
# We are creating a bundle
#
PlistViewer_OBJC_FILES = PlistViewer.m 

PlistViewer_PRINCIPAL_CLASS = PlistViewer

PlistViewer_RESOURCE_FILES = InspectorInfo.plist

-include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.postamble

