
include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = FolderViewer
BUNDLE_EXTENSION = .inspector

FolderViewer_HAS_RESOURCE_BUNDLE = yes
#
# Additional libraries
#
ifeq ($(FOUNDATION_LIB), apple)
  ADDITIONAL_GUI_LIBS += -framework GWorkspace
else
  ADDITIONAL_GUI_LIBS += -lGWorkspace
endif

OBJCFLAGS += -Wall

FolderViewer_OBJC_FILES = FolderViewer.m 

FolderViewer_PRINCIPAL_CLASS = FolderViewer

#FolderViewer_LANGUAGES = English Italian Romanian

#FolderViewer_LOCALIZED_RESOURCE_FILES = Localizable.strings

FolderViewer_RESOURCE_FILES = InspectorInfo.plist

-include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.postamble

