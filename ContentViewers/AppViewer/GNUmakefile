
include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = AppViewer
BUNDLE_EXTENSION=.inspector

OBJCFLAGS += -Wall

AppViewer_HAS_RESOURCE_BUNDLE = yes

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
AppViewer_OBJC_FILES = AppViewer.m 

AppViewer_PRINCIPAL_CLASS = AppViewer

#AppViewer_LANGUAGES = English Italian Romanian

#AppViewer_LOCALIZED_RESOURCE_FILES = Localizable.strings

AppViewer_RESOURCE_FILES = InspectorInfo.plist

-include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.postamble

