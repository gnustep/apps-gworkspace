include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = FontViewer
BUNDLE_EXTENSION = .inspector

FontViewer_HAS_RESOURCE_BUNDLE = yes

OBJCFLAGS += -Wall

#
# Additional libraries
#
ifeq ($(FOUNDATION_LIB), apple)
  ADDITIONAL_GUI_LIBS += -framework GWorkspace
else
  ADDITIONAL_GUI_LIBS += -lGWorkspace
endif

FontViewer_OBJC_FILES = FontViewer.m 
FontViewer_HEADERS_FILES = FontViewer.h 

FontViewer_PRINCIPAL_CLASS = FontViewer

FontViewer_RESOURCE_FILES = InspectorInfo.plist

-include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.postamble

