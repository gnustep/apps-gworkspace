
include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = BrowserViewer
BUNDLE_EXTENSION = .viewer

BrowserViewer_HAS_RESOURCE_BUNDLE = yes

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
BrowserViewer_OBJC_FILES = BrowserViewer.m \
                           BrowserViewerPref.m

BrowserViewer_PRINCIPAL_CLASS = BrowserViewer

BrowserViewer_RESOURCE_FILES = \
    Resources/Images/* \
    Resources/English.lproj \
    Resources/French.lproj \
    Resources/German.lproj \
    Resources/Italian.lproj \
    Resources/Romanian.lproj \
    Resources/Spanish.lproj \
    Resources/Portuguese.lproj \
    Resources/Dutch.lproj 

BrowserViewer_LANGUAGES = \
  Resources/English \
  Resources/French \
  Resources/German \
  Resources/Italian \
  Resources/Romanian \
  Resources/Spanish \
  Resources/Portuguese \
  Resources/Dutch

ifeq ($(FOUNDATION_LIB), apple)
  BrowserViewer_LOCALIZED_RESOURCE_FILES = BrowserViewerPref.nib
else
  BrowserViewer_LOCALIZED_RESOURCE_FILES = BrowserViewerPref.gorm
endif                                                                             

-include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.postamble

