include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = InspectorViewer
BUNDLE_EXTENSION = .inspector

InspectorViewer_HAS_RESOURCE_BUNDLE = yes

OBJCFLAGS += -Wall

#
# Additional libraries
#
ifeq ($(FOUNDATION_LIB), apple)
  ADDITIONAL_GUI_LIBS += -framework GWorkspace
else
  ADDITIONAL_GUI_LIBS += -lGWorkspace
endif

InspectorViewer_OBJC_FILES = InspectorViewer.m 
InspectorViewer_HEADERS_FILES = InspectorViewer.h 

InspectorViewer_PRINCIPAL_CLASS = InspectorViewer

InspectorViewer_RESOURCE_FILES = InspectorInfo.plist

-include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.postamble

