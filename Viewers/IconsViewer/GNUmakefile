include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = IconsViewer
BUNDLE_EXTENSION = .viewer

IconsViewer_HAS_RESOURCE_BUNDLE = yes

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
IconsViewer_OBJC_FILES = IconsViewer.m \
			 IconsPanel.m \
			 IconsViewerIcon.m \
			 IconsPath.m \
			 PathIcon.m \
			 PathIconLabel.m \
			 GWScrollView.m \
                         IconsViewerPref.m

IconsViewer_PRINCIPAL_CLASS = IconsViewer

IconsViewer_RESOURCE_FILES = \
    Resources/Images/* \
    Resources/English.lproj \
    Resources/French.lproj \
    Resources/German.lproj \
    Resources/Italian.lproj \
    Resources/Romanian.lproj \
    Resources/Spanish.lproj \
    Resources/Portuguese.lproj \
    Resources/Dutch.lproj 

IconsViewer_LANGUAGES = \
  Resources/English \
  Resources/French \
  Resources/German \
  Resources/Italian \
  Resources/Romanian \
  Resources/Spanish \
  Resources/Portuguese \
  Resources/Dutch

ifeq ($(FOUNDATION_LIB), apple)
  IconsViewer_LOCALIZED_RESOURCE_FILES = IconsViewerPref.nib
else
  IconsViewer_LOCALIZED_RESOURCE_FILES = IconsViewerPref.gorm
endif                                                                             

-include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.postamble

