
include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = ImageViewer
BUNDLE_EXTENSION = .inspector

ImageViewer_HAS_RESOURCE_BUNDLE = yes

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
ImageViewer_OBJC_FILES = ImageViewer.m 

ImageViewer_PRINCIPAL_CLASS = ImageViewer

#ImageViewer_LANGUAGES = English Italian Romanian

#ImageViewer_LOCALIZED_RESOURCE_FILES = Localizable.strings

ImageViewer_RESOURCE_FILES = InspectorInfo.plist

-include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.postamble

