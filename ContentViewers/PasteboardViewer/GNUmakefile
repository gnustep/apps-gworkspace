
include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = PasteboardViewer
BUNDLE_EXTENSION = .inspector

PasteboardViewer_HAS_RESOURCE_BUNDLE = yes

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
PasteboardViewer_OBJC_FILES = PasteboardViewer.m 

PasteboardViewer_PRINCIPAL_CLASS = PasteboardViewer

#PasteboardViewer_LANGUAGES = English Italian Romanian

#PasteboardViewer_LOCALIZED_RESOURCE_FILES = Localizable.strings

PasteboardViewer_RESOURCE_FILES = InspectorInfo.plist

-include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.postamble

