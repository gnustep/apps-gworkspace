
include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = SoundViewer
BUNDLE_EXTENSION = .inspector

SoundViewer_HAS_RESOURCE_BUNDLE = yes

OBJCFLAGS += -Wall

#
# Additional libraries
#
ifeq ($(FOUNDATION_LIB), apple)
  ADDITIONAL_GUI_LIBS += -framework GWorkspace
else
  ADDITIONAL_GUI_LIBS += -lGWorkspace
endif

SoundViewer_OBJC_FILES = SoundViewer.m 

SoundViewer_PRINCIPAL_CLASS = SoundViewer

#SoundViewer_LANGUAGES = English Italian Romanian

SoundViewer_RESOURCE_FILES = Images/* \
                             InspectorInfo.plist

#SoundViewer_LOCALIZED_RESOURCE_FILES = Localizable.strings

-include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.postamble

