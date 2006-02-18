
include $(GNUSTEP_MAKEFILES)/common.make
GNUSTEP_INSTALLATION_DIR = $(GNUSTEP_SYSTEM_ROOT)

BUNDLE_NAME = MDIndexing
BUNDLE_EXTENSION = .prefPane

MDIndexing_HAS_RESOURCE_BUNDLE = yes

OBJCFLAGS += -Wall

MDIndexing_OBJC_FILES = \
MDIndexing.m 

MDIndexing_PRINCIPAL_CLASS = MDIndexing

MDIndexing_RESOURCE_FILES = \
Info.plist \
MDIndexing.tiff \
Resources/English.lproj 

ifeq ($(findstring darwin, $(GNUSTEP_TARGET_OS)), darwin)
  ADDITIONAL_GUI_LIBS += -lGSPreferencePanes
else
  ADDITIONAL_GUI_LIBS += -lPreferencePanes
endif

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.preamble
-include GNUmakefile.postamble
