
include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = StringsViewer
BUNDLE_EXTENSION = .inspector

StringsViewer_HAS_RESOURCE_BUNDLE = yes

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
StringsViewer_OBJC_FILES = StringsViewer.m StringsFile.m SourceEntry.m StringsEntry.m

StringsViewer_PRINCIPAL_CLASS = StringsViewer

StringsViewer_RESOURCE_FILES = InspectorInfo.plist

-include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.postamble
