
include $(GNUSTEP_MAKEFILES)/common.make

PACKAGE_NAME = Finder
VERSION = 0.7

GNUSTEP_INSTALLATION_DIR = $(GNUSTEP_SYSTEM_ROOT)

SUBPROJECTS = Modules

#
# MAIN APP
#
APP_NAME = Finder
Finder_PRINCIPAL_CLASS = Finder
Finder_APPLICATION_ICON=Finder.tiff

Finder_HAS_RESOURCE_BUNDLE = yes

Finder_RESOURCE_FILES = \
    Resources/Images/* \
    Resources/English.lproj \
    Modules/FModuleName/FModuleName.finder \
    Modules/FModuleKind/FModuleKind.finder \
    Modules/FModuleSize/FModuleSize.finder \
    Modules/FModuleOwner/FModuleOwner.finder \
    Modules/FModuleCrDate/FModuleCrDate.finder \
    Modules/FModuleModDate/FModuleModDate.finder \
    Modules/FModuleContents/FModuleContents.finder


Finder_LANGUAGES = Resources/English 

#Finder_LOCALIZED_RESOURCE_FILES = Localizable.strings \
#                                       Finder.gorm \
#                                       FindView.gorm \
#                                       ResultsWindow.gorm 

# The Objective-C source files to be compiled
Finder_OBJC_FILES = main.m \
                 Finder.m \
                 FindView.m \
                 SearchPlacesScroll.m \
                 SearchPlacesMatrix.m \
                 SearchResults/SearchResults.m \
                 SearchResults/ResultsTableView.m \
                 SearchResults/ResultsPathsView.m \
                 Functions.m 

ADDITIONAL_GUI_LIBS += -lFSNode
						 
-include GNUmakefile.preamble

-include GNUmakefile.local

include $(GNUSTEP_MAKEFILES)/aggregate.make

include $(GNUSTEP_MAKEFILES)/application.make

-include GNUmakefile.postamble
