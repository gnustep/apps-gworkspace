
include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = SmallIconsViewer
BUNDLE_EXTENSION = .viewer

SmallIconsViewer_HAS_RESOURCE_BUNDLE = yes

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
SmallIconsViewer_OBJC_FILES = SmallIconsViewer.m \
			      Banner.m \
			      PathsPopUp.m \
			      SmallIconsPanel.m \
			      SmallIcon.m \
			      SmallIconLabel.m 

SmallIconsViewer_RESOURCE_FILES = Images/*

SmallIconsViewer_PRINCIPAL_CLASS = SmallIconsViewer

#SmallIconsViewer_LANGUAGES = English Italian Romanian

#SmallIconsViewer_LOCALIZED_RESOURCE_FILES = Localizable.strings

-include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.postamble

