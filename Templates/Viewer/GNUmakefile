
include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = MYViewer
BUNDLE_EXTENSION = .viewer

MYViewer_HAS_RESOURCE_BUNDLE = yes

OBJCFLAGS += -Wall

ifeq ($(FOUNDATION_LIB), apple)
  ADDITIONAL_INCLUDE_DIRS += -framework GWorkspace
  ADDITIONAL_GUI_LIBS += -framework GWorkspace
else
  ADDITIONAL_INCLUDE_DIRS += -IGWorkspace
  ADDITIONAL_GUI_LIBS += -lGWorkspace
endif

#
# We are creating a bundle
#
MYViewer_OBJC_FILES = MYViewer.m

MYViewer_RESOURCE_FILES = Images/*

MYViewer_PRINCIPAL_CLASS = MYViewer

-include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.postamble

